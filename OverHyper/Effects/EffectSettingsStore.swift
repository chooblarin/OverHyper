import Combine
import Foundation

@MainActor
final class EffectSettingsStore: ObservableObject {
    static let shared = EffectSettingsStore()

    @Published private(set) var hotkeyAssignments: [HotkeySlotAssignment] {
        didSet {
            persistHotkeyAssignments()
        }
    }

    var settings: EffectSettings {
        EffectSettings()
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        hotkeyAssignments = HotkeySlotID.allCases.map { slotID in
            HotkeySlotAssignment(
                slotID: slotID,
                assignedEffect: Keys.defaultAssignedEffect(for: slotID)
            )
        }

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
}

private enum Keys {
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
