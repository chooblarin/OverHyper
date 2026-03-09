import Foundation

enum EffectKind: String, CaseIterable, Identifiable {
    case confetti
    case flash
    case glitch

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .confetti:
            return "Confetti"
        case .flash:
            return "Flash"
        case .glitch:
            return "Glitch"
        }
    }
}
