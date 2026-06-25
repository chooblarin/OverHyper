import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: EffectSettingsStore
    let onTestFire: (EffectKind) -> Void

    @State private var displays = DisplayCatalog.snapshots()

    private let effectColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        Form {
            PresentationTargetSection(
                displays: displays,
                presentationTargetMode: presentationTargetModeBinding,
                selectedDisplayID: selectedDisplayBinding
            )

            Section("Try Effects") {
                LazyVGrid(columns: effectColumns, spacing: 12) {
                    ForEach(EffectKind.allCases) { effect in
                        Button(effect.displayName) {
                            onTestFire(effect)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("Hotkey Slots") {
                ForEach(settingsStore.hotkeyAssignments) { assignment in
                    HStack {
                        Text(assignment.slotID.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Picker(
                            "Assigned Effect",
                            selection: assignmentBinding(for: assignment.slotID)
                        ) {
                            Text("None").tag(EffectKind?.none)
                            ForEach(EffectKind.allCases) { effect in
                                Text(effect.displayName).tag(Optional(effect))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 560)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification
            )
        ) { _ in
            displays = DisplayCatalog.snapshots()
        }
    }

    private var presentationTargetModeBinding: Binding<PresentationTargetMode> {
        Binding(
            get: {
                settingsStore.presentationTargetMode
            },
            set: { newValue in
                settingsStore.setPresentationTargetMode(newValue)
            }
        )
    }

    private var selectedDisplayBinding: Binding<CGDirectDisplayID?> {
        Binding(
            get: {
                settingsStore.selectedDisplayID
            },
            set: { newValue in
                settingsStore.setSelectedDisplayID(newValue)
            }
        )
    }

    private func assignmentBinding(for slotID: HotkeySlotID) -> Binding<EffectKind?> {
        Binding(
            get: {
                settingsStore.assignedEffect(for: slotID)
            },
            set: { newValue in
                settingsStore.setAssignedEffect(newValue, for: slotID)
            }
        )
    }
}

private struct PresentationTargetSection: View {
    let displays: [DisplaySnapshot]
    @Binding var presentationTargetMode: PresentationTargetMode
    @Binding var selectedDisplayID: CGDirectDisplayID?

    private var presentationTarget: PresentationTarget {
        PresentationTarget(
            mode: presentationTargetMode,
            selectedDisplayID: selectedDisplayID
        )
    }

    private var targetResolution: PresentationDisplayResolution {
        PresentationTargetResolver.resolve(
            displays: displays,
            target: presentationTarget
        )
    }

    var body: some View {
        Section("Presentation Target") {
            Picker(
                "Show Effects On",
                selection: $presentationTargetMode
            ) {
                ForEach(PresentationTargetMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            if presentationTargetMode == .selectedDisplay {
                Picker("Display", selection: $selectedDisplayID) {
                    Text("None").tag(CGDirectDisplayID?.none)
                    ForEach(displays) { display in
                        Text(display.displayName).tag(Optional(display.id))
                    }
                }
            }

            if let warning = targetResolution.warning {
                Text(warning.displayMessage)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(displays) { display in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(display.displayName)
                            Spacer()
                            if isTargeted(display) {
                                Text("Target")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(display.detailText)
                                .foregroundStyle(.secondary)
                        }
                        Text(display.diagnosticText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private func isTargeted(_ display: DisplaySnapshot) -> Bool {
        targetResolution.displayIDs.contains(display.id)
    }
}
