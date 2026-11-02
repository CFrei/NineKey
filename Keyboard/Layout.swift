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

enum Accent: Equatable {
    case grave, acute, circumflex

    var symbol: String {
        switch self {
        case .grave: "`"
        case .acute: "´"
        case .circumflex: "^"
        }
    }

    private var combiningMark: String {
        switch self {
        case .grave: "\u{0300}"
        case .acute: "\u{0301}"
        case .circumflex: "\u{0302}"
        }
    }

    /// The accented letter, or nil when no precomposed character exists (e.g. "´" + "k").
    func compose(with text: String) -> String? {
        guard text.count == 1, text.first?.isLetter == true else { return nil }
        let composed = (text + combiningMark).precomposedStringWithCanonicalMapping
        return composed.unicodeScalars.count == 1 ? composed : nil
    }
}

enum KeyAction: Equatable {
    case insert(String, display: String? = nil)
    case deadKey(Accent)
    case shiftOn
    case shiftOff

    var label: String? {
        switch self {
        case .insert(let text, let display): display ?? text
        case .deadKey(let accent): accent.symbol
        case .shiftOn: "⇧"
        case .shiftOff: nil
        }
    }

    var isLetter: Bool {
        if case .insert(let text, _) = self {
            return text.first?.isLetter == true
        }
        return false
    }
}

struct LetterKey {
    let center: String
    let swipes: [SwipeDirection: KeyAction]
}

enum KeyboardMode {
    case letters, numbers
}

// English MessagEase-style layout, as defined by Thumb-Key
// (ENMessagEaseSymbols.kt and NumericENMessagEase.kt), with d/o swapped and ä/ö/ü
// placed as in DEMessagEaseSymbols.kt.
enum NineKeyLayout {
    static let letters: [[LetterKey]] = [
        [
            LetterKey(center: "a", swipes: [
                .bottomRight: .insert("v"), .bottom: .insert("ä"),
                .right: .insert("-"), .bottomLeft: .insert("$"),
            ]),
            LetterKey(center: "n", swipes: [
                .bottom: .insert("l"),
                .topLeft: .deadKey(.grave), .top: .deadKey(.circumflex), .topRight: .deadKey(.acute),
                .left: .insert("+"), .right: .insert("!"),
                .bottomLeft: .insert("/"), .bottomRight: .insert("\\"),
            ]),
            LetterKey(center: "i", swipes: [
                .bottomLeft: .insert("x"),
                .left: .insert("?"), .bottom: .insert("="), .bottomRight: .insert("€"),
            ]),
        ],
        [
            LetterKey(center: "h", swipes: [
                .right: .insert("k"), .top: .insert("ü"), .bottom: .insert("ö"),
                .topLeft: .insert("{"), .topRight: .insert("%"), .left: .insert("("),
                .bottomLeft: .insert("["), .bottomRight: .insert("_"),
            ]),
            LetterKey(center: "d", swipes: [
                .topLeft: .insert("q"), .top: .insert("u"), .topRight: .insert("p"),
                .left: .insert("c"), .right: .insert("b"),
                .bottomLeft: .insert("g"), .bottom: .insert("o"), .bottomRight: .insert("j"),
            ]),
            LetterKey(center: "r", swipes: [
                .left: .insert("m"), .top: .shiftOn, .bottom: .shiftOff,
                .topLeft: .insert("|"), .topRight: .insert("}"), .right: .insert(")"),
                .bottomLeft: .insert("@"), .bottomRight: .insert("]"),
            ]),
        ],
        [
            LetterKey(center: "t", swipes: [
                .topRight: .insert("y"),
                .topLeft: .insert("~"), .left: .insert("<"), .right: .insert("*"),
                .bottomRight: .insert("\t", display: "⇥"),
            ]),
            LetterKey(center: "e", swipes: [
                .top: .insert("w"), .right: .insert("z"),
                .topLeft: .insert("\""), .topRight: .insert("'"),
                .bottomLeft: .insert(","), .bottom: .insert("."), .bottomRight: .insert(":"),
            ]),
            LetterKey(center: "s", swipes: [
                .topLeft: .insert("f"),
                .top: .insert("&"), .topRight: .insert("°"), .left: .insert("#"),
                .right: .insert(">"), .bottomLeft: .insert(";"),
            ]),
        ],
    ]

    static let numbers: [[LetterKey]] = [
        [
            LetterKey(center: "1", swipes: [
                .right: .insert("-"), .bottomLeft: .insert("$"),
            ]),
            LetterKey(center: "2", swipes: [
                .topLeft: .insert("`"), .top: .insert("^"), .topRight: .insert("´"),
                .left: .insert("+"), .right: .insert("!"),
                .bottomLeft: .insert("/"), .bottomRight: .insert("\\"),
            ]),
            LetterKey(center: "3", swipes: [
                .left: .insert("?"), .bottomLeft: .insert("£"),
                .bottom: .insert("="), .bottomRight: .insert("€"),
            ]),
        ],
        [
            LetterKey(center: "4", swipes: [
                .topLeft: .insert("{"), .topRight: .insert("%"), .left: .insert("("),
                .bottomLeft: .insert("["), .bottomRight: .insert("_"),
            ]),
            LetterKey(center: "5", swipes: [
                .top: .insert("¬"),
            ]),
            LetterKey(center: "6", swipes: [
                .topLeft: .insert("|"), .topRight: .insert("}"), .right: .insert(")"),
                .bottomLeft: .insert("@"), .bottomRight: .insert("]"),
            ]),
        ],
        [
            LetterKey(center: "7", swipes: [
                .topLeft: .insert("~"), .left: .insert("<"), .right: .insert("*"),
                .bottomRight: .insert("\t", display: "⇥"),
            ]),
            LetterKey(center: "8", swipes: [
                .topLeft: .insert("\""), .topRight: .insert("'"),
                .bottomLeft: .insert(","), .bottom: .insert("."), .bottomRight: .insert(":"),
            ]),
            LetterKey(center: "9", swipes: [
                .top: .insert("&"), .topRight: .insert("°"), .left: .insert("#"),
                .right: .insert(">"), .bottomLeft: .insert(";"),
            ]),
        ],
    ]

    static let zero = LetterKey(center: "0", swipes: [:])
}
