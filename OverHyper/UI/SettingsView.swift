import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: EffectSettingsStore
    let onTestFire: (EffectKind) -> Void
    private let effectColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        Form {
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
        .frame(width: 520)
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
