import SwiftUI
import AppKit

enum InspectorTab: String, CaseIterable, Identifiable {
    case perKey = "Tecla"
    case global = "Global"
    case profiles = "Perfiles"
    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject var engine: RGBEngine

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if engine.connectionState == .permissionRequired {
                permissionBanner
            }
            Divider().opacity(0.25)

            HStack(spacing: 0) {
                // Left/Main interactive keyboard workspace
                VStack(spacing: 14) {
                    toolbarRow
                    KeyboardCanvasView(
                        engine: engine,
                        liveFrames: engine.liveFrames,
                        onKeyInteracted: {
                            if engine.activeTool == .select && !engine.selectedKeyIds.isEmpty {
                                engine.inspectorTab = .perKey
                            }
                        }
                    )
                    .padding(.horizontal, 16)

                    statusFooterBar
                    presetsStrip
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: NSColor(calibratedRed: 0.075, green: 0.08, blue: 0.095, alpha: 1)))

                Divider().opacity(0.25)

                // Right inspector sidebar
                VStack(spacing: 0) {
                    Picker("", selection: $engine.inspectorTab) {
                        ForEach(InspectorTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(12)

                    Divider().opacity(0.2)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            switch engine.inspectorTab {
                            case .perKey:
                                perKeyInspector
                            case .global:
                                globalInspector
                            case .profiles:
                                profilesInspector
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: 372)
                .background(Color(nsColor: NSColor(calibratedRed: 0.105, green: 0.11, blue: 0.13, alpha: 1)))
            }
        }
        .frame(minWidth: 1120, minHeight: 660)
        .preferredColorScheme(.dark)
        .onAppear {
            engine.hexInput = engine.brushOverride.color.hexString
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.15, blue: 0.28), Color(red: 0.55, green: 0.12, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Redragon Olaf K648")
                        .font(.system(size: 14, weight: .bold))
                    Text("Controlador RGB nativo para macOS")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Connection pill
            HStack(spacing: 7) {
                Circle()
                    .fill(connectionDotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: connectionDotColor.opacity(0.8), radius: 4)
                Text(engine.connectionState.statusText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().stroke(connectionDotColor.opacity(0.35), lineWidth: 1))

            Button {
                engine.simulateReactiveKeypress()
            } label: {
                Label("Simular tecla", systemImage: "bolt.fill")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Dispara una pulsación de prueba para previsualizar efectos reactivos")

            Button {
                engine.triggerTestSweep()
            } label: {
                Label("Probar LEDs", systemImage: "wand.and.stars")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Ejecuta un barrido arcoíris seguro de 3 segundos sobre el teclado")

            Button {
                engine.turnAllOff()
            } label: {
                Label("Apagar", systemImage: "moon.fill")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Apaga todos los LEDs")

            Toggle(isOn: $engine.isOutputEnabled) {
                Text("Salida USB")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Activa o pausa el envío de colores al teclado físico")

            Button {
                engine.reconnect()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Reconectar teclado USB")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: NSColor(calibratedRed: 0.095, green: 0.10, blue: 0.12, alpha: 1)))
    }

    private var connectionDotColor: Color {
        switch engine.connectionState {
        case .connected: return .green
        case .permissionRequired: return .orange
        case .disconnected: return .red
        case .error: return .red
        }
    }

    // MARK: - TCC Input Monitoring Banner

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("macOS requiere permiso de \"Monitoreo de entrada\" para controlar los LEDs USB")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Habilita \"Redragon Olaf RGB\" en Ajustes del Sistema → Privacidad y seguridad → Monitoreo de entrada y luego reinicia la app. (Solo envía paquetes de luz al chip RGB, nunca registra tu escritura.)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Solicitar permiso") {
                engine.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)

            Button("Abrir Ajustes") {
                engine.openInputMonitoringSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Reiniciar app") {
                engine.relaunchApp()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.14))
    }

    // MARK: - Keyboard Toolbar

    private var toolbarRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Picker("Herramienta", selection: $engine.activeTool) {
                    ForEach(InteractionTool.allCases) { tool in
                        Label(tool.rawValue, systemImage: toolIcon(tool)).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)
                .onChange(of: engine.activeTool) { _, tool in
                    if tool == .paint {
                        engine.inspectorTab = .perKey
                    }
                }

                Spacer()

                // Quick brightness inline control
                HStack(spacing: 6) {
                    Image(systemName: "sun.min.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Slider(value: $engine.profile.brightness, in: 0...1)
                        .frame(width: 115)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow.opacity(0.9))
                    Text("\(Int(round(engine.profile.brightness * 100)))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.05)))
            }

            // Quick zone selection chips
            HStack(spacing: 6) {
                Text("Zonas:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                ForEach(KeyZone.allCases) { zone in
                    Button(zone.rawValue) {
                        engine.selectZone(zone)
                        engine.inspectorTab = .perKey
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.07)))
                    .foregroundColor(.primary.opacity(0.9))
                }

                Spacer()

                if !engine.selectedKeyIds.isEmpty {
                    Button("Deseleccionar (\(engine.selectedKeyIds.count))") {
                        engine.clearSelection()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.cyan)
                }

                if !engine.profile.keyOverrides.isEmpty {
                    Button("Limpiar teclas (\(engine.profile.keyOverrides.count))") {
                        engine.clearAllOverrides()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func toolIcon(_ tool: InteractionTool) -> String {
        switch tool {
        case .select: return "cursorarrow"
        case .paint: return "paintbrush.fill"
        case .erase: return "eraser.fill"
        }
    }

    // MARK: - Footer Status Info

    private var statusFooterBar: some View {
        HStack {
            if let hidId = engine.hoveredKeyId, let k = K648Layout.keyById[hidId] {
                let ov = engine.profile.keyOverrides[k.id]
                let effName = ov?.effect.displayName ?? "Global (\(engine.profile.globalEffect.displayName))"
                Text("Tecla: \(k.name)  •  LED Slot \(k.slot)  •  \(effName)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text(toolHintText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            LiveKeypressBadge(liveFrames: engine.liveFrames)
            Text("94 teclas • US ANSI • Protocolo seguro 0x08")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.75))
        }
        .padding(.horizontal, 18)
    }

    private var toolHintText: String {
        switch engine.activeTool {
        case .select:
            return "Tip: Haz clic en una tecla (⌘+clic para varias o arrastra) para cambiar su color y efecto individual."
        case .paint:
            return "Modo Pincel: Haz clic o arrastra sobre las teclas para pintarlas con el color y efecto del panel derecho."
        case .erase:
            return "Modo Borrador: Haz clic o arrastra sobre las teclas para devolverlas al efecto global."
        }
    }

    // MARK: - Quick Presets Strip

    private var presetsStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Presets rápidos")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LightingProfile.builtInPresets) { preset in
                        PresetCardView(
                            preset: preset,
                            isActive: engine.profile.name == preset.name && engine.profile.globalEffect == preset.globalEffect
                        ) {
                            engine.loadProfile(preset)
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Inspector Tab 1: Per-Key Color & Effect

    private var perKeyInspector: some View {
        let isBrushMode = engine.activeTool == .paint
        let targetIds = engine.selectedKeyIds
        let hasTargets = !targetIds.isEmpty

        return VStack(alignment: .leading, spacing: 14) {
            // Header card describing selection / brush target
            VStack(alignment: .leading, spacing: 4) {
                if isBrushMode {
                    Label("Configuración del Pincel", systemImage: "paintbrush.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("Haz clic o arrastra sobre cualquier tecla para aplicar este color y efecto.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else if hasTargets {
                    let names = targetIds.compactMap { K648Layout.keyById[$0]?.name }.sorted()
                    let title = names.count == 1 ? "Tecla: \(names[0])" : "\(names.count) teclas seleccionadas"
                    Label(title, systemImage: "keyboard.badge.ellipsis")
                        .font(.system(size: 13, weight: .bold))
                    Text(names.prefix(12).joined(separator: ", ") + (names.count > 12 ? "…" : ""))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Label("Ninguna tecla seleccionada", systemImage: "cursorarrow.click")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("Haz clic en una tecla del teclado (o elige una zona arriba) para cambiar su color y efecto individual.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05)))

            // Per-key effect picker grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Efecto de la tecla")
                    .font(.system(size: 12, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(KeyEffect.allCases) { eff in
                        let selected = currentKeyOverride.effect == eff
                        Button {
                            updateActiveKeyOverride { $0.effect = eff }
                        } label: {
                            HStack(spacing: 5) {
                                Text(eff.shortBadge.isEmpty ? "○" : eff.shortBadge)
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(width: 14)
                                Text(eff.displayName)
                                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(selected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Primary color of key (always accessible except Off/Rainbow; picking a color auto-enables Solid if Inherit)
            if currentKeyOverride.effect != .off && currentKeyOverride.effect != .rainbow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Color de la tecla")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        ColorPicker("", selection: keyPrimaryColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }

                    // Hex field
                    HStack(spacing: 6) {
                        Text("HEX")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                        TextField("#00E5FF", text: $engine.hexInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5, design: .monospaced))
                            .onSubmit {
                                let col = RGBColor(hex: engine.hexInput)
                                updateActiveKeyOverride { ov in
                                    ov.color = col
                                    if ov.effect == .inherit || ov.effect == .off {
                                        ov.effect = .solid
                                    }
                                }
                            }
                        Button("Aplicar") {
                            let col = RGBColor(hex: engine.hexInput)
                            updateActiveKeyOverride { ov in
                                ov.color = col
                                if ov.effect == .inherit || ov.effect == .off {
                                    ov.effect = .solid
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    swatchGrid(selected: currentKeyOverride.color) { col in
                        engine.hexInput = col.hexString
                        updateActiveKeyOverride { ov in
                            ov.color = col
                            if ov.effect == .inherit || ov.effect == .off {
                                ov.effect = .solid
                            }
                        }
                    }
                }
            }

            // Secondary color for Dual Fade or Reactive Flash
            if currentKeyOverride.effect.usesSecondaryColor {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(currentKeyOverride.effect == .reactiveFlash ? "Color al pulsar (destello)" : "Color secundario (Alternar)")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        ColorPicker("", selection: keySecondaryColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }
                    swatchGrid(selected: currentKeyOverride.secondaryColor) { col in
                        updateActiveKeyOverride { $0.secondaryColor = col }
                    }
                }
            }

            // Per-key speed slider
            if currentKeyOverride.effect.usesSpeed {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(currentKeyOverride.effect == .reactiveFade || currentKeyOverride.effect == .reactiveFlash ? "Velocidad de desvanecido" : "Velocidad de esta tecla")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(String(format: "%.1f×", currentKeyOverride.speed))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: keySpeedBinding, in: 0.3...3.0)
                }
            }

            // Action buttons
            if hasTargets && !isBrushMode {
                Divider().opacity(0.2)
                HStack(spacing: 8) {
                    Button {
                        engine.applyOverride(engine.brushOverride, to: targetIds)
                    } label: {
                        Label("Aplicar a selección", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button {
                        engine.clearOverrides(for: targetIds)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .help("Devolver estas teclas al efecto global")
                }
            }
        }
    }

    private var currentKeyOverride: KeyOverride {
        if engine.activeTool == .select, let firstId = engine.selectedKeyIds.first {
            if let existing = engine.profile.keyOverrides[firstId] {
                return existing
            }
            var inherited = engine.brushOverride
            inherited.effect = .inherit
            return inherited
        }
        return engine.brushOverride
    }

    private func updateActiveKeyOverride(_ mutate: (inout KeyOverride) -> Void) {
        var ov = currentKeyOverride
        mutate(&ov)
        if ov.effect != .inherit {
            engine.brushOverride = ov
        }
        if engine.activeTool == .select && !engine.selectedKeyIds.isEmpty {
            engine.applyOverride(ov, to: engine.selectedKeyIds)
        }
    }

    private var keyPrimaryColorBinding: Binding<Color> {
        Binding(
            get: { currentKeyOverride.color.swiftUIColor },
            set: { newCol in
                let rgb = RGBColor(color: newCol)
                engine.hexInput = rgb.hexString
                updateActiveKeyOverride { ov in
                    ov.color = rgb
                    if ov.effect == .inherit || ov.effect == .off {
                        ov.effect = .solid
                    }
                }
            }
        )
    }

    private var keySecondaryColorBinding: Binding<Color> {
        Binding(
            get: { currentKeyOverride.secondaryColor.swiftUIColor },
            set: { newCol in
                let rgb = RGBColor(color: newCol)
                updateActiveKeyOverride { $0.secondaryColor = rgb }
            }
        )
    }

    private var keySpeedBinding: Binding<Double> {
        Binding(
            get: { currentKeyOverride.speed },
            set: { newVal in
                updateActiveKeyOverride { $0.speed = newVal }
            }
        )
    }

    // MARK: - Inspector Tab 2: Global Effect

    private var globalInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Reactive effects section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("Efectos reactivos al teclear")
                        .font(.system(size: 12, weight: .semibold))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(GlobalEffect.reactiveEffects) { eff in
                        let selected = engine.profile.globalEffect == eff
                        Button {
                            engine.profile.globalEffect = eff
                            engine.simulateReactiveKeypress()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: eff.iconName)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(selected ? .white : .cyan)
                                    .frame(width: 15)
                                Text(eff.displayName)
                                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selected ? Color.cyan.opacity(0.32) : Color.cyan.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(selected ? Color.cyan : Color.cyan.opacity(0.22), lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Ambient global effect grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Efectos ambientales")
                    .font(.system(size: 12, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(GlobalEffect.ambientEffects) { eff in
                        let selected = engine.profile.globalEffect == eff
                        Button {
                            engine.profile.globalEffect = eff
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: eff.iconName)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(selected ? .white : .cyan)
                                    .frame(width: 15)
                                Text(eff.displayName)
                                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selected ? Color.accentColor.opacity(0.32) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(selected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Optional reactive overlay on top of ambient effects
            if !engine.profile.globalEffect.isReactive {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(.pink)
                        Text("Capa reactiva sobre este modo")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(ReactiveOverlayMode.allCases) { mode in
                            let selected = engine.profile.reactiveOverlay == mode
                            Button {
                                engine.profile.reactiveOverlay = mode
                                if mode != .none {
                                    engine.simulateReactiveKeypress()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 11))
                                        .foregroundColor(selected ? .white : .pink)
                                        .frame(width: 14)
                                    Text(mode.displayName)
                                        .font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(selected ? Color.pink.opacity(0.30) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(selected ? Color.pink : Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if engine.profile.reactiveOverlay != .none && engine.profile.reactiveOverlay != .rainbowRipple {
                        HStack {
                            Text("Color del destello reactivo")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { engine.profile.reactiveOverlayColor.swiftUIColor },
                                set: { engine.profile.reactiveOverlayColor = RGBColor(color: $0) }
                            ), supportsOpacity: false)
                            .labelsHidden()
                        }
                    }
                }
            }

            // Direction (2x2 button grid so it never overflows the sidebar width)
            if engine.profile.globalEffect.usesDirection {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dirección")
                        .font(.system(size: 12, weight: .semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(WaveDirection.allCases) { dir in
                            let selected = engine.profile.direction == dir
                            Button {
                                engine.profile.direction = dir
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: dir.iconName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(selected ? .white : .cyan)
                                    Text(dir.displayName)
                                        .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(selected ? Color.accentColor.opacity(0.32) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(selected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Master brightness & speed
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Brillo maestro")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(Int(round(engine.profile.brightness * 100)))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $engine.profile.brightness, in: 0...1)
                }

                if engine.profile.globalEffect.usesSpeed || engine.profile.reactiveOverlay != .none {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Velocidad")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(String(format: "%.1f×", engine.profile.speed))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $engine.profile.speed, in: 0.2...3.0)
                    }
                }
            }

            // Primary global color
            if engine.profile.globalEffect.usesPrimaryColor {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(engine.profile.globalEffect.isReactive ? "Color reactivo (al teclear)" : "Color principal")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { engine.profile.primaryColor.swiftUIColor },
                            set: { engine.profile.primaryColor = RGBColor(color: $0) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                    swatchGrid(selected: engine.profile.primaryColor) { col in
                        engine.profile.primaryColor = col
                    }
                }
            }

            // Secondary global color
            if engine.profile.globalEffect.usesSecondaryColor {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(engine.profile.globalEffect.isReactive ? "Color de fondo (en reposo)" : "Color secundario")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { engine.profile.secondaryColor.swiftUIColor },
                            set: { engine.profile.secondaryColor = RGBColor(color: $0) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                    swatchGrid(selected: engine.profile.secondaryColor) { col in
                        engine.profile.secondaryColor = col
                    }
                }
            }

            Divider().opacity(0.2)

            // Hardware / App Options
            VStack(alignment: .leading, spacing: 9) {
                Text("Ajustes de uso diario")
                    .font(.system(size: 12, weight: .semibold))
                Toggle("Apagar LEDs al bloquear pantalla o dormir", isOn: $engine.turnOffOnLockOrSleep)
                    .font(.system(size: 11.5))
                Toggle("Mantener activo en barra de menú al cerrar", isOn: $engine.keepRunningInMenuBar)
                    .font(.system(size: 11.5))
                Toggle("Iniciar oculta en la barra de menú", isOn: $engine.launchHiddenInMenuBar)
                    .font(.system(size: 11.5))
                Toggle("Corrección gamma para LEDs físicos", isOn: $engine.gammaCorrection)
                    .font(.system(size: 11.5))

                Button {
                    engine.openLoginItemsSettings()
                } label: {
                    Label("Abrir Ítems de inicio de sesión", systemImage: "gearshape")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Inspector Tab 3: Profiles

    private var profilesInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Guardar diseño actual")
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 6) {
                    TextField("Nombre del perfil (ej. Mi Setup)", text: $engine.newProfileName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveProfileAction()
                        }
                    Button("Guardar") {
                        saveProfileAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(engine.newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Divider().opacity(0.2)

            VStack(alignment: .leading, spacing: 8) {
                Text("Mis perfiles guardados")
                    .font(.system(size: 12, weight: .semibold))

                if engine.savedProfiles.isEmpty {
                    Text("Aún no guardaste perfiles propios. Configura tus teclas y guarda tu diseño arriba.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(engine.savedProfiles) { item in
                        HStack {
                            Circle()
                                .fill(item.primaryColor.swiftUIColor)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text("\(item.globalEffect.displayName) • \(item.keyOverrides.count) teclas")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Cargar") {
                                engine.loadProfile(item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                engine.deleteSavedProfile(item)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                    }
                }
            }

            Divider().opacity(0.2)

            VStack(alignment: .leading, spacing: 8) {
                Text("Presets incluidos")
                    .font(.system(size: 12, weight: .semibold))
                ForEach(LightingProfile.builtInPresets) { preset in
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [preset.primaryColor.swiftUIColor, preset.secondaryColor.swiftUIColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 24, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(preset.name)
                                .font(.system(size: 12, weight: .medium))
                            Text(preset.globalEffect.displayName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Aplicar") {
                            engine.loadProfile(preset)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                }
            }
        }
    }

    private func saveProfileAction() {
        engine.saveCurrentProfile(named: engine.newProfileName)
        engine.newProfileName = ""
    }

    // MARK: - Swatch Grid Helper

    private func swatchGrid(selected: RGBColor, onPick: @escaping (RGBColor) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(RGBColor.swatches, id: \.self) { swatch in
                let isSel = swatch.hexString == selected.hexString
                Button {
                    onPick(swatch)
                } label: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(swatch.swiftUIColor)
                        .frame(height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSel ? Color.white : Color.white.opacity(0.2), lineWidth: isSel ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Live Keypress Indicator Badge

struct LiveKeypressBadge: View {
    @ObservedObject var liveFrames: LiveFrameStore

    var body: some View {
        if let name = liveFrames.lastPressedKeyName {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.cyan)
                Text("Tecla: \(name)")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.cyan.opacity(0.14)))
            .padding(.trailing, 6)
        }
    }
}

// MARK: - Preset Card

struct PresetCardView: View {
    let preset: LightingProfile
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        preset.globalEffect == .rainbowWave || preset.globalEffect == .spectrumCycle || preset.globalEffect == .reactiveRainbowRipple
                        ? LinearGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple], startPoint: .leading, endPoint: .trailing)
                        : (preset.globalEffect == .reactiveHeatmap
                           ? LinearGradient(colors: [Color(red: 0.05, green: 0.15, blue: 0.45), .cyan, .yellow, .red], startPoint: .leading, endPoint: .trailing)
                           : LinearGradient(colors: [preset.primaryColor.swiftUIColor, preset.secondaryColor.swiftUIColor], startPoint: .leading, endPoint: .trailing))
                    )
                    .frame(height: 6)

                HStack(spacing: 4) {
                    if preset.globalEffect.isReactive || preset.reactiveOverlay != .none {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    Text(preset.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Text(preset.globalEffect.displayName)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(9)
            .frame(width: 138, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isActive ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isActive ? Color.accentColor : Color.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive 94-Key Redragon K648 Olaf Keyboard Canvas

struct KeyboardCanvasView: View {
    @ObservedObject var engine: RGBEngine
    @ObservedObject var liveFrames: LiveFrameStore
    let onKeyInteracted: () -> Void

    var body: some View {
        GeometryReader { geo in
            let availW = max(100, geo.size.width)
            let availH = max(100, geo.size.height)
            let padding: CGFloat = 18
            let scaleX = (availW - padding * 2) / K648Layout.canvasWidth
            let scaleY = (availH - padding * 2) / K648Layout.canvasHeight
            let scale = min(scaleX, scaleY)
            let boardW = K648Layout.canvasWidth * scale
            let boardH = K648Layout.canvasHeight * scale

            ZStack {
                // Brushed aluminum chassis frame (matching Redragon K648 Olaf)
                RoundedRectangle(cornerRadius: 16 * min(1.2, scale))
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.17, blue: 0.195),
                                Color(red: 0.11, green: 0.115, blue: 0.135)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: boardW + padding * 2, height: boardH + padding * 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16 * min(1.2, scale))
                            .stroke(Color.white.opacity(0.14), lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.65), radius: 18, x: 0, y: 10)

                // Subtle engraved badge
                VStack {
                    HStack {
                        Text("REDRAGON  OLAF  K648")
                            .font(.system(size: max(8, 8.5 * scale), weight: .bold, design: .rounded))
                            .tracking(2.0)
                            .foregroundColor(Color.white.opacity(0.22))
                        Spacer()
                    }
                    .padding(.horizontal, padding + 10)
                    .padding(.top, 5)
                    Spacer()
                }
                .frame(width: boardW + padding * 2, height: boardH + padding * 2)

                // Keycaps layer
                ZStack(alignment: .topLeading) {
                    ForEach(K648Layout.keys) { key in
                        let liveColor = liveFrames.colors[key.id] ?? .black
                        let isSelected = engine.selectedKeyIds.contains(key.id)
                        let override = engine.profile.keyOverrides[key.id]
                        let isHovered = engine.hoveredKeyId == key.id

                        KeycapView(
                            key: key,
                            scale: scale,
                            ledColor: liveColor,
                            isSelected: isSelected,
                            isHovered: isHovered,
                            override: override
                        )
                        .offset(x: key.x * scale, y: key.y * scale)
                        .onHover { hovering in
                            if hovering {
                                engine.hoveredKeyId = key.id
                            } else if engine.hoveredKeyId == key.id {
                                engine.hoveredKeyId = nil
                            }
                        }
                    }
                }
                .frame(width: boardW, height: boardH, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            let pt = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                            if let hit = hitTestKey(at: pt) {
                                if engine.lastDraggedKeyId == nil {
                                    // Initial press
                                    let flags = NSEvent.modifierFlags
                                    let additive = flags.contains(.command) || flags.contains(.shift)
                                    engine.handleKeyClick(hit, additive: additive)
                                    onKeyInteracted()
                                    engine.lastDraggedKeyId = hit.id
                                } else if engine.lastDraggedKeyId != hit.id {
                                    // Dragging onto another key
                                    engine.handleKeyDragPaint(hit)
                                    onKeyInteracted()
                                    engine.lastDraggedKeyId = hit.id
                                }
                            }
                        }
                        .onEnded { _ in
                            engine.lastDraggedKeyId = nil
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 270)
    }

    private func hitTestKey(at point: CGPoint) -> KeyboardKey? {
        for key in K648Layout.keys {
            if point.x >= key.x && point.x <= key.x + key.width &&
               point.y >= key.y && point.y <= key.y + key.height {
                return key
            }
        }
        return nil
    }
}

struct KeycapView: View {
    let key: KeyboardKey
    let scale: CGFloat
    let ledColor: RGBColor
    let isSelected: Bool
    let isHovered: Bool
    let override: KeyOverride?

    var body: some View {
        let w = key.width * scale
        let h = key.height * scale
        let radius = max(3.5, 5.0 * scale)
        let rgb = ledColor.swiftUIColor
        let lum = 0.299 * ledColor.r + 0.587 * ledColor.g + 0.114 * ledColor.b

        ZStack {
            // Subtle LED backlight halo
            RoundedRectangle(cornerRadius: radius)
                .fill(rgb.opacity(0.32))
                .blur(radius: 3.5 * scale)

            // Keycap dark body tinted by LED glow
            RoundedRectangle(cornerRadius: radius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.145, blue: 0.165),
                            Color(red: 0.085, green: 0.09, blue: 0.105)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .fill(rgb.opacity(0.24))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(
                            isSelected
                            ? Color.white
                            : (isHovered ? Color.white.opacity(0.65) : rgb.opacity(0.75)),
                            lineWidth: isSelected ? 2.2 : (isHovered ? 1.5 : 1.0)
                        )
                )

            // Legend illuminated with the LED color (legible even when dark)
            Text(key.label)
                .font(.system(
                    size: fontSize(for: key.label, scale: scale),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundColor(lum > 0.18 ? rgb.opacity(0.98) : Color.white.opacity(0.45))
                .shadow(color: rgb.opacity(0.7), radius: 2.5)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 2)

            // Small badge if this key has a custom per-key override
            if let ov = override, ov.effect != .inherit {
                VStack {
                    HStack {
                        Spacer()
                        Text(ov.effect.shortBadge)
                            .font(.system(size: max(6.5, 7 * scale), weight: .heavy))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.trailing, 2.5)
                            .padding(.top, 1)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: w, height: h)
    }

    private func fontSize(for label: String, scale: CGFloat) -> CGFloat {
        if label.count >= 4 {
            return max(7.0, 7.8 * scale)
        } else if label.count >= 2 {
            return max(8.0, 9.0 * scale)
        } else {
            return max(9.5, 11.0 * scale)
        }
    }
}
