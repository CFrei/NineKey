import SwiftUI

struct KeyboardView: View {
    static let letterRowHeight: CGFloat = 58
    static let bottomRowHeight: CGFloat = 46
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 6
    static let height = letterRowHeight * 3 + bottomRowHeight + spacing * 3 + padding * 2

    @ObservedObject var state: KeyboardState
    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let onMoveCursor: (Int) -> Void
    let onNextKeyboard: () -> Void

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - Self.padding * 2 - Self.spacing * 3
            let letterWidth = available / 3.7
            let sideWidth = available - letterWidth * 3
            let isLetters = state.mode == .letters
            let grid = isLetters ? NineKeyLayout.letters : NineKeyLayout.numbers

            VStack(spacing: Self.spacing) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: Self.spacing) {
                        ForEach(0..<3, id: \.self) { column in
                            LetterKeyView(
                                key: grid[row][column],
                                displayText: keyLabel,
                                onAction: perform
                            )
                            .frame(width: letterWidth)
                        }
                        sideKey(row: row).frame(width: sideWidth)
                    }
                    .frame(height: Self.letterRowHeight)
                }

                HStack(spacing: Self.spacing) {
                    if state.showsGlobeKey {
                        TapKey(isModifier: true, action: onNextKeyboard) {
                            Image(systemName: "globe")
                        }
                        .frame(width: sideWidth)
                    }
                    if !isLetters {
                        LetterKeyView(key: NineKeyLayout.zero, displayText: keyLabel, onAction: perform)
                            .frame(width: letterWidth)
                    }
                    SpaceKey(onSpace: { insert(" ") }, onMoveCursor: onMoveCursor)
                    TapKey(isModifier: true, action: { insert("\n") }) {
                        Image(systemName: "return")
                    }
                    .frame(width: sideWidth)
                }
                .frame(height: Self.bottomRowHeight)
            }
            .padding(Self.padding)
        }
        .frame(height: Self.height)
    }

    @ViewBuilder
    private func sideKey(row: Int) -> some View {
        switch row {
        case 0:
            if state.mode == .letters {
                TapKey(isModifier: true, action: { state.isShifted.toggle() }) {
                    Image(systemName: state.isShifted ? "shift.fill" : "shift")
                }
            } else {
                Color.clear
            }
        case 1:
            TapKey(isModifier: true, action: toggleMode) {
                Text(state.mode == .letters ? "123" : "abc").font(.system(size: 16))
            }
        default:
            RepeatKey(action: delete) {
                Image(systemName: "delete.left")
            }
        }
    }

    private func keyLabel(_ text: String) -> String {
        guard state.mode == .letters, text.first?.isLetter == true else { return text }
        let cased = state.isShifted ? text.uppercased() : text
        return state.pendingAccent?.compose(with: cased) ?? cased
    }

    // Applies a pending dead key: "´" then "e" gives "é", "´" then space gives "´",
    // and a letter that can't take the accent gets the plain accent in front of it.
    private func insert(_ text: String) {
        guard let accent = state.pendingAccent else {
            onInsert(text)
            return
        }
        state.pendingAccent = nil
        if text == " " {
            onInsert(accent.symbol)
        } else if let composed = accent.compose(with: text) {
            onInsert(composed)
        } else {
            onInsert(accent.symbol + text)
        }
    }

    private func delete() {
        if state.pendingAccent != nil {
            state.pendingAccent = nil
        } else {
            onDelete()
        }
    }

    private func toggleMode() {
        state.mode = state.mode == .letters ? .numbers : .letters
        state.isShifted = false
    }

    private func perform(_ action: KeyAction) {
        switch action {
        case .insert(let text, _):
            let shouldCapitalize = state.isShifted && state.mode == .letters
            insert(shouldCapitalize ? text.uppercased() : text)
            state.isShifted = false
        case .deadKey(let accent):
            if let pending = state.pendingAccent {
                state.pendingAccent = nil
                onInsert(pending.symbol)
                if pending == accent { return }
            }
            state.pendingAccent = accent
        case .shiftOn:
            state.isShifted = true
        case .shiftOff:
            state.isShifted = false
        }
    }
}

private let swipeThreshold: CGFloat = 18

private struct LetterKeyView: View {
    let key: LetterKey
    let displayText: (String) -> String
    let onAction: (KeyAction) -> Void

    @State private var isPressed = false

    var body: some View {
        KeyFace(isPressed: isPressed, isModifier: false) {
            ZStack {
                Text(displayText(key.center))
                    .font(.system(size: 26))
                ForEach(Array(key.swipes), id: \.key) { direction, action in
                    if let label = action.label {
                        Text(displayText(label))
                            .font(.system(size: action.isLetter ? 13 : 11))
                            .foregroundStyle(action.isLetter ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: direction.alignment)
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { value in
                    isPressed = false
                    if let direction = SwipeDirection(translation: value.translation, threshold: swipeThreshold) {
                        if let action = key.swipes[direction] {
                            onAction(action)
                        }
                    } else {
                        onAction(.insert(key.center))
                    }
                }
        )
    }
}

private struct TapKey<Label: View>: View {
    let isModifier: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false

    var body: some View {
        KeyFace(isPressed: isPressed, isModifier: isModifier, content: label)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

private struct RepeatKey<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false
    @State private var timer: Timer?

    var body: some View {
        KeyFace(isPressed: isPressed, isModifier: true, content: label)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                                action()
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        timer?.invalidate()
                        timer = nil
                    }
            )
    }
}

// Tap inserts a space; dragging sideways moves the cursor one character per step.
private struct SpaceKey: View {
    let onSpace: () -> Void
    let onMoveCursor: (Int) -> Void

    @State private var isPressed = false
    @State private var cursorSteps = 0

    private let stepWidth: CGFloat = 12

    var body: some View {
        KeyFace(isPressed: isPressed, isModifier: false) {
            Text("space").font(.system(size: 15))
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isPressed = true
                    let steps = Int(value.translation.width / stepWidth)
                    if steps != cursorSteps {
                        onMoveCursor(steps - cursorSteps)
                        cursorSteps = steps
                    }
                }
                .onEnded { value in
                    isPressed = false
                    let moved = cursorSteps != 0 || abs(value.translation.width) >= stepWidth
                    if !moved {
                        onSpace()
                    }
                    cursorSteps = 0
                }
        )
    }
}

private struct KeyFace<Content: View>: View {
    let isPressed: Bool
    let isModifier: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? Color.pressedKey : (isModifier ? Color.modifierKey : Color.letterKey))
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 1)
            )
            .contentShape(Rectangle())
    }
}

private extension Color {
    static let letterKey = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white
    })
    static let modifierKey = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : UIColor(white: 0.68, alpha: 1)
    })
    static let pressedKey = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.82, alpha: 1)
    })
}
