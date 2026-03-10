@MainActor
final class CrackedGlassEffect: ScreenShaderEffect {
    init(screenCaptureService: ScreenCaptureService) {
        super.init(
            style: .crackedGlass,
            duration: 1.35,
            screenCaptureService: screenCaptureService,
            loggerCategory: "CrackedGlassEffect"
        )
    }

    convenience init() {
        self.init(screenCaptureService: ScreenCaptureService())
    }
}
