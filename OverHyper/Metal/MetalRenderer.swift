import Foundation
import MetalKit
import QuartzCore
import simd

private struct TexturedVertex {
    let position: SIMD2<Float>
    let textureCoordinate: SIMD2<Float>
}

private struct ShaderUniforms {
    let viewportSize: SIMD2<Float>
    let elapsedTime: Float
    let totalDuration: Float
    let tweaks: SIMD4<Float>
}

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let durationProvider: () -> Float
    private let elapsedTimeProvider: (() -> Float)?
    private let tweakProvider: () -> SIMD4<Float>
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let texture: MTLTexture
    private let vertexBuffer: MTLBuffer
    private let startTime = CACurrentMediaTime()

    private var viewportSize = SIMD2<Float>(0, 0)

    init?(
        device: MTLDevice,
        image: CGImage,
        style: ShaderEffectStyle,
        duration: TimeInterval,
        durationProvider: (() -> Float)? = nil,
        elapsedTimeProvider: (() -> Float)? = nil,
        tweakProvider: (() -> SIMD4<Float>)? = nil
    ) {
        let fallbackDuration = Float(duration)
        self.durationProvider = durationProvider ?? { fallbackDuration }
        self.elapsedTimeProvider = elapsedTimeProvider
        self.tweakProvider = tweakProvider ?? { SIMD4<Float>(1, 0, 0, 0) }

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        guard let vertexBuffer = Self.makeVertexBuffer(device: device) else {
            return nil
        }
        self.vertexBuffer = vertexBuffer

        guard let texture = Self.makeTexture(device: device, image: image) else {
            return nil
        }
        self.texture = texture

        guard let library = device.makeDefaultLibrary() else {
            return nil
        }

        guard let pipelineState = Self.makePipelineState(
            device: device,
            library: library,
            style: style
        ) else {
            return nil
        }
        self.pipelineState = pipelineState
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
            let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor
            )
        else {
            return
        }

        let totalDuration = max(durationProvider(), 0.001)
        let elapsedTime = min(
            max(elapsedTimeProvider?() ?? Float(CACurrentMediaTime() - startTime), 0),
            totalDuration
        )
        var uniforms = ShaderUniforms(
            viewportSize: viewportSize,
            elapsedTime: elapsedTime,
            totalDuration: totalDuration,
            tweaks: tweakProvider()
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<ShaderUniforms>.stride,
            index: 0
        )
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static func makeVertexBuffer(device: MTLDevice) -> MTLBuffer? {
        let vertices: [TexturedVertex] = [
            TexturedVertex(position: [-1, -1], textureCoordinate: [0, 1]),
            TexturedVertex(position: [1, -1], textureCoordinate: [1, 1]),
            TexturedVertex(position: [-1, 1], textureCoordinate: [0, 0]),
            TexturedVertex(position: [-1, 1], textureCoordinate: [0, 0]),
            TexturedVertex(position: [1, -1], textureCoordinate: [1, 1]),
            TexturedVertex(position: [1, 1], textureCoordinate: [1, 0])
        ]

        return device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<TexturedVertex>.stride * vertices.count
        )
    }

    private static func makeTexture(device: MTLDevice, image: CGImage) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)

        return try? textureLoader.newTexture(
            cgImage: image,
            options: [
                MTKTextureLoader.Option.SRGB: NSNumber(value: false),
                MTKTextureLoader.Option.textureStorageMode: NSNumber(
                    value: MTLStorageMode.private.rawValue
                )
            ]
        )
    }

    private static func makePipelineState(
        device: MTLDevice,
        library: MTLLibrary,
        style: ShaderEffectStyle
    ) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "glitchVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: style.fragmentFunctionName)
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
}
