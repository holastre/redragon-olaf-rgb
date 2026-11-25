import Foundation
import SwiftUI
import Combine
import AppKit

enum InteractionTool: String, CaseIterable, Identifiable {
    case select = "Seleccionar"
    case paint = "Pincel"
    case erase = "Borrador"
    var id: String { rawValue }
}

private struct ReactivePulseEvent {
    let keyId: String
    let normX: Double
    let normY: Double
    let timestamp: CFTimeInterval
    let hue: Double
    let splashTargets: [String: Double] // neighbor keyId -> intensity weight
}

@MainActor
final class LiveFrameStore: ObservableObject {
    @Published var colors: [String: RGBColor] = [:]
    @Published var lastPressedKeyName: String? = nil
}

@MainActor
final class RGBEngine: ObservableObject {
    @Published var profile: LightingProfile {
        didSet {
            scheduleSave()
            updateAnimationState()
            renderNow(forceSend: true)
        }
    }
    @Published var savedProfiles: [LightingProfile] = [] {
        didSet { scheduleSave() }
    }
    @Published var connectionState: HIDConnectionState = .disconnected
    @Published var isOutputEnabled: Bool = true {
        didSet {
            if isOutputEnabled {
                renderNow(forceSend: true)
            }
        }
    }
    @Published var gammaCorrection: Bool = true {
        didSet {
            scheduleSave()
            renderNow(forceSend: true)
        }
    }
    @Published var keepRunningInMenuBar: Bool = true {
        didSet { scheduleSave() }
    }
    @Published var launchHiddenInMenuBar: Bool = false {
        didSet { scheduleSave() }
    }
    @Published var turnOffOnLockOrSleep: Bool = true {
        didSet {
            scheduleSave()
            if !turnOffOnLockOrSleep && isSystemSuspended {
                setSystemAsleepOrLocked(false)
            }
        }
    }
    @Published private(set) var isSystemSuspended: Bool = false

    // Isolated live preview store so buttons/controls outside the keyboard canvas never re-render at 45 FPS
    let liveFrames = LiveFrameStore()

    // Interactive editor state
    @Published var selectedKeyIds: Set<String> = []
    @Published var activeTool: InteractionTool = .select
    @Published var inspectorTab: InspectorTab = .global
    @Published var newProfileName: String = ""
    @Published var hexInput: String = "#00E5FF"
    @Published var hoveredKeyId: String? = nil
    var lastDraggedKeyId: String? = nil
    @Published var brushOverride: KeyOverride = KeyOverride(
        effect: .solid,
        color: .cyan,
        secondaryColor: .white,
        speed: 1.0
    ) {
        didSet {
            let h = brushOverride.color.hexString
            if hexInput != h { hexInput = h }
        }
    }

    // Optional slot-by-slot LED test sweep (safe 0x08 test)
    @Published var isTestSweepActive: Bool = false
    private var testSweepStart: CFTimeInterval = 0

    // Real-time reactive state
    private var activePulses: [ReactivePulseEvent] = []
    private var heldKeyIds: Set<String> = []
    private var keyLastActiveTime: [String: CFTimeInterval] = [:]
    private var keyHeat: [String: Double] = [:]
    private var lastHeatUpdate: CFTimeInterval = CACurrentMediaTime()
    private var lastPressDedupe: [String: CFTimeInterval] = [:]
    private var reactiveHueCursor: Double = 0.0
    private var lastPressedClearWorkItem: DispatchWorkItem?

    private let hid = K648HIDController()
    private var renderTimer: Timer?
    private let startTime: CFTimeInterval = CACurrentMediaTime()
    private var saveWorkItem: DispatchWorkItem?
    private let stateURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RedragonOlafRGB", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.stateURL = dir.appendingPathComponent("state.json")

        if let loaded = Self.loadState(from: stateURL) {
            self.profile = loaded.activeProfile
            self.savedProfiles = loaded.savedProfiles
            self.gammaCorrection = loaded.gammaCorrection
            self.keepRunningInMenuBar = loaded.keepRunningInMenuBar
            self.launchHiddenInMenuBar = loaded.launchHiddenInMenuBar
            self.turnOffOnLockOrSleep = loaded.turnOffOnLockOrSleep
        } else {
            self.profile = LightingProfile.builtInPresets.first ?? LightingProfile(name: "Personalizado")
            self.savedProfiles = []
        }

        for key in K648Layout.keys {
            liveFrames.colors[key.id] = .black
        }

        hid.onStateChange = { [weak self] state in
            guard let self = self else { return }
            self.connectionState = state
            if state.isConnected {
                self.renderNow(forceSend: true)
            }
        }

        hid.onKeyEvent = { [weak self] usage, pressed in
            guard let self = self else { return }
            self.handlePhysicalHIDKey(usage: usage, pressed: pressed)
        }

        hid.start()
        updateAnimationState()
        renderNow(forceSend: true)
    }

    func shutdown() {
        renderTimer?.invalidate()
        renderTimer = nil
        saveNow()
        hid.stop()
    }

    // MARK: - Physical Keypress Reactive Input

    private func handlePhysicalHIDKey(usage: UInt32, pressed: Bool) {
        guard let key = K648Layout.keyByHIDUsage[usage] else { return }
        let now = CACurrentMediaTime()

        if pressed {
            // Dedupe in case both IF0 and IF1 report the same press within 15ms
            if let prev = lastPressDedupe[key.id], (now - prev) < 0.015 {
                return
            }
            lastPressDedupe[key.id] = now
            heldKeyIds.insert(key.id)
            triggerReactivePulse(for: key, at: now)
        } else {
            if heldKeyIds.remove(key.id) != nil {
                keyLastActiveTime[key.id] = now
                updateAnimationState()
            }
        }
    }

    /// Triggers a reactive pulse for any key (physical keypress or UI preview simulation).
    func triggerReactivePulse(for key: KeyboardKey, at now: CFTimeInterval = CACurrentMediaTime()) {
        keyLastActiveTime[key.id] = now
        keyHeat[key.id] = min(1.0, (keyHeat[key.id] ?? 0.0) + 0.28)
        lastHeatUpdate = now

        reactiveHueCursor = (reactiveHueCursor + 0.145).truncatingRemainder(dividingBy: 1.0)

        // Precompute nearby keys for reactiveSplash effect
        var splash: [String: Double] = [key.id: 1.0]
        let candidates = K648Layout.keys.compactMap { other -> (String, Double)? in
            guard other.id != key.id else { return nil }
            let dx = other.normX - key.normX
            let dy = (other.normY - key.normY) * 0.45
            let d = sqrt(dx * dx + dy * dy)
            return d < 0.22 ? (other.id, d) : nil
        }
        for (cid, dist) in candidates.shuffled().prefix(7) {
            let weight = max(0.35, 1.0 - dist / 0.24) * Double.random(in: 0.65...1.0)
            splash[cid] = weight
        }

        let event = ReactivePulseEvent(
            keyId: key.id,
            normX: key.normX,
            normY: key.normY,
            timestamp: now,
            hue: reactiveHueCursor,
            splashTargets: splash
        )
        activePulses.append(event)
        if activePulses.count > 28 {
            activePulses.removeFirst(activePulses.count - 28)
        }

        // Briefly display pressed key name in footer indicator
        liveFrames.lastPressedKeyName = key.name
        lastPressedClearWorkItem?.cancel()
        let clearItem = DispatchWorkItem { [weak self] in
            self?.liveFrames.lastPressedKeyName = nil
        }
        lastPressedClearWorkItem = clearItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: clearItem)

        // Zero-latency frame render + ensure smooth animation timer is running
        updateAnimationState()
        renderNow(forceSend: false)
    }

    /// Fires a demo reactive keypress from a central key so the user can preview reactive effects with a mouse click.
    func simulateReactiveKeypress() {
        let sampleNames = ["G", "H", "J", "F", "T", "Y", "R", "U", "Space", "Enter"]
        let chosenName = sampleNames.randomElement() ?? "G"
        if let key = K648Layout.keyByName[chosenName] ?? K648Layout.keys.first {
            triggerReactivePulse(for: key)
        }
    }

    // MARK: - Connection & Permissions

    func reconnect() {
        hid.reconnect()
    }

    func requestPermission() {
        K648HIDController.requestInputMonitoringPermission()
        openInputMonitoringSettings()
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Automatically blacks out the keyboard when macOS locks/sleeps and restores lighting on unlock/wake.
    func setSystemAsleepOrLocked(_ suspended: Bool) {
        if suspended {
            guard turnOffOnLockOrSleep else { return }
            isSystemSuspended = true
            heldKeyIds.removeAll()
            activePulses.removeAll()
            updateAnimationState()
            if isOutputEnabled {
                let black = [UInt8](repeating: 0, count: K648Layout.totalLedSlots * 3)
                hid.sendFrame(slotRGB: black, force: true)
            }
        } else {
            let wasSuspended = isSystemSuspended
            isSystemSuspended = false
            updateAnimationState()
            if wasSuspended || isOutputEnabled {
                renderNow(forceSend: true)
                // Re-sync shortly after wake in case the USB hub takes a moment to re-enumerate
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                    guard let self = self, !self.isSystemSuspended else { return }
                    if !self.connectionState.isConnected {
                        self.hid.reconnect()
                    }
                    self.renderNow(forceSend: true)
                }
            }
        }
    }

    func relaunchApp() {
        saveNow()
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Selection & Per-Key Editing

    func handleKeyClick(_ key: KeyboardKey, additive: Bool) {
        switch activeTool {
        case .select:
            if additive {
                if selectedKeyIds.contains(key.id) {
                    selectedKeyIds.remove(key.id)
                } else {
                    selectedKeyIds.insert(key.id)
                }
            } else {
                if selectedKeyIds == [key.id] {
                    selectedKeyIds.removeAll()
                } else {
                    selectedKeyIds = [key.id]
                }
            }
            if let existing = profile.keyOverrides[key.id] {
                brushOverride = existing
            }
        case .paint:
            applyOverride(brushOverride, to: [key.id])
            selectedKeyIds = [key.id]
        case .erase:
            clearOverrides(for: [key.id])
        }
    }

    func handleKeyDragPaint(_ key: KeyboardKey) {
        switch activeTool {
        case .paint:
            if profile.keyOverrides[key.id] != brushOverride {
                applyOverride(brushOverride, to: [key.id])
            }
        case .erase:
            if profile.keyOverrides[key.id] != nil {
                clearOverrides(for: [key.id])
            }
        case .select:
            selectedKeyIds.insert(key.id)
        }
    }

    func selectZone(_ zone: KeyZone) {
        if zone == .all {
            selectedKeyIds = Set(K648Layout.keys.map { $0.id })
        } else {
            selectedKeyIds = Set(K648Layout.keys.filter { $0.zone == zone }.map { $0.id })
        }
    }

    func clearSelection() {
        selectedKeyIds.removeAll()
    }

    func applyOverride(_ override: KeyOverride, to keyIds: Set<String>) {
        guard !keyIds.isEmpty else { return }
        var updated = profile
        for id in keyIds {
            if override.effect == .inherit {
                updated.keyOverrides.removeValue(forKey: id)
            } else {
                updated.keyOverrides[id] = override
            }
        }
        profile = updated
    }

    func clearOverrides(for keyIds: Set<String>) {
        guard !keyIds.isEmpty else { return }
        var updated = profile
        for id in keyIds {
            updated.keyOverrides.removeValue(forKey: id)
        }
        profile = updated
    }

    func clearAllOverrides() {
        var updated = profile
        updated.keyOverrides.removeAll()
        profile = updated
    }

    func turnAllOff() {
        var updated = profile
        updated.globalEffect = .customOnly
        updated.reactiveOverlay = .none
        updated.keyOverrides.removeAll()
        profile = updated
    }

    // MARK: - Profiles

    func loadProfile(_ preset: LightingProfile) {
        var copy = preset
        copy.id = UUID()
        profile = copy
        if copy.globalEffect.isReactive {
            simulateReactiveKeypress()
        }
    }

    func saveCurrentProfile(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var copy = profile
        copy.id = UUID()
        copy.name = trimmed
        if let idx = savedProfiles.firstIndex(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            savedProfiles[idx] = copy
        } else {
            savedProfiles.insert(copy, at: 0)
        }
    }

    func deleteSavedProfile(_ item: LightingProfile) {
        savedProfiles.removeAll { $0.id == item.id }
    }

    // MARK: - Safe LED Test Sweep

    func triggerTestSweep() {
        isTestSweepActive = true
        testSweepStart = CACurrentMediaTime()
        updateAnimationState()
        renderNow(forceSend: true)
    }

    // MARK: - Render Loop (45 FPS when animating/reactive, 0% CPU when idle static)

    private var hasActiveReactiveAnimations: Bool {
        !heldKeyIds.isEmpty || !activePulses.isEmpty || !keyLastActiveTime.isEmpty || !keyHeat.isEmpty
    }

    private func updateAnimationState() {
        if isSystemSuspended {
            renderTimer?.invalidate()
            renderTimer = nil
            return
        }
        let needsTimer = profile.hasAnyContinuousAnimation || hasActiveReactiveAnimations || isTestSweepActive
        if needsTimer {
            if renderTimer == nil {
                let timer = Timer(timeInterval: 1.0 / 45.0, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.renderNow(forceSend: false)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                renderTimer = timer
            }
        } else {
            renderTimer?.invalidate()
            renderTimer = nil
        }
    }

    private func pruneReactiveState(now: CFTimeInterval, speed: Double) {
        let maxPulseAge = max(1.4, 2.4 / max(0.3, speed))
        if !activePulses.isEmpty {
            activePulses.removeAll { (now - $0.timestamp) > maxPulseAge }
        }

        let maxTrailAge = max(1.5, 2.8 / max(0.3, speed))
        if !keyLastActiveTime.isEmpty {
            for (k, ts) in keyLastActiveTime {
                if !heldKeyIds.contains(k) && (now - ts) > maxTrailAge {
                    keyLastActiveTime.removeValue(forKey: k)
                }
            }
        }

        // Cool down heatmap gradually
        let dt = max(0.0, now - lastHeatUpdate)
        lastHeatUpdate = now
        if !keyHeat.isEmpty && dt > 0 {
            let decay = dt * 0.085 * max(0.35, speed)
            for (k, h) in keyHeat {
                if heldKeyIds.contains(k) {
                    keyHeat[k] = min(1.0, h + dt * 0.25)
                } else {
                    let next = h - decay
                    if next <= 0.004 {
                        keyHeat.removeValue(forKey: k)
                    } else {
                        keyHeat[k] = next
                    }
                }
            }
        }
    }

    func renderNow(forceSend: Bool) {
        if isSystemSuspended { return }
        let now = CACurrentMediaTime()
        let elapsed = now - startTime
        let p = profile

        if isTestSweepActive {
            let dt = now - testSweepStart
            if dt >= 3.2 {
                isTestSweepActive = false
                updateAnimationState()
            } else {
                renderTestSweep(progress: dt / 3.2)
                return
            }
        }

        pruneReactiveState(now: now, speed: p.speed)

        var nextPreview: [String: RGBColor] = Dictionary(minimumCapacity: K648Layout.keys.count)
        var slotBuffer = [UInt8](repeating: 0, count: K648Layout.totalLedSlots * 3)

        let t = elapsed * p.speed

        for key in K648Layout.keys {
            var color: RGBColor
            if let ov = p.keyOverrides[key.id], ov.effect != .inherit {
                color = evaluateKeyOverride(ov, key: key, elapsed: elapsed, now: now)
            } else {
                color = evaluateGlobalEffect(p, key: key, t: t, now: now)
            }

            // Optional reactive overlay on top of ANY non-pure-reactive global mode
            if p.reactiveOverlay != .none && !p.globalEffect.isReactive {
                color = applyReactiveOverlay(base: color, profile: p, key: key, now: now)
            }

            // UI preview shows brightness softly so dimmed keys remain legible
            let previewScale = p.brightness <= 0.001 ? 0.0 : (0.18 + 0.82 * p.brightness)
            nextPreview[key.id] = color.scaled(by: previewScale)

            let (r8, g8, b8) = color.toHardwareBytes(brightness: p.brightness, gammaCorrect: gammaCorrection)
            if key.slot >= 0 && key.slot < K648Layout.totalLedSlots {
                let idx = key.slot * 3
                slotBuffer[idx] = r8
                slotBuffer[idx + 1] = g8
                slotBuffer[idx + 2] = b8
            }
        }

        liveFrames.colors = nextPreview

        if isOutputEnabled {
            hid.sendFrame(slotRGB: slotBuffer, force: forceSend)
        }

        // Stop timer automatically once all reactive pulses have completely faded on a static mode
        if !profile.hasAnyContinuousAnimation && !hasActiveReactiveAnimations && !isTestSweepActive {
            updateAnimationState()
        }
    }

    private func renderTestSweep(progress: Double) {
        var nextPreview: [String: RGBColor] = Dictionary(minimumCapacity: K648Layout.keys.count)
        var slotBuffer = [UInt8](repeating: 0, count: K648Layout.totalLedSlots * 3)

        for key in K648Layout.keys {
            let dist = abs(key.normX - progress)
            let glow = max(0.0, 1.0 - dist * 5.5)
            let col = RGBColor.hsv(h: (key.normX + progress) * 0.9, s: 1.0, v: glow)
            nextPreview[key.id] = col
            let (r8, g8, b8) = col.toHardwareBytes(brightness: max(0.5, profile.brightness), gammaCorrect: gammaCorrection)
            let idx = key.slot * 3
            slotBuffer[idx] = r8
            slotBuffer[idx + 1] = g8
            slotBuffer[idx + 2] = b8
        }

        liveFrames.colors = nextPreview
        if isOutputEnabled {
            hid.sendFrame(slotRGB: slotBuffer, force: true)
        }
    }

    // MARK: - Effect Math

    private func waveCoord(for key: KeyboardKey, direction: WaveDirection) -> Double {
        switch direction {
        case .leftToRight: return key.normX
        case .rightToLeft: return 1.0 - key.normX
        case .diagonal: return (key.normX * 0.72 + key.normY * 0.28)
        case .topToBottom: return key.normY
        }
    }

    private func keyReactiveLevel(keyId: String, now: CFTimeInterval, decayRate: Double) -> Double {
        if heldKeyIds.contains(keyId) {
            return 1.0
        }
        guard let ts = keyLastActiveTime[keyId] else { return 0.0 }
        let age = max(0.0, now - ts)
        let level = exp(-age * decayRate)
        return level < 0.008 ? 0.0 : level
    }

    private func evaluateGlobalEffect(_ p: LightingProfile, key: KeyboardKey, t: Double, now: CFTimeInterval) -> RGBColor {
        switch p.globalEffect {
        case .solid:
            return p.primaryColor

        case .customOnly:
            return .black

        case .rainbowWave:
            let pos = waveCoord(for: key, direction: p.direction)
            let hue = pos - t * 0.28
            return RGBColor.hsv(h: hue, s: 1.0, v: 1.0)

        case .breathing:
            let phase = (sin(t * 1.8) + 1.0) * 0.5
            let level = 0.08 + 0.92 * (phase * phase)
            return p.primaryColor.scaled(by: level)

        case .spectrumCycle:
            return RGBColor.hsv(h: t * 0.12, s: 1.0, v: 1.0)

        case .aurora:
            let pos = waveCoord(for: key, direction: p.direction)
            let wave1 = (sin((pos * 3.8 - t * 1.4) * .pi) + 1.0) * 0.5
            let wave2 = (cos((key.normY * 2.2 + t * 0.9) * .pi) + 1.0) * 0.5
            let blend = 0.7 * wave1 + 0.3 * wave2
            let shimmer = 0.65 + 0.35 * sin(t * 2.1 + pos * 5.0)
            return p.primaryColor.blended(with: p.secondaryColor, t: blend).scaled(by: min(1.0, max(0.35, shimmer)))

        case .fire:
            let seed = Double(key.slot) * 1.6180339
            let flicker =
                0.5 * sin(t * 6.2 + seed * 3.1) +
                0.3 * sin(t * 11.4 + seed * 7.3) +
                0.2 * cos(t * 4.1 - key.normY * 8.0)
            let heat = min(1.0, max(0.0, (key.normY * 0.85) + 0.28 + flicker * 0.26))
            if heat < 0.35 {
                return RGBColor(r: heat / 0.35 * 0.85, g: 0.02, b: 0.0)
            } else if heat < 0.72 {
                let u = (heat - 0.35) / 0.37
                return RGBColor(r: 0.85 + 0.15 * u, g: 0.05 + 0.45 * u, b: 0.0)
            } else {
                let u = (heat - 0.72) / 0.28
                return RGBColor(r: 1.0, g: 0.50 + 0.48 * u, b: 0.12 * u)
            }

        case .matrixRain:
            let col = floor(key.normX * 19.0)
            let colHash = sin(col * 12.9898 + 4.1414) * 43758.5453
            let offset = colHash - floor(colHash)
            let colSpeed = 0.75 + (offset * 0.65)
            let dropY = (t * 0.55 * colSpeed + offset).truncatingRemainder(dividingBy: 1.55)
            let dist = dropY - key.normY
            if dist >= 0 && dist < 0.12 {
                return p.primaryColor.blended(with: .white, t: 0.55)
            } else if dist >= 0.12 && dist < 0.68 {
                let trail = 1.0 - (dist - 0.12) / 0.56
                return p.primaryColor.scaled(by: trail * trail)
            } else {
                return p.primaryColor.scaled(by: 0.05)
            }

        case .twinkle:
            let seed = Double(key.slot) * 2.39996
            let rate = 0.65 + (sin(seed) * 0.5 + 0.5) * 1.15
            let raw = (sin(t * rate * 2.4 + seed * 9.7) + 1.0) * 0.5
            let star = pow(raw, 7.0)
            let bg = p.secondaryColor.scaled(by: 0.25)
            return bg.blended(with: p.primaryColor, t: star)

        case .radialPulse:
            let dx = key.normX - 0.5
            let dy = (key.normY - 0.5) * 0.55
            let r = sqrt(dx * dx + dy * dy)
            let wave = (sin((r * 7.5 - t * 2.6) * .pi) + 1.0) * 0.5
            return p.secondaryColor.blended(with: p.primaryColor, t: wave)

        // MARK: Reactive Global Effects

        case .reactiveTrail:
            let bg = p.secondaryColor.scaled(by: 0.45)
            let level = keyReactiveLevel(keyId: key.id, now: now, decayRate: 2.3 * p.speed)
            if level <= 0.0 { return bg }
            let hotWhite = level > 0.85 ? (level - 0.85) / 0.15 * 0.4 : 0.0
            return bg.blended(with: p.primaryColor.blended(with: .white, t: hotWhite), t: level)

        case .reactiveRipple:
            let bg = p.secondaryColor.scaled(by: 0.45)
            var intensity = keyReactiveLevel(keyId: key.id, now: now, decayRate: 4.0 * p.speed) * 0.85
            for ev in activePulses {
                let age = now - ev.timestamp
                guard age >= 0 else { continue }
                let radius = age * 1.12 * p.speed
                let fade = exp(-age * 1.55 * p.speed)
                guard fade > 0.01 else { continue }
                let dx = key.normX - ev.normX
                let dy = (key.normY - ev.normY) * 0.42
                let dist = sqrt(dx * dx + dy * dy)
                let ring = exp(-pow((dist - radius) / 0.085, 2.0))
                intensity = min(1.0, intensity + ring * fade)
            }
            return bg.blended(with: p.primaryColor, t: intensity)

        case .reactiveRainbowRipple:
            let bg = p.secondaryColor.scaled(by: 0.35)
            var accR = bg.r
            var accG = bg.g
            var accB = bg.b
            for ev in activePulses {
                let age = now - ev.timestamp
                guard age >= 0 else { continue }
                let radius = age * 1.15 * p.speed
                let fade = exp(-age * 1.45 * p.speed)
                guard fade > 0.01 else { continue }
                let dx = key.normX - ev.normX
                let dy = (key.normY - ev.normY) * 0.42
                let dist = sqrt(dx * dx + dy * dy)
                let ring = exp(-pow((dist - radius) / 0.09, 2.0)) * fade
                if ring > 0.01 {
                    let waveColor = RGBColor.hsv(h: ev.hue + dist * 0.35, s: 1.0, v: 1.0)
                    accR = min(1.0, accR + waveColor.r * ring)
                    accG = min(1.0, accG + waveColor.g * ring)
                    accB = min(1.0, accB + waveColor.b * ring)
                }
            }
            return RGBColor(r: accR, g: accG, b: accB)

        case .reactiveCross:
            let bg = p.secondaryColor.scaled(by: 0.40)
            var beam = keyReactiveLevel(keyId: key.id, now: now, decayRate: 3.5 * p.speed)
            for ev in activePulses {
                let age = now - ev.timestamp
                guard age >= 0 else { continue }
                let travel = age * 1.65 * p.speed
                let fade = exp(-age * 2.1 * p.speed)
                guard fade > 0.01 else { continue }
                let dx = abs(key.normX - ev.normX)
                let dy = abs(key.normY - ev.normY)
                // Horizontal laser along same row
                if dy < 0.095 {
                    let front = exp(-pow((dx - travel) / 0.10, 2.0))
                    beam = min(1.0, beam + front * fade)
                }
                // Vertical laser along same column
                if dx < 0.055 {
                    let front = exp(-pow((dy * 0.55 - travel * 0.65) / 0.10, 2.0))
                    beam = min(1.0, beam + front * fade)
                }
            }
            let whiteCore = (heldKeyIds.contains(key.id) ? 0.45 : 0.0)
            return bg.blended(with: p.primaryColor.blended(with: .white, t: whiteCore), t: beam)

        case .reactiveSplash:
            let bg = p.secondaryColor.scaled(by: 0.35)
            var spark = keyReactiveLevel(keyId: key.id, now: now, decayRate: 3.0 * p.speed)
            for ev in activePulses {
                guard let weight = ev.splashTargets[key.id] else { continue }
                let age = now - ev.timestamp
                guard age >= 0 else { continue }
                let delay = (ev.keyId == key.id) ? 0.0 : 0.045
                if age >= delay {
                    let localAge = age - delay
                    let twinkle = 0.78 + 0.22 * sin(localAge * 26.0 + Double(key.slot))
                    let level = exp(-localAge * 3.2 * p.speed) * weight * twinkle
                    spark = min(1.0, max(spark, level))
                }
            }
            let hot = spark > 0.72 ? (spark - 0.72) / 0.28 * 0.65 : 0.0
            return bg.blended(with: p.primaryColor.blended(with: .white, t: hot), t: spark)

        case .reactiveHeatmap:
            let heat = keyHeat[key.id] ?? 0.0
            if heat <= 0.005 {
                return RGBColor(hex: "#08122E")
            } else if heat < 0.33 {
                let u = heat / 0.33
                return RGBColor(hex: "#08122E").blended(with: RGBColor(hex: "#00E5FF"), t: u)
            } else if heat < 0.66 {
                let u = (heat - 0.33) / 0.33
                return RGBColor(hex: "#00E5FF").blended(with: RGBColor(hex: "#FFD600"), t: u)
            } else {
                let u = (heat - 0.66) / 0.34
                return RGBColor(hex: "#FFD600").blended(with: RGBColor(hex: "#FF1744"), t: u)
            }
        }
    }

    private func applyReactiveOverlay(base: RGBColor, profile p: LightingProfile, key: KeyboardKey, now: CFTimeInterval) -> RGBColor {
        switch p.reactiveOverlay {
        case .none:
            return base

        case .keyFlash:
            let level = keyReactiveLevel(keyId: key.id, now: now, decayRate: 3.2 * p.speed)
            guard level > 0 else { return base }
            return base.blended(with: p.reactiveOverlayColor, t: level)

        case .ripple:
            var level = keyReactiveLevel(keyId: key.id, now: now, decayRate: 4.2 * p.speed) * 0.85
            for ev in activePulses {
                let age = now - ev.timestamp
                guard age >= 0 else { continue }
                let radius = age * 1.15 * p.speed
                let fade = exp(-age * 1.75 * p.speed)
                guard fade > 0.01 else { continue }
                let dx = key.normX - ev.normX
                let dy = (key.normY - ev.normY) * 0.42
                let dist = sqrt(dx * dx + dy * dy)
                let ring = exp(-pow((dist - radius) / 0.08, 2.0)) * fade
                level = min(1.0, level + ring)
            }
            guard level > 0.01 else { return base }
            return base.blended(with: p.reactiveOverlayColor, t: level)

        case .laserCross:
            var beam = keyReactiveLevel(keyId: key.id, now: now, decayRate: 3.8 * p.speed)
            for ev in activePulses {
                let age = now - ev.timestamp
                guard age >= 0 else { continue }
                let travel = age * 1.65 * p.speed
                let fade = exp(-age * 2.2 * p.speed)
                guard fade > 0.01 else { continue }
                let dx = abs(key.normX - ev.normX)
                let dy = abs(key.normY - ev.normY)
                if dy < 0.095 {
                    beam = min(1.0, beam + exp(-pow((dx - travel) / 0.095, 2.0)) * fade)
                }
                if dx < 0.055 {
                    beam = min(1.0, beam + exp(-pow((dy * 0.55 - travel * 0.65) / 0.095, 2.0)) * fade)
                }
            }
            guard beam > 0.01 else { return base }
            return base.blended(with: p.reactiveOverlayColor, t: beam)

        case .rainbowRipple:
            var out = base
            for ev in activePulses {
                let age = now - ev.timestamp
                guard age >= 0 else { continue }
                let radius = age * 1.15 * p.speed
                let fade = exp(-age * 1.6 * p.speed)
                guard fade > 0.01 else { continue }
                let dx = key.normX - ev.normX
                let dy = (key.normY - ev.normY) * 0.42
                let dist = sqrt(dx * dx + dy * dy)
                let ring = exp(-pow((dist - radius) / 0.085, 2.0)) * fade
                if ring > 0.01 {
                    let waveColor = RGBColor.hsv(h: ev.hue + dist * 0.35, s: 1.0, v: 1.0)
                    out = out.blended(with: waveColor, t: min(1.0, ring))
                }
            }
            return out
        }
    }

    private func evaluateKeyOverride(_ ov: KeyOverride, key: KeyboardKey, elapsed: CFTimeInterval, now: CFTimeInterval) -> RGBColor {
        let kt = elapsed * ov.speed
        switch ov.effect {
        case .inherit:
            return ov.color
        case .solid:
            return ov.color
        case .off:
            return .black
        case .breathing:
            let s = (sin(kt * 2.2) + 1.0) * 0.5
            return ov.color.scaled(by: 0.10 + 0.90 * s * s)
        case .heartbeat:
            let cycle = kt.truncatingRemainder(dividingBy: 1.25) / 1.25
            let beat1 = exp(-pow((cycle - 0.16) / 0.055, 2.0))
            let beat2 = 0.75 * exp(-pow((cycle - 0.34) / 0.065, 2.0))
            let level = min(1.0, 0.12 + max(beat1, beat2))
            return ov.color.scaled(by: level)
        case .rainbow:
            let offset = Double(key.slot) * 0.015
            return RGBColor.hsv(h: kt * 0.22 + offset, s: 1.0, v: 1.0)
        case .sparkle:
            let phase = (sin(kt * 3.8 + Double(key.slot) * 1.7) + 1.0) * 0.5
            let flash = pow(phase, 8.0)
            return ov.color.scaled(by: 0.35 + 0.65 * flash).blended(with: .white, t: flash * 0.45)
        case .blink:
            let on = sin(kt * 4.5) >= 0
            return on ? ov.color : ov.color.scaled(by: 0.05)
        case .dualFade:
            let mix = (sin(kt * 2.0) + 1.0) * 0.5
            return ov.color.blended(with: ov.secondaryColor, t: mix)
        case .reactiveFade:
            let level = keyReactiveLevel(keyId: key.id, now: now, decayRate: 2.5 * ov.speed)
            return ov.color.scaled(by: 0.06 + 0.94 * level)
        case .reactiveFlash:
            let level = keyReactiveLevel(keyId: key.id, now: now, decayRate: 3.0 * ov.speed)
            return ov.color.blended(with: ov.secondaryColor, t: level)
        }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    private func saveNow() {
        let state = AppPersistedState(
            activeProfile: profile,
            savedProfiles: savedProfiles,
            gammaCorrection: gammaCorrection,
            keepRunningInMenuBar: keepRunningInMenuBar,
            launchHiddenInMenuBar: launchHiddenInMenuBar,
            turnOffOnLockOrSleep: turnOffOnLockOrSleep
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    private static func loadState(from url: URL) -> AppPersistedState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppPersistedState.self, from: data)
    }
}
