import Foundation
import IOKit
import IOKit.hid

enum HIDConnectionState: Equatable {
    case connected(deviceName: String)
    case permissionRequired
    case disconnected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .connected(let name): return "\(name) conectado (258a:0049)"
        case .permissionRequired: return "Falta permiso de Monitoreo de entrada"
        case .disconnected: return "Teclado desconectado (conecta el K648 por USB)"
        case .error(let msg): return "Error HID: \(msg)"
        }
    }
}

private let k648InputValueCallback: IOHIDValueCallback = { context, result, _, value in
    guard result == kIOReturnSuccess, let ctx = context else { return }
    let elem = IOHIDValueGetElement(value)
    let usagePage = IOHIDElementGetUsagePage(elem)
    let usage = IOHIDElementGetUsage(elem)
    // Standard USB HID Keyboard/Keypad usage page (0x07), physical keys 0x04...0xE7
    guard usagePage == 0x07, usage >= 0x04, usage <= 0xE7 else { return }
    let pressed = IOHIDValueGetIntegerValue(value) != 0
    let controller = Unmanaged<K648HIDController>.fromOpaque(ctx).takeUnretainedValue()
    controller.onKeyEvent?(usage, pressed)
}

/// Safe IOKit HID controller for the Redragon K648GG-RGB Olaf (Sinowealth 0x258A:0x0049).
///
/// SAFETY GUARANTEE:
/// - Writes ONLY HID Feature Report ID `0x08` (382 bytes, header `08 0A 7A 01` + 126 RGB triples)
///   to volatile RAM on Interface 1 (`MaxFeatureReportSize >= 382`). Never touches flash/bootloader (`0x05`/`0x06`).
/// - Opens keyboard interfaces strictly non-seized (`kIOHIDOptionsTypeNone`) so normal macOS typing is never affected.
/// - Listens to hardware key presses only in memory to drive real-time reactive lighting effects.
final class K648HIDController {
    static let vendorID: Int = 0x258A
    static let productID: Int = 0x0049
    static let reportID: CFIndex = 0x08
    static let packetLength: Int = 382 // 4-byte header + 126 * 3 RGB bytes

    private let ioQueue = DispatchQueue(label: "com.redragon.olaf.hid", qos: .userInteractive)
    private var manager: IOHIDManager?
    private var ledDevice: IOHIDDevice?
    private var openDevices: [IOHIDDevice] = []
    private var isDeviceOpen = false
    private var lastFrameBytes: [UInt8]?
    private var reconnectTimer: DispatchSourceTimer?

    var onStateChange: ((HIDConnectionState) -> Void)?
    /// Called on the main run loop whenever a physical K648 key is pressed or released.
    var onKeyEvent: ((UInt32, Bool) -> Void)?

    private(set) var currentState: HIDConnectionState = .disconnected {
        didSet {
            if oldValue != currentState {
                let state = currentState
                DispatchQueue.main.async { [weak self] in
                    self?.onStateChange?(state)
                }
            }
        }
    }

    init() {}

    deinit {
        stop()
    }

    static func hasInputMonitoringPermission() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    @discardableResult
    static func requestInputMonitoringPermission() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func start() {
        ioQueue.async { [weak self] in
            self?.setupManager()
            self?.attemptConnect(forceResetFrame: true)
            self?.startReconnectTimer()
        }
    }

    func stop() {
        ioQueue.sync {
            reconnectTimer?.cancel()
            reconnectTimer = nil
            closeDevicesSync()
            if let mgr = manager {
                IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
                manager = nil
            }
        }
    }

    func reconnect() {
        ioQueue.async { [weak self] in
            self?.closeDevicesAsync()
            self?.setupManager()
            self?.attemptConnect(forceResetFrame: true)
        }
    }

    /// Sends a 126-slot RGB buffer (378 bytes) wrapped in the safe 382-byte Report 0x08 feature report.
    func sendFrame(slotRGB: [UInt8], force: Bool = false) {
        guard slotRGB.count == K648Layout.totalLedSlots * 3 else { return }
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isDeviceOpen {
                return
            }
            if !force, let prev = self.lastFrameBytes, prev == slotRGB {
                return
            }

            var packet = [UInt8](repeating: 0, count: Self.packetLength)
            packet[0] = 0x08 // Report ID
            packet[1] = 0x0A // Sinowealth direct LED header
            packet[2] = 0x7A
            packet[3] = 0x01
            for i in 0..<slotRGB.count {
                packet[4 + i] = slotRGB[i]
            }

            guard let dev = self.ledDevice else { return }
            let result: IOReturn = packet.withUnsafeBytes { rawBuf in
                guard let basePtr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return kIOReturnBadArgument
                }
                return IOHIDDeviceSetReport(
                    dev,
                    kIOHIDReportTypeFeature,
                    Self.reportID,
                    basePtr,
                    Self.packetLength
                )
            }

            if result == kIOReturnSuccess {
                self.lastFrameBytes = slotRGB
            } else if result == kIOReturnNotPermitted {
                self.closeDevicesAsync()
                self.currentState = .permissionRequired
            } else {
                self.closeDevicesAsync()
                self.currentState = .disconnected
            }
        }
    }

    // MARK: - Private IOKit Helpers

    private func setupManager() {
        if let mgr = manager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            manager = nil
        }
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDProductIDKey: Self.productID
        ]
        IOHIDManagerSetDeviceMatching(mgr, match as CFDictionary)
        manager = mgr
    }

    private func closeDevicesAsync() {
        let toClose = openDevices
        openDevices.removeAll()
        ledDevice = nil
        isDeviceOpen = false
        lastFrameBytes = nil
        guard !toClose.isEmpty else { return }
        DispatchQueue.main.async {
            for dev in toClose {
                IOHIDDeviceRegisterInputValueCallback(dev, nil, nil)
                IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
                IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            }
        }
    }

    private func closeDevicesSync() {
        let toClose = openDevices
        openDevices.removeAll()
        ledDevice = nil
        isDeviceOpen = false
        lastFrameBytes = nil
        guard !toClose.isEmpty else { return }
        let cleanup = {
            for dev in toClose {
                IOHIDDeviceRegisterInputValueCallback(dev, nil, nil)
                IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
                IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            }
        }
        if Thread.isMainThread {
            cleanup()
        } else {
            DispatchQueue.main.sync(execute: cleanup)
        }
    }

    private func attemptConnect(forceResetFrame: Bool) {
        if isDeviceOpen { return }
        guard let mgr = manager else {
            currentState = .disconnected
            return
        }

        guard let deviceSet = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>, !deviceSet.isEmpty else {
            currentState = .disconnected
            return
        }

        // Interface 1 is the vendor RGB control interface: MaxFeatureReportSize == 1032 (>= 382)
        // Interface 0 is the standard boot keyboard: MaxFeatureReportSize == 0 (used read-only for reactive keypresses)
        var targetLED: IOHIDDevice?
        for dev in deviceSet {
            let maxFeat = IOHIDDeviceGetProperty(dev, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int ?? 0
            if maxFeat >= Self.packetLength {
                targetLED = dev
                break
            }
        }

        guard let ledDev = targetLED else {
            currentState = .disconnected
            return
        }

        let openLED = IOHIDDeviceOpen(ledDev, IOOptionBits(kIOHIDOptionsTypeNone))
        if openLED == kIOReturnSuccess {
            var opened: [IOHIDDevice] = [ledDev]
            // Also open IF0 (boot keyboard) non-seized so reactive lighting receives standard & NKRO keypresses
            for dev in deviceSet where dev !== ledDev {
                if IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess {
                    opened.append(dev)
                }
            }

            ledDevice = ledDev
            openDevices = opened
            isDeviceOpen = true
            if forceResetFrame { lastFrameBytes = nil }

            // Register live input value callbacks on the main run loop for reactive keypress lighting
            let ctx = Unmanaged.passUnretained(self).toOpaque()
            DispatchQueue.main.async {
                for dev in opened {
                    IOHIDDeviceRegisterInputValueCallback(dev, k648InputValueCallback, ctx)
                    IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
                }
            }

            let product = IOHIDDeviceGetProperty(ledDev, kIOHIDProductKey as CFString) as? String ?? "Redragon K648 Olaf"
            currentState = .connected(deviceName: product)
        } else if openLED == kIOReturnNotPermitted {
            currentState = .permissionRequired
        } else {
            currentState = .error(String(format: "0x%08X", openLED))
        }
    }

    private func startReconnectTimer() {
        reconnectTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: ioQueue)
        timer.schedule(deadline: .now() + 1.5, repeating: 2.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if !self.isDeviceOpen {
                self.attemptConnect(forceResetFrame: true)
            }
        }
        reconnectTimer = timer
        timer.resume()
    }
}
