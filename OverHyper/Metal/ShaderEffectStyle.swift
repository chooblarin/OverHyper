enum ShaderEffectStyle {
    case glitch
    case crtBurst
    case shockwave
    case crackedGlass
    case neonEdge
    case rainGlass

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
