@MainActor
final class CRTBurstEffect: ScreenShaderEffect {
    init(screenCaptureService: ScreenCaptureService) {
        super.init(
            style: .crtBurst,
            duration: 0.9,
            screenCaptureService: screenCaptureService,
            loggerCategory: "CRTBurstEffect"
        )
    }

    convenience init() {
        self.init(screenCaptureService: ScreenCaptureService())
    }
}
