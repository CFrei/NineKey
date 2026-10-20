import CoreGraphics
import SwiftUI

enum SwipeDirection: CaseIterable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

    init?(translation: CGSize, threshold: CGFloat) {
        let dx = translation.width
        let dy = -translation.height
        guard hypot(dx, dy) >= threshold else { return nil }
        switch Int((atan2(dy, dx) / (.pi / 4)).rounded()) {
        case 0: self = .right
        case 1: self = .topRight
        case 2: self = .top
        case 3: self = .topLeft
        case 4, -4: self = .left
        case -3: self = .bottomLeft
        case -2: self = .bottom
        case -1: self = .bottomRight
        default: return nil
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeft: .topLeading
        case .top: .top
        case .topRight: .topTrailing
        case .left: .leading
        case .right: .trailing
        case .bottomLeft: .bottomLeading
        case .bottom: .bottom
        case .bottomRight: .bottomTrailing
        }
    }
}

enum KeyAction: Equatable {
    case insert(String)
    case shiftOn
    case shiftOff

    var label: String? {
        switch self {
        case .insert(let text): text
        case .shiftOn: "⇧"
        case .shiftOff: nil
        }
    }
}

struct LetterKey {
    let center: String
    let swipes: [SwipeDirection: KeyAction]
}

// English MessagEase-style layout, as defined by Thumb-Key (ENMessagEase.kt).
enum NineKeyLayout {
    static let english: [[LetterKey]] = [
        [
            LetterKey(center: "a", swipes: [.bottomRight: .insert("v")]),
            LetterKey(center: "n", swipes: [.bottom: .insert("l")]),
            LetterKey(center: "i", swipes: [.bottomLeft: .insert("x")]),
        ],
        [
            LetterKey(center: "h", swipes: [.right: .insert("k")]),
            LetterKey(center: "o", swipes: [
                .topLeft: .insert("q"), .top: .insert("u"), .topRight: .insert("p"),
                .left: .insert("c"), .right: .insert("b"),
                .bottomLeft: .insert("g"), .bottom: .insert("d"), .bottomRight: .insert("j"),
            ]),
            LetterKey(center: "r", swipes: [.left: .insert("m"), .top: .shiftOn, .bottom: .shiftOff]),
        ],
        [
            LetterKey(center: "t", swipes: [.topRight: .insert("y")]),
            LetterKey(center: "e", swipes: [
                .top: .insert("w"), .topRight: .insert("'"), .right: .insert("z"),
                .bottomRight: .insert(":"), .bottom: .insert("."), .bottomLeft: .insert(","),
            ]),
            LetterKey(center: "s", swipes: [.topLeft: .insert("f")]),
        ],
    ]
}
