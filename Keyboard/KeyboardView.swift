import SwiftUI

struct KeyboardActions {
    let insert: (String) -> Void
    let deleteBackward: () -> Void
    let deleteWordBackward: () -> Void
    let deleteWordForward: () -> Void
    let moveCursor: (Int) -> Void
    let moveWord: (_ forward: Bool) -> Void
    let copy: () -> Void
    let cut: () -> Void
    let paste: () -> Void
    let nextKeyboard: () -> Void
}

struct KeyboardView: View {
    static let letterRowHeight: CGFloat = 58
    static let bottomRowHeight: CGFloat = 46
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 6
    static let height = letterRowHeight * 3 + bottomRowHeight + spacing * 3 + padding * 2
    static let coordinateSpace = "keyboard"

    @ObservedObject var state: KeyboardState
    @ObservedObject var clipboard: ClipboardHistory
    let feedback: KeyFeedback
    let actions: KeyboardActions

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - Self.padding * 2 - Self.spacing * 3
            let letterWidth = available / 3.7
            let sideWidth = available - letterWidth * 3
            let isLetters = state.mode == .letters
            let grid = isLetters ? NineKeyLayout.letters : NineKeyLayout.numbers

            VStack(spacing: Self.spacing) {
                if let panel = state.panel {
                    Group {
                        switch panel {
                        case .clipboard:
                            ClipboardPanel(
                                items: clipboard.items,
                                hasFullAccess: state.hasFullAccess,
                                onSelect: { text in
                                    actions.insert(text)
                                    state.panel = nil
                                },
                                onRemove: clipboard.remove,
                                onClear: clipboard.clear,
                                onClose: { state.panel = nil }
                            )
                        case .haptics:
                            HapticsPanel(
                                settings: feedback.settings,
                                hasFullAccess: state.hasFullAccess,
                                preview: feedback.play,
                                onClose: { state.panel = nil }
                            )
                        }
                    }
                    .frame(height: Self.letterRowHeight * 3 + Self.spacing * 2)
                } else {
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
                }

                HStack(spacing: Self.spacing) {
                    if state.showsGlobeKey {
                        TapKey(isModifier: true, action: actions.nextKeyboard) {
                            Image(systemName: "globe")
                        }
                        .frame(width: sideWidth)
                    }
                    if !isLetters && state.panel == nil {
                        LetterKeyView(key: NineKeyLayout.zero, displayText: keyLabel, onAction: perform)
                            .frame(width: letterWidth)
                    }
                    SpaceKey(onSpace: { insert(" ") }, onMoveCursor: actions.moveCursor, onMoveWord: actions.moveWord)
                    TapKey(isModifier: true, action: { insert("\n") }) {
                        Image(systemName: "return")
                    }
                    .frame(width: sideWidth)
                }
                .frame(height: Self.bottomRowHeight)
            }
            .coordinateSpace(name: Self.coordinateSpace)
            .onPreferenceChange(KeyFramesKey.self) { frames in
                feedback.keyFrames = frames
            }
            .environment(\.keyFeedback, feedback)
            .padding(Self.padding)
            .overlay(alignment: .top) {
                if let toast = state.toast {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.regularMaterial))
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                }
            }
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
            ActionKey(swipes: clipboardSwipes, onTap: toggleMode) {
                Text(state.mode == .letters ? "123" : "abc").font(.system(size: 16))
            }
        default:
            DeleteKey(
                onDelete: { deleting(actions.deleteBackward) },
                onDeleteWordBackward: { deleting(actions.deleteWordBackward) },
                onDeleteWordForward: { deleting(actions.deleteWordForward) }
            )
        }
    }

    private var clipboardSwipes: [SwipeDirection: KeySwipe] {
        [
            .top: KeySwipe(systemImage: "doc.on.doc", action: actions.copy),
            .topRight: KeySwipe(systemImage: "scissors", action: actions.cut),
            .bottom: KeySwipe(systemImage: "doc.on.clipboard", action: actions.paste),
            .left: KeySwipe(systemImage: "clock.arrow.circlepath", action: { state.panel = .clipboard }),
            .right: KeySwipe(systemImage: "gearshape", action: { state.panel = .haptics }),
        ]
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
            actions.insert(text)
            return
        }
        state.pendingAccent = nil
        if text == " " {
            actions.insert(accent.symbol)
        } else if let composed = accent.compose(with: text) {
            actions.insert(composed)
        } else {
            actions.insert(accent.symbol + text)
        }
    }

    // Any delete gesture first cancels a pending accent instead of touching the text.
    private func deleting(_ delete: () -> Void) {
        if state.pendingAccent != nil {
            state.pendingAccent = nil
        } else {
            delete()
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
                actions.insert(pending.symbol)
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

// Tap for the centre character, swipe for the others, or draw a small circle for the capital centre letter.
private struct LetterKeyView: View {
    let key: LetterKey
    let displayText: (String) -> String
    let onAction: (KeyAction) -> Void

    @State private var isPressed = false
    @State private var stroke = Stroke()

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
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        stroke.begin(at: value.startLocation)
                    }
                    stroke.add(value.location)
                }
                .onEnded { value in
                    isPressed = false
                    stroke.add(value.location)
                    if stroke.isCircle {
                        onAction(.insert(key.center.uppercased()))
                    } else if let direction = SwipeDirection(translation: value.translation, threshold: swipeThreshold) {
                        if let action = key.swipes[direction] {
                            onAction(action)
                        }
                    } else {
                        onAction(.insert(key.center))
                    }
                }
        )
        .keyFeedback()
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
            .keyFeedback()
    }
}

private struct KeySwipe {
    let systemImage: String
    let action: () -> Void
}

// A modifier key with a tap action plus swipe actions, each shown as a small icon in its corner.
private struct ActionKey<Label: View>: View {
    let swipes: [SwipeDirection: KeySwipe]
    let onTap: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false

    var body: some View {
        KeyFace(isPressed: isPressed, isModifier: true) {
            ZStack {
                label()
                ForEach(Array(swipes), id: \.key) { direction, swipe in
                    Image(systemName: swipe.systemImage)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary)
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: direction.alignment)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { value in
                    isPressed = false
                    if let direction = SwipeDirection(translation: value.translation, threshold: swipeThreshold) {
                        swipes[direction]?.action()
                    } else {
                        onTap()
                    }
                }
        )
        .keyFeedback()
    }
}

// Tap deletes a character, holding repeats, and swiping left/right deletes the word before/after the cursor.
private struct DeleteKey: View {
    let onDelete: () -> Void
    let onDeleteWordBackward: () -> Void
    let onDeleteWordForward: () -> Void

    @State private var isPressed = false
    @State private var isRepeating = false
    @State private var timer: Timer?

    var body: some View {
        KeyFace(isPressed: isPressed, isModifier: true) {
            Image(systemName: "delete.left")
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                            isRepeating = true
                            onDelete()
                            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                                onDelete()
                            }
                        }
                    }
                    if !isRepeating && abs(value.translation.width) >= swipeThreshold {
                        timer?.invalidate()
                        timer = nil
                    }
                }
                .onEnded { value in
                    timer?.invalidate()
                    timer = nil
                    isPressed = false
                    let wasRepeating = isRepeating
                    isRepeating = false
                    guard !wasRepeating else { return }

                    if value.translation.width <= -swipeThreshold {
                        onDeleteWordBackward()
                    } else if value.translation.width >= swipeThreshold {
                        onDeleteWordForward()
                    } else {
                        onDelete()
                    }
                }
        )
        .keyFeedback()
    }
}

// Tap inserts a space. Dragging sideways moves the cursor one character per step;
// a diagonal swipe moves it one word (left diagonals back, right diagonals forward).
private struct SpaceKey: View {
    let onSpace: () -> Void
    let onMoveCursor: (Int) -> Void
    let onMoveWord: (_ forward: Bool) -> Void

    private enum DragMode {
        case undecided, cursor, wordBackward, wordForward, ignored
    }

    @State private var isPressed = false
    @State private var mode = DragMode.undecided
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
                    if mode == .undecided,
                       let direction = SwipeDirection(translation: value.translation, threshold: swipeThreshold) {
                        switch direction {
                        case .left, .right: mode = .cursor
                        case .topLeft, .bottomLeft: mode = .wordBackward
                        case .topRight, .bottomRight: mode = .wordForward
                        case .top, .bottom: mode = .ignored
                        }
                    }
                    if mode == .cursor {
                        let steps = Int(value.translation.width / stepWidth)
                        if steps != cursorSteps {
                            onMoveCursor(steps - cursorSteps)
                            cursorSteps = steps
                        }
                    }
                }
                .onEnded { _ in
                    switch mode {
                    case .undecided: onSpace()
                    case .wordBackward: onMoveWord(false)
                    case .wordForward: onMoveWord(true)
                    case .cursor, .ignored: break
                    }
                    isPressed = false
                    mode = .undecided
                    cursorSteps = 0
                }
        )
        .keyFeedback()
    }
}

private struct KeyFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// Reports the key's position on the keyboard, vibrates when it's touched, and vibrates again
// each time the same touch slides onto a different key (gaps between keys are ignored).
private struct KeyFeedbackModifier: ViewModifier {
    @Environment(\.keyFeedback) private var feedback
    @State private var id = UUID()
    @State private var isTouching = false
    @State private var currentKey: UUID?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: KeyFramesKey.self,
                        value: [id: geo.frame(in: .named(KeyboardView.coordinateSpace))]
                    )
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(KeyboardView.coordinateSpace))
                    .onChanged { value in
                        guard let feedback else { return }
                        guard isTouching else {
                            isTouching = true
                            currentKey = id
                            feedback.keyPressed()
                            return
                        }
                        if let key = feedback.key(at: value.location), key != currentKey {
                            currentKey = key
                            feedback.enteredKey()
                        }
                    }
                    .onEnded { _ in
                        isTouching = false
                        currentKey = nil
                    }
            )
    }
}

private extension View {
    func keyFeedback() -> some View {
        modifier(KeyFeedbackModifier())
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

extension Color {
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
