import SwiftUI
import AppKit

@main
struct RedragonOlafRGBApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()
    private let engine = RGBEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupSleepAndLockObservers()

        if engine.launchHiddenInMenuBar && K648HIDController.hasInputMonitoringPermission() {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            setupMainWindow()
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        engine.shutdown()
    }

    // MARK: - Sleep & Screen Lock Auto-Off

    private func setupSleepAndLockObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(handleSystemSleepOrLock), name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleSystemSleepOrLock), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleSystemWakeOrUnlock), name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleSystemWakeOrUnlock), name: NSWorkspace.screensDidWakeNotification, object: nil)

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(handleSystemSleepOrLock), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(handleSystemWakeOrUnlock), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func handleSystemSleepOrLock() {
        engine.setSystemAsleepOrLocked(true)
    }

    @objc private func handleSystemWakeOrUnlock() {
        engine.setSystemAsleepOrLocked(false)
    }

    // MARK: - Main Window

    private func setupMainWindow() {
        let contentView = ContentView(engine: engine)
        let hosting = NSHostingView(rootView: contentView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1260, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Redragon Olaf K648 — RGB Studio"
        win.titlebarAppearsTransparent = false
        win.appearance = NSAppearance(named: .darkAqua)
        win.contentView = hosting
        win.delegate = self
        win.isReleasedWhenClosed = false
        win.center()
        win.setFrameAutosaveName("RedragonOlafMainWindow")
        self.window = win
    }

    @objc func showMainWindow() {
        if window == nil {
            setupMainWindow()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if engine.keepRunningInMenuBar {
            sender.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
            return false
        } else {
            NSApp.terminate(nil)
            return true
        }
    }

    // MARK: - Dynamic Menu Bar Icon

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = item.button {
            let img = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "Redragon Olaf RGB")
            img?.isTemplate = true
            btn.image = img
        }
        statusMenu.delegate = self
        item.menu = statusMenu
        self.statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Status header
        let statusPrefix: String
        switch engine.connectionState {
        case .connected: statusPrefix = "● Conectado"
        case .permissionRequired: statusPrefix = "⚠ Falta permiso"
        case .disconnected: statusPrefix = "○ Desconectado"
        case .error: statusPrefix = "○ Error HID"
        }
        let statusLine = NSMenuItem(title: "\(statusPrefix) — \(engine.profile.name)", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        let openItem = NSMenuItem(title: "Abrir Redragon Olaf RGB", action: #selector(showMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // User's saved profiles directly accessible in the menu bar
        if !engine.savedProfiles.isEmpty {
            let header = NSMenuItem(title: "Mis perfiles", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for (idx, saved) in engine.savedProfiles.enumerated() {
                let mi = NSMenuItem(title: saved.name, action: #selector(selectSavedProfileFromMenu(_:)), keyEquivalent: "")
                mi.tag = idx
                mi.target = self
                if engine.profile.name == saved.name && engine.profile.globalEffect == saved.globalEffect {
                    mi.state = .on
                }
                menu.addItem(mi)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // Built-in presets submenu
        let presetsMenu = NSMenu()
        for (idx, preset) in LightingProfile.builtInPresets.enumerated() {
            let title = (preset.globalEffect.isReactive || preset.reactiveOverlay != .none)
                ? "⚡ \(preset.name)"
                : preset.name
            let mi = NSMenuItem(title: title, action: #selector(selectPresetFromMenu(_:)), keyEquivalent: "")
            mi.tag = idx
            mi.target = self
            if engine.profile.name == preset.name && engine.profile.globalEffect == preset.globalEffect {
                mi.state = .on
            }
            presetsMenu.addItem(mi)
        }
        let presetsRoot = NSMenuItem(title: "Presets rápidos", action: nil, keyEquivalent: "")
        presetsRoot.submenu = presetsMenu
        menu.addItem(presetsRoot)

        // Quick brightness submenu
        let brightnessMenu = NSMenu()
        let levels: [(String, Int)] = [
            ("100% (Máximo)", 100),
            ("75%", 75),
            ("50% (Medio)", 50),
            ("25% (Noche)", 25),
            ("0% (Apagado)", 0)
        ]
        let currentPct = Int(round(engine.profile.brightness * 100))
        for (label, pct) in levels {
            let mi = NSMenuItem(title: label, action: #selector(selectBrightnessFromMenu(_:)), keyEquivalent: "")
            mi.tag = pct
            mi.target = self
            if abs(currentPct - pct) <= 5 {
                mi.state = .on
            }
            brightnessMenu.addItem(mi)
        }
        let brightnessRoot = NSMenuItem(title: "Brillo (\(currentPct)%)", action: nil, keyEquivalent: "")
        brightnessRoot.submenu = brightnessMenu
        menu.addItem(brightnessRoot)

        menu.addItem(NSMenuItem.separator())

        let outputItem = NSMenuItem(
            title: engine.isOutputEnabled ? "Pausar salida USB" : "Reanudar salida USB",
            action: #selector(toggleOutputFromMenu),
            keyEquivalent: ""
        )
        outputItem.target = self
        menu.addItem(outputItem)

        let offItem = NSMenuItem(title: "Apagar LEDs", action: #selector(turnOffFromMenu), keyEquivalent: "")
        offItem.target = self
        menu.addItem(offItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Salir completamente", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectSavedProfileFromMenu(_ sender: NSMenuItem) {
        if sender.tag >= 0 && sender.tag < engine.savedProfiles.count {
            engine.loadProfile(engine.savedProfiles[sender.tag])
        }
    }

    @objc private func selectPresetFromMenu(_ sender: NSMenuItem) {
        let presets = LightingProfile.builtInPresets
        if sender.tag >= 0 && sender.tag < presets.count {
            engine.loadProfile(presets[sender.tag])
        }
    }

    @objc private func selectBrightnessFromMenu(_ sender: NSMenuItem) {
        engine.profile.brightness = Double(sender.tag) / 100.0
    }

    @objc private func toggleOutputFromMenu() {
        engine.isOutputEnabled.toggle()
    }

    @objc private func turnOffFromMenu() {
        engine.turnAllOff()
    }

    @objc private func quitApp() {
        engine.shutdown()
        NSApp.terminate(nil)
    }
}
