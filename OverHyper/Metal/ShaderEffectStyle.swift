enum ShaderEffectStyle {
    case glitch
    case crtBurst
    case shockwave
    case neonEdge

    var fragmentFunctionName: String {
        switch self {
        case .glitch:
            return "glitchFragmentShader"
        case .crtBurst:
            return "crtBurstFragmentShader"
        case .shockwave:
            return "shockwaveFragmentShader"
        case .neonEdge:
            return "neonEdgeFragmentShader"
        }
    }
}
