import AppKit

@MainActor
final class LightningEffect: OverlayEffect {
    private enum Constants {
        static let duration: TimeInterval = 2.1
    }

    func fire(in context: OverlayRenderContext, settings: EffectSettings) {
        let requestID = context.hostView.beginShaderRequest()

        guard let overlayView = LightningMetalOverlayView(
            frame: context.hostView.bounds,
            duration: Constants.duration
        ) else {
            return
        }

        context.hostView.installShaderSubview(overlayView, requestID: requestID)

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.duration
        ) { [weak hostView = context.hostView, weak overlayView] in
            guard let hostView, let overlayView else {
                return
            }

            hostView.clearShaderSubview(ifMatching: overlayView, requestID: requestID)
        }
    }
}
