enum ShaderEffectStyle {
    case glitch
    case crtBurst
    case shockwave
    case crackedGlass
    case neonEdge

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
        }
    }

    var preferredFramesPerSecond: Int {
        switch self {
        case .glitch, .crtBurst, .shockwave, .crackedGlass, .neonEdge:
            return 60
        }
    }
}
