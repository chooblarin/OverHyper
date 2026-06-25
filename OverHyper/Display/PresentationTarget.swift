import AppKit
import CoreGraphics

enum PresentationTargetMode: String, CaseIterable, Identifiable {
    case allDisplays
    case externalDisplays
    case mainDisplay
    case selectedDisplay

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .allDisplays:
            return "All Displays"
        case .externalDisplays:
            return "External Displays"
        case .mainDisplay:
            return "Main Display"
        case .selectedDisplay:
            return "Selected Display"
        }
    }
}

struct PresentationTarget: Equatable {
    var mode: PresentationTargetMode
    var selectedDisplayID: CGDirectDisplayID?
}

struct DisplaySnapshot: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let isMain: Bool
    let isExternal: Bool

    var displayName: String {
        if isMain {
            return "\(name) (Main)"
        }

        return name
    }

    var detailText: String {
        "\(Int(frame.width)) x \(Int(frame.height))"
    }

    var diagnosticText: String {
        let displayType = isExternal ? "External" : "Built-in"
        let origin = "\(Int(frame.origin.x)), \(Int(frame.origin.y))"
        return "\(displayType) - ID \(id) - Origin \(origin)"
    }
}

enum PresentationTargetWarning: Equatable {
    case noDisplaysAvailable
    case noExternalDisplays
    case externalDisplaysUnavailableAsScreens
    case mainDisplayUnavailable
    case selectedDisplayNotChosen
    case selectedDisplayUnavailable
    case displayIDsUnavailable

    var displayMessage: String {
        switch self {
        case .noDisplaysAvailable:
            return "No displays are currently available."
        case .noExternalDisplays:
            return "No external displays are currently connected."
        case .externalDisplaysUnavailableAsScreens:
            return """
            External displays are connected but are not available as separate displays.
            Use extended display mode or choose All Displays.
            """
        case .mainDisplayUnavailable:
            return "The main display is not currently available."
        case .selectedDisplayNotChosen:
            return "Choose a display before using Selected Display."
        case .selectedDisplayUnavailable:
            return "The selected display is not currently connected."
        case .displayIDsUnavailable:
            return "Connected displays could not be identified."
        }
    }
}

struct PresentationTargetResolution {
    let screens: [NSScreen]
    let displayIDs: Set<CGDirectDisplayID>
    let warning: PresentationTargetWarning?
}

struct PresentationDisplayResolution {
    let displayIDs: Set<CGDirectDisplayID>
    let warning: PresentationTargetWarning?
}

enum DisplayCatalog {
    static func snapshots() -> [DisplaySnapshot] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = displayID(for: screen) else {
                return nil
            }

            return DisplaySnapshot(
                id: displayID,
                name: screen.localizedName,
                frame: screen.frame,
                isMain: displayID == CGMainDisplayID(),
                isExternal: isExternal(displayID: displayID)
            )
        }
    }

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard
            let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber
        else {
            return nil
        }

        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    static func isExternal(displayID: CGDirectDisplayID) -> Bool {
        CGDisplayIsBuiltin(displayID) == 0
    }

    static func onlineExternalDisplayCount() -> Int {
        onlineDisplayIDs().filter { displayID in
            isExternal(displayID: displayID)
        }.count
    }

    private static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else {
            return []
        }

        let capacity = Int(displayCount)
        var displayIDs = Array(repeating: CGDirectDisplayID(), count: capacity)
        guard CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return []
        }

        return Array(displayIDs.prefix(Int(displayCount)))
    }
}

enum PresentationTargetResolver {
    static func resolve(
        screens: [NSScreen],
        target: PresentationTarget
    ) -> PresentationTargetResolution {
        let screenEntries = screens.compactMap { screen -> ScreenEntry? in
            guard let displayID = DisplayCatalog.displayID(for: screen) else {
                return nil
            }

            return ScreenEntry(
                screen: screen,
                displayID: displayID,
                isExternal: DisplayCatalog.isExternal(displayID: displayID)
            )
        }
        let usesNonMainFallback = shouldUseNonMainExternalFallback(
            physicalExternalCount: screenEntries.filter(\.isExternal).count,
            displayCount: screenEntries.count
        )
        let matchedEntries = screenEntries.filter { entry in
            isTargeted(
                displayID: entry.displayID,
                isExternal: entry.isExternal,
                target: target,
                usesNonMainFallback: usesNonMainFallback
            )
        }
        let matchedDisplayIDs = Set(matchedEntries.map(\.displayID))

        return PresentationTargetResolution(
            screens: matchedEntries.map(\.screen),
            displayIDs: matchedDisplayIDs,
            warning: warning(
                for: target,
                matchedDisplayCount: matchedDisplayIDs.count,
                availableDisplayCount: screenEntries.count,
                onlineExternalDisplayCount: DisplayCatalog.onlineExternalDisplayCount(),
                sourceDisplayCount: screens.count
            )
        )
    }

    static func resolve(
        displays: [DisplaySnapshot],
        target: PresentationTarget
    ) -> PresentationDisplayResolution {
        let usesNonMainFallback = shouldUseNonMainExternalFallback(
            physicalExternalCount: displays.filter { display in
                display.isExternal
            }.count,
            displayCount: displays.count
        )
        let matchedDisplayIDs = Set<CGDirectDisplayID>(
            displays.compactMap { display in
                guard isTargeted(
                    displayID: display.id,
                    isExternal: display.isExternal,
                    target: target,
                    usesNonMainFallback: usesNonMainFallback
                ) else {
                    return nil
                }

                return display.id
            }
        )

        return PresentationDisplayResolution(
            displayIDs: matchedDisplayIDs,
            warning: warning(
                for: target,
                matchedDisplayCount: matchedDisplayIDs.count,
                availableDisplayCount: displays.count,
                onlineExternalDisplayCount: DisplayCatalog.onlineExternalDisplayCount(),
                sourceDisplayCount: displays.count
            )
        )
    }

    private static func isTargeted(
        displayID: CGDirectDisplayID,
        isExternal: Bool,
        target: PresentationTarget,
        usesNonMainFallback: Bool
    ) -> Bool {
        switch target.mode {
        case .allDisplays:
            return true
        case .externalDisplays:
            if usesNonMainFallback {
                return displayID != CGMainDisplayID()
            }

            return isExternal
        case .mainDisplay:
            return displayID == CGMainDisplayID()
        case .selectedDisplay:
            return displayID == target.selectedDisplayID
        }
    }

    private static func shouldUseNonMainExternalFallback(
        physicalExternalCount: Int,
        displayCount: Int
    ) -> Bool {
        physicalExternalCount == 0 && displayCount > 1
    }

    private static func warning(
        for target: PresentationTarget,
        matchedDisplayCount: Int,
        availableDisplayCount: Int,
        onlineExternalDisplayCount: Int,
        sourceDisplayCount: Int
    ) -> PresentationTargetWarning? {
        if matchedDisplayCount > 0 {
            return nil
        }

        if sourceDisplayCount > 0, availableDisplayCount == 0 {
            return .displayIDsUnavailable
        }

        if availableDisplayCount == 0 {
            return .noDisplaysAvailable
        }

        switch target.mode {
        case .allDisplays:
            return .noDisplaysAvailable
        case .externalDisplays:
            if onlineExternalDisplayCount > 0 {
                return .externalDisplaysUnavailableAsScreens
            }

            return .noExternalDisplays
        case .mainDisplay:
            return .mainDisplayUnavailable
        case .selectedDisplay:
            if target.selectedDisplayID == nil {
                return .selectedDisplayNotChosen
            }

            return .selectedDisplayUnavailable
        }
    }

    private struct ScreenEntry {
        let screen: NSScreen
        let displayID: CGDirectDisplayID
        let isExternal: Bool
    }
}
