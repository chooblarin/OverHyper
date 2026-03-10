@MainActor
final class RainGlassEffect: ScreenShaderEffect {
    init(screenCaptureService: ScreenCaptureService) {
        super.init(
            style: .rainGlass,
            duration: 5.2,
            screenCaptureService: screenCaptureService,
            loggerCategory: "RainGlassEffect"
        )
    }

    convenience init() {
        self.init(screenCaptureService: ScreenCaptureService())
    }
}
