@MainActor
final class NeonEdgeEffect: ScreenShaderEffect {
    init(screenCaptureService: ScreenCaptureService) {
        super.init(
            style: .neonEdge,
            duration: 0.95,
            screenCaptureService: screenCaptureService,
            loggerCategory: "NeonEdgeEffect"
        )
    }

    convenience init() {
        self.init(screenCaptureService: ScreenCaptureService())
    }
}
