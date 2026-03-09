import Carbon.HIToolbox
import Foundation
import MASShortcut

enum HotkeySlotID: String, CaseIterable, Identifiable {
    case slot1
    case slot2
    case slot3
    case slot4
    case slot5

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .slot1:
            return "Control + Option + Command + 1"
        case .slot2:
            return "Control + Option + Command + 2"
        case .slot3:
            return "Control + Option + Command + 3"
        case .slot4:
            return "Control + Option + Command + 4"
        case .slot5:
            return "Control + Option + Command + 5"
        }
    }

    var shortcut: MASShortcut {
        MASShortcut(
            keyCode: keyCode,
            modifierFlags: [.control, .option, .command]
        )
    }

    private var keyCode: Int {
        switch self {
        case .slot1:
            return Int(kVK_ANSI_1)
        case .slot2:
            return Int(kVK_ANSI_2)
        case .slot3:
            return Int(kVK_ANSI_3)
        case .slot4:
            return Int(kVK_ANSI_4)
        case .slot5:
            return Int(kVK_ANSI_5)
        }
    }
}

struct HotkeySlotAssignment: Identifiable, Equatable {
    let slotID: HotkeySlotID
    var assignedEffect: EffectKind?

    var id: HotkeySlotID {
        slotID
    }
}
