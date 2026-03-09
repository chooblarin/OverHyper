import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: EffectSettingsStore

    private var confettiDurationText: String {
        settingsStore.confettiDuration.formatted(
            .number.precision(.fractionLength(1))
        )
    }

    var body: some View {
        Form {
            Section("Confetti") {
                Picker("Intensity", selection: $settingsStore.intensityPreset) {
                    ForEach(IntensityPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                HStack {
                    Slider(
                        value: $settingsStore.confettiDuration,
                        in: 0.8...4.0,
                        step: 0.1
                    )
                    Text("\(confettiDurationText) s")
                        .frame(width: 44, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Secondary Effect") {
                Toggle("Enable flash effect", isOn: $settingsStore.flashEnabled)
            }

            Section("Global Hotkey") {
                MASShortcutRecorderField(defaultsKey: EffectSettingsStore.hotkeyDefaultsKey)
                    .frame(height: 25)
                Text("Default: Control + Option + Command + G")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 440)
    }
}
