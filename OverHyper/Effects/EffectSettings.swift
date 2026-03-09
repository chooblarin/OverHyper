import CoreGraphics
import Foundation

enum IntensityPreset: String, CaseIterable, Identifiable {
    case low
    case standard
    case high

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .standard:
            return "Standard"
        case .high:
            return "High"
        }
    }

    var confettiBirthRate: Float {
        switch self {
        case .low:
            return 70
        case .standard:
            return 108
        case .high:
            return 150
        }
    }

    var confettiVelocity: CGFloat {
        switch self {
        case .low:
            return 320
        case .standard:
            return 420
        case .high:
            return 540
        }
    }

    var confettiSpinRange: CGFloat {
        switch self {
        case .low:
            return 1.4
        case .standard:
            return 2.2
        case .high:
            return 3.0
        }
    }

    var flashOpacity: Float {
        switch self {
        case .low:
            return 0.12
        case .standard:
            return 0.18
        case .high:
            return 0.24
        }
    }
}

struct EffectSettings {
    var intensityPreset: IntensityPreset
    var confettiDuration: TimeInterval
    var flashEnabled: Bool

    static let defaultValue = EffectSettings(
        intensityPreset: .standard,
        confettiDuration: 1.6,
        flashEnabled: true
    )
}
