// swiftlint:disable file_length
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

    func glowPass(amount: Float) -> LightningInstance {
        LightningInstance(
            modelMatrix: modelMatrix,
            coreColor: coreColor,
            edgeColor: edgeColor,
            parameters: SIMD4<Float>(
                parameters.x,
                parameters.y,
                parameters.z,
                amount
            )
        )
    }
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
    private static let meshVariantCount = 6

    private let duration: Float
    private let commandQueue: MTLCommandQueue
    private let basePipelineState: MTLRenderPipelineState
    private let glowPipelineState: MTLRenderPipelineState
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

        guard
            let basePipelineState = Self.makePipelineState(
                device: device,
                library: library,
                isAdditive: false
            ),
            let glowPipelineState = Self.makePipelineState(
                device: device,
                library: library,
                isAdditive: true
            )
        else {
            return nil
        }
        self.basePipelineState = basePipelineState
        self.glowPipelineState = glowPipelineState

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

            draw(
                instances.map { $0.glowPass(amount: 1.45) },
                meshIndex: meshIndex,
                pipelineState: glowPipelineState,
                in: view,
                using: encoder
            )
            draw(
                instances,
                meshIndex: meshIndex,
                pipelineState: basePipelineState,
                in: view,
                using: encoder
            )
        }
    }

    private func draw(
        _ instances: [LightningInstance],
        meshIndex: Int,
        pipelineState: MTLRenderPipelineState,
        in view: MTKView,
        using encoder: MTLRenderCommandEncoder
    ) {
        guard !instances.isEmpty else {
            return
        }

        guard let instanceBuffer = view.device?.makeBuffer(
            bytes: instances,
            length: MemoryLayout<LightningInstance>.stride * instances.count
        ) else {
            return
        }

        let mesh = meshes[meshIndex]
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: mesh.vertexCount,
            instanceCount: instances.count
        )
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
                threshold = age * 11.5
            } else {
                let decayProgress = min(max((age - 0.1) / 0.9, 0), 1)
                threshold = 0.90 * (1 - decayProgress)
            }

            let attack = min(max(age / 0.08, 0), 1)
            let release = 1 - smoothstep(edge0: 0.84, edge1: 1, value: age)
            let sparkPhase = (elapsedTime * 8.5) + (spawn.textureOffset * 37.0)
            let strobe = 0.76
                + (0.14 * sin(sparkPhase))
                + (0.10 * sin((sparkPhase * 2.31) + 1.7))
            let opacity = attack * release * min(max(strobe, 0.58), 1.0)
            let parameters = SIMD4<Float>(
                threshold * min(max(0.92 + (0.12 * strobe), 0.82), 1.08),
                opacity,
                spawn.textureOffset,
                0
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
    private static func makePipelineState(
        device: MTLDevice,
        library: MTLLibrary,
        isAdditive: Bool
    ) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "lightningRibbonVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "lightningRibbonFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = isAdditive ? .one : .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        let destinationBlend: MTLBlendFactor = isAdditive ? .one : .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = destinationBlend
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = destinationBlend

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeMaskTexture(device: MTLDevice) -> MTLTexture? {
        let width = 512
        let height = 256
        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            let uvY = Float(y) / Float(height - 1)
            for x in 0..<width {
                let uvX = Float(x) / Float(width - 1)
                var value: Float = 0

                value += electricMaskValue(uvX: uvX, uvY: uvY)
                value += branchMaskValue(uvX: uvX, uvY: uvY)

                let horizontalPulse = 0.68
                    + (0.20 * sin((uvX * .pi * 8.0) + 0.9))
                    + (0.12 * sin((uvX * .pi * 31.0) + 2.4))
                let verticalFade = smoothstep(edge0: 0.02, edge1: 0.22, value: uvY)
                    * (1 - smoothstep(edge0: 0.78, edge1: 0.99, value: uvY))
                let finalValue = min(value * horizontalPulse * verticalFade, 0.92)
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

    private static func electricMaskValue(uvX: Float, uvY: Float) -> Float {
        let initialX = (uvX - 0.5) * 0.58
        let initialY = (uvY - 0.5) * 0.32
        var fieldX = initialX
        var fieldY = initialY
        var vectorX: Float = 1.0
        var vectorY: Float = 1.0
        var amplitude: Float = 0.50
        var energy: Float = 0

        for index in 1...14 {
            let step = Float(index)
            let phase = step * 0.47
            amplitude += 0.03

            let denominator = max(0.5 - ((fieldX * fieldX) + (fieldY * fieldY)), 0.08)
            let singularX = (1.5 * fieldX / denominator) - (9.0 * fieldY) + phase
            let singularY = (1.5 * fieldY / denominator) - (9.0 * fieldX) + phase
            vectorX = cos(phase - (7.0 * fieldX * pow(amplitude, step))) - (5.0 * fieldX)
            vectorY = cos(phase - (7.0 * fieldY * pow(amplitude, step))) - (5.0 * fieldY)

            let vectorEnergy = (vectorX * vectorX) + (vectorY * vectorY)
            let waveX = (1.0 + (step * vectorEnergy)) * sin(singularX)
            let waveY = (1.0 + (step * vectorEnergy)) * sin(singularY)
            let distanceWave = max(hypot(waveX, waveY), 0.055)
            let colorPulse = 1.0 + cos((step * 0.65) + phase)
            energy += (1.0 / distanceWave) * (0.66 + (0.34 * colorPulse)) / (1.0 + (step * 0.24))

            let angle = step + (phase * 0.02)
            let rotatedX = (cos(angle) * fieldX) - (sin(angle) * fieldY)
            let rotatedY = (sin(angle) * fieldX) + (cos(angle) * fieldY)
            fieldX = rotatedX
            fieldY = rotatedY

            let pushX = cos((92.0 * fieldY) + phase)
            let pushY = cos((92.0 * fieldX) + phase)
            let radius = (fieldX * fieldX) + (fieldY * fieldY)
            fieldX += tanh(40.0 * radius * pushX) * 0.005
            fieldY += tanh(40.0 * radius * pushY) * 0.005
            fieldX += fieldX * amplitude * 0.16
            fieldY += fieldY * amplitude * 0.16
            let compressedEnergy = min(energy * energy, 64.0)
            let drift = cos((4.0 / exp(compressedEnergy * 0.01)) + phase) * 0.003
            fieldX += drift
            fieldY += drift
        }

        let safeEnergy = max(energy * 0.72, 0.001)
        let compressed = 25.6 / (min(safeEnergy, 13.0) + (164.0 / safeEnergy))
        let radialFalloff = ((initialX - fieldX) * (initialX - fieldX))
            + ((initialY - fieldY) * (initialY - fieldY))
        return min(max((compressed * 1.42) - (radialFalloff * 0.28), 0), 1)
    }

    private static func branchMaskValue(uvX: Float, uvY: Float) -> Float {
        var value: Float = 0
        let centers: [LightningMaskBand] = [
            LightningMaskBand(center: 0.48, width: 0.026, amplitude: 0.16, phase: 0.2),
            LightningMaskBand(center: 0.54, width: 0.020, amplitude: 0.12, phase: 1.6)
        ]

        for band in centers {
            let bend = sin((uvX * .pi * 3.0) + band.phase) * band.amplitude
                + sin((uvX * .pi * 13.0) + (band.phase * 0.71)) * band.amplitude * 0.30
                + tanh(sin((uvX * .pi * 29.0) + band.phase)) * band.amplitude * 0.10
            let center = band.center + bend
            let distance = abs(uvY - center)
            let taper = smoothstep(edge0: 0.0, edge1: 0.18, value: uvX)
                * (1 - smoothstep(edge0: 0.78, edge1: 1.0, value: uvX))
            value += exp(-pow(distance / band.width, 2.0)) * 0.30 * taper
        }

        return value
    }

    private static func makeRibbonMeshes() -> [[LightningVertex]] {
        (0..<meshVariantCount).map { index in
            makeRibbonMesh(points: makeFieldFoldPath(index: index))
        }
    }

    private static func makeFieldFoldPath(index: Int) -> [SIMD3<Float>] {
        let pointCount = 29
        let seed = Float(index) * 1.371
        let foldDirection: Float = index.isMultiple(of: 2) ? 1 : -1

        return (0..<pointCount).map { pointIndex in
            let progress = Float(pointIndex) / Float(pointCount - 1)
            var x = -1.05 + (progress * 2.10)
            var y = sin((progress * .pi * 2.1) + seed) * 0.12
            y += sin((progress * .pi * 7.7) + (seed * 1.7)) * 0.070
            y += tanh(sin((progress * .pi * 18.0) + seed)) * 0.045

            let curlProgress = progress - 0.50
            let curl = 0.16 * foldDirection * sin((progress * .pi * 2.0) + seed)
            x += curl * abs(curlProgress)
            y += curl * (1.0 - abs(curlProgress * 1.7))

            if index >= 4 {
                let branchStart = 0.22 + (Float(index - 3) * 0.11)
                let branchProgress = max(progress - branchStart, 0)
                let branchTaper = 1 - smoothstep(edge0: 0.42, edge1: 0.72, value: branchProgress)
                y += foldDirection * branchProgress * branchTaper * 0.38
                x -= branchProgress * branchTaper * 0.18
            }

            let z = -0.22 + (sin((progress * .pi * 3.0) + seed) * 0.18)
            return SIMD3<Float>(x, y, z)
        }
    }

    private static func makeRibbonMesh(points: [SIMD3<Float>]) -> [LightningVertex] {
        let widths = points.indices.map { index -> Float in
            let progress = Float(index) / Float(points.count - 1)
            let forkTaper = 0.18 * sin(progress * .pi * 5.0)
            return 0.112 * (0.24 + (0.76 * sin(progress * .pi))) * (1.0 + forkTaper)
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

    // swiftlint:disable:next function_body_length
    private static func makeSpawns(duration: Float) -> [LightningSpawn] {
        var generator = SeededGenerator(seed: 0x5F17ECA1)
        let count = 19
        let centerCount = 3
        let corePalette: [SIMD4<Float>] = [
            color(hex: 0xFF481B, alpha: 0.95),
            color(hex: 0xDFFE38, alpha: 0.90),
            color(hex: 0xFF2929, alpha: 0.86)
        ]
        let edgeColor = color(hex: 0x1C1D1E, alpha: 0.70)

        return (0..<count).map { index in
            let burstCount = 5
            let isCentral = index >= count - centerCount
            let spawnTime: Float
            if index < burstCount {
                spawnTime = Float(index) * 0.18
            } else {
                spawnTime = 0.20 + (generator.nextUnit() * duration * 0.66)
            }
            let lifetime = 0.48 + generator.nextUnit() * 0.48
            let meshIndex = min(
                Int(generator.nextUnit() * Float(meshVariantCount)),
                meshVariantCount - 1
            )
            let placement = isCentral
                ? makeCentralPlacement(generator: &generator)
                : makePeripheralPlacement(index: index, generator: &generator)
            let scale = isCentral
                ? 0.18 + generator.nextUnit() * 0.22
                : 0.24 + generator.nextUnit() * 0.48
            let scaleY = scale * (
                isCentral
                    ? 0.82 + generator.nextUnit() * 0.36
                    : 0.90 + generator.nextUnit() * 0.52
            )
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
        let edgeJitter = generator.nextUnit() * 0.10
        let tangentJitter = (generator.nextUnit() - 0.5) * 0.72
        let lateral = (generator.nextUnit() * 1.66) - 0.83

        switch side {
        case 0:
            return LightningPlacement(
                position: SIMD3<Float>(lateral, 0.66 + edgeJitter, 0),
                rotationZ: tangentJitter
            )
        case 1:
            return LightningPlacement(
                position: SIMD3<Float>(lateral, -0.66 - edgeJitter, 0),
                rotationZ: tangentJitter + .pi
            )
        case 2:
            return LightningPlacement(
                position: SIMD3<Float>(-0.76 - edgeJitter, lateral * 0.82, 0),
                rotationZ: (.pi * 0.5) + tangentJitter
            )
        default:
            return LightningPlacement(
                position: SIMD3<Float>(0.76 + edgeJitter, lateral * 0.82, 0),
                rotationZ: (.pi * 0.5) + tangentJitter
            )
        }
    }

    private static func makeCentralPlacement(
        generator: inout SeededGenerator
    ) -> LightningPlacement {
        let radius = 0.10 + generator.nextUnit() * 0.30
        let angle = generator.nextUnit() * .pi * 2.0
        let tangentJitter = (generator.nextUnit() - 0.5) * 1.10

        return LightningPlacement(
            position: SIMD3<Float>(
                cos(angle) * radius * 1.12,
                sin(angle) * radius * 0.76,
                0
            ),
            rotationZ: angle + (.pi * 0.5) + tangentJitter
        )
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
