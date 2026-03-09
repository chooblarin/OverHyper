import Foundation

enum EffectKind: String, CaseIterable, Identifiable {
    case confetti
    case flash
    case glitch
    case crtBurst
    case shockwave
    case neonEdge

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
        case .crtBurst:
            return "CRT Burst"
        case .shockwave:
            return "Shockwave"
        case .neonEdge:
            return "Neon Edge"
        }
    }
}
