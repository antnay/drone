//
//  EqualizerView.swift
//  drone
//
//  Interactive parametric EQ window: master controls + preset management on
//  top, an interactive log-frequency response curve with draggable band nodes
//  in the center.
//

import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject var eq: EqualizerController

    @State private var selectedBandID: UUID?
    @State private var showSaveAs = false
    @State private var newPresetName = ""

    /// Draft text for the preamp field. Committed to settings only on Enter (or
    /// focus loss); kept in sync with the slider value while not being edited.
    @State private var preampText = ""
    @FocusState private var preampFocused: Bool

    /// Shared, range-clamped binding for the preamp so the slider and the
    /// editable text field stay in sync and never exceed the valid range.
    private var preampBinding: Binding<Double> {
        Binding(
            get: { eq.settings.preamp },
            set: { newValue in
                eq.settings.preamp = min(
                    EQBand.maxGain, max(EQBand.minGain, newValue)
                )
            }
        )
    }

    /// Parses the draft preamp text, clamps it, applies it to settings, and
    /// normalises the field's display. Invalid input reverts to the current
    /// value. Called on Enter and on focus loss.
    private func commitPreampText() {
        let cleaned = preampText
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let value = Double(cleaned) {
            let clamped = min(EQBand.maxGain, max(EQBand.minGain, value))
            eq.settings.preamp = clamped
        }
        // Re-render from the (possibly clamped / reverted) authoritative value.
        preampText = Self.preampString(eq.settings.preamp)
        preampFocused = false
    }

    private static func preampString(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            Divider()

            EQCurveView(
                settings: $eq.settings,
                selectedBandID: $selectedBandID,
                controller: eq
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)

            Divider()

            bandInspector
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 680, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .opacity(eq.settings.enabled ? 1 : 0.82)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 20) {
            Toggle("EQ", isOn: $eq.settings.enabled)
                .toggleStyle(.switch)
                .fixedSize()

            Divider().frame(height: 24)

            HStack(spacing: 8) {
                Text("Preamp")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Slider(
                    value: preampBinding,
                    in: EQBand.minGain...EQBand.maxGain
                )
                .frame(width: 130)
                .controlSize(.small)
                // Editable exact value: type a number (e.g. 0) and press Enter
                // to set the preamp precisely. The draft text commits only on
                // submit/focus-loss, and mirrors the slider otherwise.
                TextField("", text: $preampText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 12).monospacedDigit())
                    .frame(width: 64)
                    .focused($preampFocused)
                    .onSubmit { commitPreampText() }
                    .onChange(of: preampFocused) { _, focused in
                        if focused {
                            // Entering edit: show the raw current value.
                            preampText = Self.preampString(eq.settings.preamp)
                        } else {
                            // Leaving the field also commits.
                            commitPreampText()
                        }
                    }
                    .onChange(of: eq.settings.preamp) { _, newValue in
                        // Keep the field in sync with slider drags when not editing.
                        if !preampFocused {
                            preampText = Self.preampString(newValue)
                        }
                    }
                    .onAppear {
                        preampText = Self.preampString(eq.settings.preamp)
                    }
                Text("dB")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            presetControls
        }
    }

    private var presetControls: some View {
        HStack(spacing: 8) {
            Menu {
                if eq.userPresets.isEmpty {
                    Text("No saved presets")
                } else {
                    ForEach(eq.userPresets) { preset in
                        // Each preset is a submenu: apply it, or delete it.
                        Menu(preset.name) {
                            Button("Apply") { eq.apply(preset: preset) }
                            Divider()
                            Button(role: .destructive) {
                                eq.deletePreset(preset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } label: {
                Label("Presets", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button("Save As…") { showSaveAs = true }
                .controlSize(.small)

            Button("Reset") { eq.resetToFlat() }
                .controlSize(.small)
        }
        .popover(isPresented: $showSaveAs) {
            savePopover
        }
    }

    private var savePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save Preset")
                .font(.system(size: 13, weight: .semibold))
            TextField("Preset name", text: $newPresetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            HStack {
                Spacer()
                Button("Cancel") {
                    showSaveAs = false
                    newPresetName = ""
                }
                Button("Save") {
                    eq.saveAsPreset(named: newPresetName)
                    showSaveAs = false
                    newPresetName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }

    // MARK: - Band inspector

    @ViewBuilder
    private var bandInspector: some View {
        if let id = selectedBandID,
           let band = eq.settings.bands.first(where: { $0.id == id }) {
            HStack(spacing: 18) {
                // Filter type
                Picker("Type", selection: Binding(
                    get: { band.filterType },
                    set: { newType in
                        eq.updateBand(id: id) { $0.filterType = newType }
                    }
                )) {
                    ForEach(EQFilterType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .frame(width: 180)

                labeledReadout("Freq", "\(Int(band.frequency)) Hz")

                if band.filterType.usesGain {
                    labeledReadout("Gain", String(format: "%+.1f dB", band.gain))
                }

                HStack(spacing: 6) {
                    Text("Q")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { band.bandwidth },
                            set: { newValue in
                                eq.updateBand(id: id) { $0.bandwidth = newValue }
                            }
                        ),
                        in: EQBand.minBandwidth...EQBand.maxBandwidth
                    )
                    .frame(width: 120)
                    .controlSize(.small)
                }

                Spacer()

                Button(role: .destructive) {
                    eq.removeBand(id: id)
                    selectedBandID = nil
                } label: {
                    Label("Remove Band", systemImage: "trash")
                }
                .controlSize(.small)
            }
        } else {
            Text("Double-click the curve to add a band · click a node to edit · ⌫ to remove")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func labeledReadout(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
        }
    }
}
