import Combine
import Foundation

@MainActor
final class EffectSettingsStore: ObservableObject {
    static let shared = EffectSettingsStore()
    nonisolated static let hotkeyDefaultsKey = "overhyperHotkeyConfetti"
    nonisolated static let legacyHotkeyDefaultsKey = "overhyper.hotkey.confetti"

    @Published var intensityPreset: IntensityPreset {
        didSet {
            userDefaults.set(intensityPreset.rawValue, forKey: Keys.intensityPreset)
        }
    }

    @Published var confettiDuration: Double {
        didSet {
            let clamped = confettiDuration.clamped(to: Constants.durationRange)
            if clamped != confettiDuration {
                confettiDuration = clamped
                return
            }
            userDefaults.set(confettiDuration, forKey: Keys.confettiDuration)
        }
    }

    @Published var flashEnabled: Bool {
        didSet {
            userDefaults.set(flashEnabled, forKey: Keys.flashEnabled)
        }
    }

    var settings: EffectSettings {
        EffectSettings(
            intensityPreset: intensityPreset,
            confettiDuration: confettiDuration,
            flashEnabled: flashEnabled
        )
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let preset = IntensityPreset(
            rawValue: userDefaults.string(forKey: Keys.intensityPreset) ?? ""
        ) ?? EffectSettings.defaultValue.intensityPreset

        let durationValue = userDefaults.object(forKey: Keys.confettiDuration) as? Double
        let duration = (durationValue ?? EffectSettings.defaultValue.confettiDuration)
            .clamped(to: Constants.durationRange)

        let isFlashEnabled = userDefaults.object(forKey: Keys.flashEnabled) as? Bool
            ?? EffectSettings.defaultValue.flashEnabled

        intensityPreset = preset
        confettiDuration = duration
        flashEnabled = isFlashEnabled
    }
}

private enum Keys {
    static let intensityPreset = "overhyper.settings.intensityPreset"
    static let confettiDuration = "overhyper.settings.confettiDuration"
    static let flashEnabled = "overhyper.settings.flashEnabled"
}

private enum Constants {
    static let durationRange: ClosedRange<Double> = 0.8...4.0
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
