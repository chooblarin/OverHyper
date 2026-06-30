enum ShaderEffectStyle: String, CaseIterable, Codable, Hashable, Identifiable {
    case glitch
    case crtBurst
    case shockwave
    case crackedGlass
    case neonEdge
    case rainGlass

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .glitch:
            return "Glitch"
        case .crtBurst:
            return "CRT Burst"
        case .shockwave:
            return "Shockwave"
        case .crackedGlass:
            return "Cracked Glass"
        case .neonEdge:
            return "Neon Edge"
        case .rainGlass:
            return "Rain Glass"
        }
    }

    var fragmentFunctionName: String {
        switch self {
        case .glitch:
            return "glitchFragmentShader"
        case .crtBurst:
            return "crtBurstFragmentShader"
        case .shockwave:
            return "shockwaveFragmentShader"
        case .crackedGlass:
            return "crackedGlassFragmentShader"
        case .neonEdge:
            return "neonEdgeFragmentShader"
        case .rainGlass:
            return "rainGlassFragmentShader"
        }
    }

    var preferredFramesPerSecond: Int {
        switch self {
        case .glitch, .crtBurst, .shockwave, .crackedGlass, .neonEdge, .rainGlass:
            return 60
        }
    }
}
