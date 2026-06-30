#if DEBUG
import AppKit
import SwiftUI

struct ShaderLabView: View {
    @State private var selectedStyle = ShaderEffectStyle.glitch
    @State private var duration = 1.6
    @State private var intensity = 1.0
    @State private var isPlaying = true
    @State private var pausedTime = 0.0
    @State private var playbackAnchorDate = Date()
    @State private var playbackAnchorTime = 0.0

    private let sampleImage = ShaderPreviewImage.make()

    var body: some View {
        TimelineView(.animation) { timeline in
            let currentTime = previewTime(at: timeline.date)

            HStack(spacing: 0) {
                effectSidebar

                Divider()

                VStack(spacing: 16) {
                    ShaderPreviewMetalView(
                        style: selectedStyle,
                        image: sampleImage,
                        elapsedTime: currentTime,
                        duration: duration,
                        intensity: intensity
                    )
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    controls(currentTime: currentTime)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 920, minHeight: 560)
        .onChange(of: selectedStyle) {
            restart()
        }
        .onChange(of: duration) {
            pausedTime = min(pausedTime, duration)
            playbackAnchorTime = min(playbackAnchorTime, duration)
        }
    }

    private var effectSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shader Lab")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(ShaderEffectStyle.allCases) { style in
                Button {
                    selectedStyle = style
                } label: {
                    HStack {
                        Text(style.displayName)
                        Spacer()
                        if selectedStyle == style {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    selectedStyle == style
                    ? Color.accentColor.opacity(0.16)
                    : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer()
        }
        .frame(width: 190)
        .padding(16)
    }

    private func controls(currentTime: Double) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    togglePlayback(currentTime: currentTime)
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 18)
                }
                .help(isPlaying ? "Pause" : "Play")

                Button {
                    restart()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 18)
                }
                .help("Restart")

                Text(timeText(currentTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: {
                            currentTime
                        },
                        set: { newValue in
                            pause(at: newValue)
                        }
                    ),
                    in: 0...duration
                )
            }

            HStack(spacing: 18) {
                controlSlider(
                    title: "Intensity",
                    value: $intensity,
                    range: 0...1.8,
                    formattedValue: String(format: "%.2f", intensity)
                )

                controlSlider(
                    title: "Duration",
                    value: $duration,
                    range: 0.4...4.0,
                    formattedValue: String(format: "%.1fs", duration)
                )
            }
        }
    }

    private func controlSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        formattedValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)
        }
    }

    private func previewTime(at date: Date) -> Double {
        guard isPlaying else {
            return pausedTime
        }

        let elapsed = date.timeIntervalSince(playbackAnchorDate)
        return (playbackAnchorTime + elapsed).truncatingRemainder(dividingBy: duration)
    }

    private func togglePlayback(currentTime: Double) {
        if isPlaying {
            pause(at: currentTime)
        } else {
            playbackAnchorTime = pausedTime
            playbackAnchorDate = Date()
            isPlaying = true
        }
    }

    private func pause(at time: Double) {
        pausedTime = min(max(time, 0), duration)
        playbackAnchorTime = pausedTime
        playbackAnchorDate = Date()
        isPlaying = false
    }

    private func restart() {
        pausedTime = 0
        playbackAnchorTime = 0
        playbackAnchorDate = Date()
        isPlaying = true
    }

    private func timeText(_ currentTime: Double) -> String {
        "\(String(format: "%.2f", currentTime)) / \(String(format: "%.2f", duration))"
    }
}

private struct ShaderPreviewMetalView: NSViewRepresentable {
    let style: ShaderEffectStyle
    let image: CGImage
    let elapsedTime: Double
    let duration: Double
    let intensity: Double

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ShaderPreviewContainerView {
        let view = ShaderPreviewContainerView()
        updateCoordinator(context.coordinator)
        view.configure(
            style: style,
            image: image,
            renderState: context.coordinator.renderState
        )
        return view
    }

    func updateNSView(_ nsView: ShaderPreviewContainerView, context: Context) {
        updateCoordinator(context.coordinator)
        nsView.configure(
            style: style,
            image: image,
            renderState: context.coordinator.renderState
        )
    }

    private func updateCoordinator(_ coordinator: Coordinator) {
        coordinator.renderState.elapsedTime = Float(elapsedTime)
        coordinator.renderState.duration = Float(duration)
        coordinator.renderState.intensity = Float(intensity)
    }

    final class Coordinator {
        let renderState = ShaderPreviewRenderState()
    }
}

private final class ShaderPreviewRenderState {
    var elapsedTime: Float = 0
    var duration: Float = 1.6
    var intensity: Float = 1
}

private final class ShaderPreviewContainerView: NSView {
    private var currentStyle: ShaderEffectStyle?
    private var metalView: MetalOverlayView?

    func configure(
        style: ShaderEffectStyle,
        image: CGImage,
        renderState: ShaderPreviewRenderState
    ) {
        guard currentStyle != style || metalView == nil else {
            return
        }

        metalView?.removeFromSuperview()
        guard let previewView = MetalOverlayView(
            frame: bounds,
            image: image,
            style: style,
            duration: TimeInterval(renderState.duration),
            durationProvider: { [weak renderState] in
                renderState?.duration ?? 1.6
            },
            elapsedTimeProvider: { [weak renderState] in
                renderState?.elapsedTime ?? 0
            },
            tweakProvider: { [weak renderState] in
                SIMD4<Float>(renderState?.intensity ?? 1, 0, 0, 0)
            }
        ) else {
            currentStyle = nil
            return
        }

        previewView.frame = bounds
        previewView.autoresizingMask = [.width, .height]
        addSubview(previewView)
        metalView = previewView
        currentStyle = style
    }

    override func layout() {
        super.layout()
        metalView?.frame = bounds
    }
}

private enum ShaderPreviewImage {
    static func make() -> CGImage {
        let width = 1280
        let height = 720
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        else {
            fatalError("Failed to create shader preview image")
        }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        drawBackground(in: context, bounds: bounds)
        drawGrid(in: context, bounds: bounds)
        drawPanels(in: context)

        guard let image = context.makeImage() else {
            fatalError("Failed to render shader preview image")
        }

        return image
    }

    private static func drawBackground(in context: CGContext, bounds: CGRect) {
        let colors = [
            NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.09, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.21, alpha: 1).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 1]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else {
            return
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.minX, y: bounds.minY),
            end: CGPoint(x: bounds.maxX, y: bounds.maxY),
            options: []
        )
    }

    private static func drawGrid(in context: CGContext, bounds: CGRect) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
        context.setLineWidth(1)

        stride(from: CGFloat(0), through: bounds.width, by: 64).forEach { x in
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))
        }

        stride(from: CGFloat(0), through: bounds.height, by: 64).forEach { y in
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }

        context.strokePath()
    }

    private static func drawPanels(in context: CGContext) {
        let panels: [(CGRect, NSColor)] = [
            (CGRect(x: 96, y: 96, width: 330, height: 210), .systemCyan),
            (CGRect(x: 476, y: 132, width: 250, height: 456), .systemPink),
            (CGRect(x: 780, y: 86, width: 390, height: 250), .systemYellow),
            (CGRect(x: 832, y: 390, width: 280, height: 210), .systemGreen)
        ]

        for (rect, color) in panels {
            context.setFillColor(color.withAlphaComponent(0.72).cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.40).cgColor)
            context.setLineWidth(4)
            context.stroke(rect)
        }
    }
}
#endif
