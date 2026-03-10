import AppKit
import Carbon.HIToolbox

struct Hotkey: Hashable {
    let keyCode: UInt32
    let modifierFlags: NSEvent.ModifierFlags

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        lhs.keyCode == rhs.keyCode
            && lhs.modifierFlags.rawValue == rhs.modifierFlags.rawValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifierFlags.rawValue)
    }
}

struct HotkeyRegistrationToken: Hashable {
    let identifier: UInt32
}

extension Hotkey {
    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0

        if modifierFlags.contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if modifierFlags.contains(.option) {
            flags |= UInt32(optionKey)
        }
        if modifierFlags.contains(.control) {
            flags |= UInt32(controlKey)
        }
        if modifierFlags.contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        if modifierFlags.contains(.function) {
            flags |= UInt32(kEventKeyModifierFnMask)
        }

        return flags
    }
}
