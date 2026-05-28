import Foundation
import MetalKit
import QuartzCore
import simd

private struct LightningVertex {
    let position: SIMD3<Float>
    let textureCoordinate: SIMD2<Float>
    let along: Float
    let padding: Float
}

private struct LightningInstance {
    let modelMatrix: simd_float4x4
    let coreColor: SIMD4<Float>
    let edgeColor: SIMD4<Float>
    let parameters: SIMD4<Float>
}

private struct LightningUniforms {
    let viewportSize: SIMD2<Float>
    let elapsedTime: Float
    let totalDuration: Float
}

private struct LightningSpawn {
    let spawnTime: Float
    let lifetime: Float
    let meshIndex: Int
    let modelMatrix: simd_float4x4
    let textureOffset: Float
    let coreColor: SIMD4<Float>
    let edgeColor: SIMD4<Float>
}

private struct LightningMesh {
    let vertexBuffer: MTLBuffer
    let vertexCount: Int
}

private struct LightningMaskBand {
    let center: Float
    let width: Float
    let amplitude: Float
    let phase: Float
}

private struct LightningPlacement {
    let position: SIMD3<Float>
    let rotationZ: Float
}

final class LightningMetalRenderer: NSObject, MTKViewDelegate {
    private let duration: Float
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let maskTexture: MTLTexture
    private let meshes: [LightningMesh]
    private let spawns: [LightningSpawn]
    private let startTime = CACurrentMediaTime()

    private var viewportSize = SIMD2<Float>(0, 0)

    init?(device: MTLDevice, duration: TimeInterval) {
        self.duration = Float(duration)

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary() else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "lightningRibbonVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "lightningRibbonFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }

        guard let maskTexture = Self.makeMaskTexture(device: device) else {
            return nil
        }
        self.maskTexture = maskTexture

        let meshVertices = Self.makeRibbonMeshes()
        var meshes: [LightningMesh] = []
        for vertices in meshVertices {
            guard let buffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<LightningVertex>.stride * vertices.count
            ) else {
                return nil
            }
            meshes.append(LightningMesh(vertexBuffer: buffer, vertexCount: vertices.count))
        }
        self.meshes = meshes
        spawns = Self.makeSpawns(duration: Float(duration))
    }

    func attach(to view: MTKView) {
        viewportSize = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height)
        )
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    func draw(in view: MTKView) {
        guard
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        let elapsedTime = min(Float(CACurrentMediaTime() - startTime), duration)
        var uniforms = LightningUniforms(
            viewportSize: viewportSize,
            elapsedTime: elapsedTime,
            totalDuration: duration
        )
        let groupedInstances = activeInstances(at: elapsedTime)

        encodeInstances(groupedInstances, uniforms: &uniforms, in: view, using: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encodeInstances(
        _ groupedInstances: [[LightningInstance]],
        uniforms: inout LightningUniforms,
        in view: MTKView,
        using encoder: MTLRenderCommandEncoder
    ) {
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(maskTexture, index: 0)
        encoder.setVertexBytes(
            &uniforms,
            length: MemoryLayout<LightningUniforms>.stride,
            index: 2
        )
        encoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<LightningUniforms>.stride,
            index: 0
        )

        for meshIndex in meshes.indices {
            let instances = groupedInstances[meshIndex]
            guard !instances.isEmpty else {
                continue
            }

            guard let instanceBuffer = view.device?.makeBuffer(
                bytes: instances,
                length: MemoryLayout<LightningInstance>.stride * instances.count
            ) else {
                continue
            }

            let mesh = meshes[meshIndex]
            encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
            encoder.drawPrimitives(
                type: .triangle,
                vertexStart: 0,
                vertexCount: mesh.vertexCount,
                instanceCount: instances.count
            )
        }
    }

    private func activeInstances(at elapsedTime: Float) -> [[LightningInstance]] {
        var grouped = Array(repeating: [LightningInstance](), count: meshes.count)

        for spawn in spawns {
            let age = (elapsedTime - spawn.spawnTime) / spawn.lifetime
            guard age >= 0, age < 1 else {
                continue
            }

            let threshold: Float
            if age < 0.1 {
                threshold = age * 10.2
            } else {
                threshold = 0.86 * (1 - ((age - 0.1) / 0.9))
            }

            let attack = min(max(age / 0.08, 0), 1)
            let release = 1 - smoothstep(edge0: 0.72, edge1: 1, value: age)
            let opacity = attack * release
            let parameters = SIMD4<Float>(
                threshold,
                opacity,
                spawn.textureOffset,
                Float(spawn.meshIndex)
            )

            grouped[spawn.meshIndex].append(
                LightningInstance(
                    modelMatrix: spawn.modelMatrix,
                    coreColor: spawn.coreColor,
                    edgeColor: spawn.edgeColor,
                    parameters: parameters
                )
            )
        }

        return grouped
    }
}

private extension LightningMetalRenderer {
    private static func makeMaskTexture(device: MTLDevice) -> MTLTexture? {
        let width = 512
        let height = 256
        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            let uvY = Float(y) / Float(height - 1)
            for x in 0..<width {
                let uvX = Float(x) / Float(width - 1)
                var value: Float = 0

                let bands: [LightningMaskBand] = [
                    LightningMaskBand(center: 0.48, width: 0.070, amplitude: 0.21, phase: 0.0),
                    LightningMaskBand(center: 0.55, width: 0.055, amplitude: 0.17, phase: 1.7),
                    LightningMaskBand(center: 0.42, width: 0.044, amplitude: 0.13, phase: 3.1),
                    LightningMaskBand(center: 0.62, width: 0.032, amplitude: 0.10, phase: 4.6)
                ]

                for band in bands {
                    let center = band.center
                        + sin((uvX * .pi * 2.0) + band.phase) * band.amplitude
                        + sin((uvX * .pi * 7.0) + band.phase * 0.63) * band.amplitude * 0.22
                    let distance = abs(uvY - center)
                    value += exp(-pow(distance / band.width, 2.0)) * 0.58
                }

                let horizontalPulse = 0.72 + 0.28 * sin((uvX * .pi * 8.0) + 0.9)
                let verticalFade = smoothstep(edge0: 0.02, edge1: 0.22, value: uvY)
                    * (1 - smoothstep(edge0: 0.78, edge1: 0.99, value: uvY))
                let finalValue = min(value * horizontalPulse * verticalFade, 0.82)
                pixels[(y * width) + x] = UInt8(finalValue * 255)
            }
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width
        )

        return texture
    }

    private static func makeRibbonMeshes() -> [[LightningVertex]] {
        [
            makeRibbonMesh(points: [
                [-0.92, -0.08, -0.18],
                [-0.82, -0.15, -0.30],
                [-0.54, -0.09, -0.25],
                [-0.28, -0.24, -0.22],
                [0.04, -0.16, -0.18],
                [0.35, -0.31, -0.13],
                [0.66, -0.22, -0.07],
                [0.91, -0.34, 0.02],
                [0.74, -0.09, 0.18],
                [0.54, -0.01, 0.30],
                [0.30, 0.07, 0.19],
                [-0.07, 0.00, 0.10],
                [-0.44, 0.06, -0.02]
            ]),
            makeRibbonMesh(points: [
                [-0.82, 0.08, -0.22],
                [-0.72, 0.33, -0.34],
                [-0.45, 0.50, -0.42],
                [-0.12, 0.40, -0.38],
                [0.18, 0.58, -0.32],
                [0.44, 0.36, -0.28],
                [0.75, 0.42, -0.17],
                [0.92, 0.18, -0.06],
                [0.70, 0.06, 0.12],
                [0.45, -0.03, 0.25],
                [0.12, -0.12, 0.18],
                [-0.24, -0.05, 0.07],
                [-0.53, -0.15, -0.04]
            ])
        ]
    }

    private static func makeRibbonMesh(points: [SIMD3<Float>]) -> [LightningVertex] {
        let widths = points.indices.map { index -> Float in
            let progress = Float(index) / Float(points.count - 1)
            return 0.10 * (0.24 + (0.76 * sin(progress * .pi)))
        }

        var rows: [[LightningVertex]] = Array(repeating: [], count: 3)
        for index in points.indices {
            let previous = points[max(index - 1, 0)]
            let next = points[min(index + 1, points.count - 1)]
            let tangent = normalize(next - previous)
            let normal = normalize(SIMD3<Float>(-tangent.y, tangent.x, 0))
            let along = Float(index) / Float(points.count - 1)
            let offsets: [Float] = [-1, 0, 1]

            for row in 0..<3 {
                let offset = offsets[row] * widths[index]
                rows[row].append(
                    LightningVertex(
                        position: points[index] + (normal * offset),
                        textureCoordinate: SIMD2<Float>(along, [0.05, 0.5, 0.95][row]),
                        along: along,
                        padding: 0
                    )
                )
            }
        }

        var vertices: [LightningVertex] = []
        for row in 0..<2 {
            for index in 0..<(points.count - 1) {
                let lowerStart = rows[row][index]
                let lowerEnd = rows[row][index + 1]
                let upperStart = rows[row + 1][index]
                let upperEnd = rows[row + 1][index + 1]
                vertices.append(contentsOf: [
                    lowerStart,
                    lowerEnd,
                    upperStart,
                    lowerEnd,
                    upperEnd,
                    upperStart
                ])
            }
        }

        return vertices
    }

    private static func makeSpawns(duration: Float) -> [LightningSpawn] {
        var generator = SeededGenerator(seed: 0x5F17ECA1)
        let count = 64
        let corePalette: [SIMD4<Float>] = [
            color(hex: 0xFF481B, alpha: 0.95),
            color(hex: 0xDFFE38, alpha: 0.90),
            color(hex: 0xFF2929, alpha: 0.86)
        ]
        let edgeColor = color(hex: 0x1C1D1E, alpha: 0.70)

        return (0..<count).map { index in
            let burst = Float(index) / Float(max(count - 1, 1))
            let spawnTime = pow(generator.nextUnit(), 1.65) * duration * 0.72
                + (burst < 0.12 ? 0 : generator.nextUnit() * 0.10)
            let lifetime = 0.30 + generator.nextUnit() * 0.55
            let meshIndex = Int(generator.nextUnit() * 1.999)
            let placement = makePeripheralPlacement(index: index, generator: &generator)
            let scale = 0.20 + generator.nextUnit() * 0.44
            let scaleY = scale * (0.86 + generator.nextUnit() * 0.48)
            let rotation = SIMD3<Float>(
                (generator.nextUnit() - 0.5) * 0.8,
                (generator.nextUnit() - 0.5) * 0.8,
                placement.rotationZ
            )
            let modelMatrix = translationMatrix(placement.position)
                * rotationZMatrix(rotation.z)
                * rotationYMatrix(rotation.y)
                * rotationXMatrix(rotation.x)
                * scaleMatrix(SIMD3<Float>(scale, scaleY, scale))

            return LightningSpawn(
                spawnTime: spawnTime,
                lifetime: lifetime,
                meshIndex: meshIndex,
                modelMatrix: modelMatrix,
                textureOffset: generator.nextUnit(),
                coreColor: corePalette[index % corePalette.count],
                edgeColor: edgeColor
            )
        }
        .sorted { $0.spawnTime < $1.spawnTime }
    }

    private static func makePeripheralPlacement(
        index: Int,
        generator: inout SeededGenerator
    ) -> LightningPlacement {
        let side = index % 4
        let edgeJitter = generator.nextUnit() * 0.18
        let tangentJitter = (generator.nextUnit() - 0.5) * 0.80
        let lateral = (generator.nextUnit() * 1.82) - 0.91

        switch side {
        case 0:
            return LightningPlacement(
                position: SIMD3<Float>(lateral, 0.78 + edgeJitter, 0),
                rotationZ: tangentJitter
            )
        case 1:
            return LightningPlacement(
                position: SIMD3<Float>(lateral, -0.78 - edgeJitter, 0),
                rotationZ: tangentJitter + .pi
            )
        case 2:
            return LightningPlacement(
                position: SIMD3<Float>(-0.91 - edgeJitter, lateral * 0.88, 0),
                rotationZ: (.pi * 0.5) + tangentJitter
            )
        default:
            return LightningPlacement(
                position: SIMD3<Float>(0.91 + edgeJitter, lateral * 0.88, 0),
                rotationZ: (.pi * 0.5) + tangentJitter
            )
        }
    }
}

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUnit() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let value = UInt32(truncatingIfNeeded: state >> 32)
        return Float(value) / Float(UInt32.max)
    }
}

private func color(hex: UInt32, alpha: Float) -> SIMD4<Float> {
    SIMD4<Float>(
        Float((hex >> 16) & 0xFF) / 255,
        Float((hex >> 8) & 0xFF) / 255,
        Float(hex & 0xFF) / 255,
        alpha
    )
}

private func smoothstep(edge0: Float, edge1: Float, value: Float) -> Float {
    let interpolation = min(max((value - edge0) / (edge1 - edge0), 0), 1)
    return interpolation * interpolation * (3 - (2 * interpolation))
}

private func translationMatrix(_ translation: SIMD3<Float>) -> simd_float4x4 {
    simd_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    )
}

private func scaleMatrix(_ scale: SIMD3<Float>) -> simd_float4x4 {
    simd_float4x4(
        SIMD4<Float>(scale.x, 0, 0, 0),
        SIMD4<Float>(0, scale.y, 0, 0),
        SIMD4<Float>(0, 0, scale.z, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

private func rotationXMatrix(_ angle: Float) -> simd_float4x4 {
    let cosine = cos(angle)
    let sine = sin(angle)
    return simd_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, cosine, sine, 0),
        SIMD4<Float>(0, -sine, cosine, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

private func rotationYMatrix(_ angle: Float) -> simd_float4x4 {
    let cosine = cos(angle)
    let sine = sin(angle)
    return simd_float4x4(
        SIMD4<Float>(cosine, 0, -sine, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(sine, 0, cosine, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

private func rotationZMatrix(_ angle: Float) -> simd_float4x4 {
    let cosine = cos(angle)
    let sine = sin(angle)
    return simd_float4x4(
        SIMD4<Float>(cosine, sine, 0, 0),
        SIMD4<Float>(-sine, cosine, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}
