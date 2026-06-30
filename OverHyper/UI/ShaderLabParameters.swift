#if DEBUG
import Foundation
import simd

enum ShaderLabTweakSlot: CaseIterable, Hashable {
    case slotX
    case slotY
    case slotZ
    case slotW
}

struct ShaderLabParameter: Identifiable {
    let slot: ShaderLabTweakSlot
    let title: String
    let range: ClosedRange<Double>
    let defaultValue: Double
    let unit: String

    var id: ShaderLabTweakSlot {
        slot
    }

    func formatted(_ value: Double) -> String {
        "\(String(format: "%.2f", value))\(unit)"
    }
}

struct ShaderLabParameterValues: Codable, Equatable {
    var slotX: Double
    var slotY: Double
    var slotZ: Double
    var slotW: Double

    subscript(slot: ShaderLabTweakSlot) -> Double {
        get {
            switch slot {
            case .slotX:
                return slotX
            case .slotY:
                return slotY
            case .slotZ:
                return slotZ
            case .slotW:
                return slotW
            }
        }
        set {
            switch slot {
            case .slotX:
                slotX = newValue
            case .slotY:
                slotY = newValue
            case .slotZ:
                slotZ = newValue
            case .slotW:
                slotW = newValue
            }
        }
    }

    var vector: SIMD4<Float> {
        SIMD4<Float>(Float(slotX), Float(slotY), Float(slotZ), Float(slotW))
    }

    static func defaults(for style: ShaderEffectStyle) -> ShaderLabParameterValues {
        let neutral = ShaderTweakDefaults.neutral
        var values = ShaderLabParameterValues(
            slotX: Double(neutral.x),
            slotY: Double(neutral.y),
            slotZ: Double(neutral.z),
            slotW: Double(neutral.w)
        )

        for parameter in style.shaderLabParameters {
            values[parameter.slot] = parameter.defaultValue
        }

        return values
    }

    static func defaultsByStyle() -> [ShaderEffectStyle: ShaderLabParameterValues] {
        Dictionary(
            uniqueKeysWithValues: ShaderEffectStyle.allCases.map { style in
                (style, defaults(for: style))
            }
        )
    }
}

extension ShaderEffectStyle {
    var shaderLabParameters: [ShaderLabParameter] {
        switch self {
        case .glitch:
            return [
                intensityParameter,
                ShaderLabParameter(
                    slot: .slotY,
                    title: "Slice Drift",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotZ,
                    title: "Chroma Shift",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotW,
                    title: "Grain",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                )
            ]
        case .crtBurst:
            return [
                intensityParameter,
                ShaderLabParameter(
                    slot: .slotY,
                    title: "Curvature",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotZ,
                    title: "Convergence",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotW,
                    title: "Scanlines",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                )
            ]
        case .shockwave:
            return [
                intensityParameter,
                ShaderLabParameter(
                    slot: .slotY,
                    title: "Radius",
                    range: 0.5...1.5,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotZ,
                    title: "Refraction",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotW,
                    title: "Ripples",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                )
            ]
        case .crackedGlass:
            return [
                intensityParameter,
                ShaderLabParameter(
                    slot: .slotY,
                    title: "Spread",
                    range: 0.6...1.6,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotZ,
                    title: "Refraction",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotW,
                    title: "Crack Width",
                    range: 0.5...1.5,
                    defaultValue: 1,
                    unit: ""
                )
            ]
        case .neonEdge:
            return [
                intensityParameter,
                ShaderLabParameter(
                    slot: .slotY,
                    title: "Edge Width",
                    range: 0.5...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotZ,
                    title: "Glow",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotW,
                    title: "Pulse",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                )
            ]
        case .rainGlass:
            return [
                intensityParameter,
                ShaderLabParameter(
                    slot: .slotY,
                    title: "Coverage",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotZ,
                    title: "Refraction",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                ),
                ShaderLabParameter(
                    slot: .slotW,
                    title: "Trail Blur",
                    range: 0...2,
                    defaultValue: 1,
                    unit: ""
                )
            ]
        }
    }

    private var intensityParameter: ShaderLabParameter {
        ShaderLabParameter(
            slot: .slotX,
            title: "Intensity",
            range: 0...1.8,
            defaultValue: 1,
            unit: ""
        )
    }
}
#endif
