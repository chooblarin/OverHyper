@MainActor
final class ShockwaveEffect: ScreenShaderEffect {
    init(screenCaptureService: ScreenCaptureService) {
        super.init(
            style: .shockwave,
            duration: 1.2,
            screenCaptureService: screenCaptureService,
            loggerCategory: "ShockwaveEffect"
        )
    }

    convenience init() {
        self.init(screenCaptureService: ScreenCaptureService())
    }
}
