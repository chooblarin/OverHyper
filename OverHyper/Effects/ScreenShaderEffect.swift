import AppKit
import OSLog

@MainActor
class ScreenShaderEffect: OverlayEffect {
    private let style: ShaderEffectStyle
    private let effectDuration: TimeInterval
    private let screenCaptureService: ScreenCaptureService
    private let logger: Logger

    init(
        style: ShaderEffectStyle,
        duration: TimeInterval,
        screenCaptureService: ScreenCaptureService,
        loggerCategory: String
    ) {
        self.style = style
        effectDuration = duration
        self.screenCaptureService = screenCaptureService
        logger = Logger(subsystem: "OverHyper", category: loggerCategory)
    }

    func prepareForRender(settings: EffectSettings) -> Bool {
        screenCaptureService.ensurePermission()
    }

    func fire(in context: OverlayRenderContext, settings: EffectSettings) {
        let requestID = context.hostView.beginShaderRequest()

        Task { @MainActor [screen = context.screen, weak hostView = context.hostView] in
            guard let hostView else {
                return
            }

            guard let image = await screenCaptureService.capture(screen: screen) else {
                logger.error("Failed to capture display for shader effect")
                return
            }

            guard hostView.isCurrentShaderRequest(requestID) else {
                return
            }

            guard let overlayView = MetalOverlayView(
                frame: hostView.bounds,
                image: image,
                style: style,
                duration: effectDuration
            ) else {
                logger.error("Failed to create Metal overlay view")
                return
            }

            hostView.installShaderSubview(overlayView, requestID: requestID)

            DispatchQueue.main.asyncAfter(
                deadline: .now() + effectDuration
            ) { [weak hostView, weak overlayView] in
                guard let hostView, let overlayView else {
                    return
                }

                hostView.clearShaderSubview(
                    ifMatching: overlayView,
                    requestID: requestID
                )
            }
        }
    }
}
