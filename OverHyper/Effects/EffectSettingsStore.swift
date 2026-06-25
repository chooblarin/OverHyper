import Combine
import CoreGraphics
import Foundation

@MainActor
final class EffectSettingsStore: ObservableObject {
    static let shared = EffectSettingsStore()

    @Published var presentationTargetMode: PresentationTargetMode {
        didSet {
            persistPresentationTarget()
        }
    }

    @Published var selectedDisplayID: CGDirectDisplayID? {
        didSet {
            persistPresentationTarget()
        }
    }

    @Published private(set) var hotkeyAssignments: [HotkeySlotAssignment] {
        didSet {
            persistHotkeyAssignments()
        }
    }

    var settings: EffectSettings {
        EffectSettings(presentationTarget: presentationTarget)
    }

    var presentationTarget: PresentationTarget {
        PresentationTarget(
            mode: presentationTargetMode,
            selectedDisplayID: selectedDisplayID
        )
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        presentationTargetMode = .allDisplays
        selectedDisplayID = nil
        hotkeyAssignments = HotkeySlotID.allCases.map { slotID in
            HotkeySlotAssignment(
                slotID: slotID,
                assignedEffect: Keys.defaultAssignedEffect(for: slotID)
            )
        }

        loadPresentationTarget()
        loadHotkeyAssignments()
    }

    func assignedEffect(for slotID: HotkeySlotID) -> EffectKind? {
        hotkeyAssignments.first { $0.slotID == slotID }?.assignedEffect
    }

    func setAssignedEffect(_ effect: EffectKind?, for slotID: HotkeySlotID) {
        guard let index = hotkeyAssignments.firstIndex(where: { $0.slotID == slotID }) else {
            return
        }

        hotkeyAssignments[index].assignedEffect = effect
    }

    func setPresentationTargetMode(_ mode: PresentationTargetMode) {
        presentationTargetMode = mode
    }

    func setSelectedDisplayID(_ displayID: CGDirectDisplayID?) {
        selectedDisplayID = displayID
    }

    private func loadPresentationTarget() {
        if let storedMode = userDefaults.string(forKey: Keys.presentationTargetMode),
           let mode = PresentationTargetMode(rawValue: storedMode) {
            presentationTargetMode = mode
        }

        if userDefaults.object(forKey: Keys.selectedDisplayID) != nil {
            let storedDisplayID = userDefaults.integer(forKey: Keys.selectedDisplayID)
            selectedDisplayID = CGDirectDisplayID(storedDisplayID)
        }
    }

    private func loadHotkeyAssignments() {
        hotkeyAssignments = HotkeySlotID.allCases.map { slotID in
            let storedValue = userDefaults.string(forKey: Keys.hotkeyAssignmentKey(for: slotID))
            let assignedEffect = storedValue.flatMap(EffectKind.init(rawValue:))
                ?? Keys.defaultAssignedEffect(for: slotID)

            return HotkeySlotAssignment(
                slotID: slotID,
                assignedEffect: assignedEffect
            )
        }
    }

    private func persistHotkeyAssignments() {
        for assignment in hotkeyAssignments {
            let key = Keys.hotkeyAssignmentKey(for: assignment.slotID)
            if let rawValue = assignment.assignedEffect?.rawValue {
                userDefaults.set(rawValue, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
        }
    }

    private func persistPresentationTarget() {
        userDefaults.set(presentationTargetMode.rawValue, forKey: Keys.presentationTargetMode)

        if let selectedDisplayID {
            userDefaults.set(Int(selectedDisplayID), forKey: Keys.selectedDisplayID)
        } else {
            userDefaults.removeObject(forKey: Keys.selectedDisplayID)
        }
    }
}

private enum Keys {
    static let presentationTargetMode = "overhyper.settings.presentationTarget.mode"
    static let selectedDisplayID = "overhyper.settings.presentationTarget.selectedDisplayID"

    static func hotkeyAssignmentKey(for slotID: HotkeySlotID) -> String {
        "overhyper.settings.hotkey.\(slotID.rawValue)"
    }

    static func defaultAssignedEffect(for slotID: HotkeySlotID) -> EffectKind? {
        switch slotID {
        case .slot1:
            return .confetti
        case .slot2:
            return .flash
        case .slot3:
            return .glitch
        case .slot4, .slot5:
            return nil
        }
    }
}
