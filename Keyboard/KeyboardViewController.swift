import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let state = KeyboardState()
    private let clipboard = ClipboardHistory()
    private var toastDismissal: DispatchWorkItem?

    private var proxy: UITextDocumentProxy { textDocumentProxy }

    override func viewDidLoad() {
        super.viewDidLoad()

        let actions = KeyboardActions(
            insert: { [weak self] text in self?.proxy.insertText(text) },
            deleteBackward: { [weak self] in self?.proxy.deleteBackward() },
            deleteWordBackward: { [weak self] in self?.deleteWordBackward() },
            deleteWordForward: { [weak self] in self?.deleteWordForward() },
            moveCursor: { [weak self] offset in self?.proxy.adjustTextPosition(byCharacterOffset: offset) },
            moveWord: { [weak self] forward in self?.moveCursorByWord(forward: forward) },
            copy: { [weak self] in self?.copySelection(cut: false) },
            cut: { [weak self] in self?.copySelection(cut: true) },
            paste: { [weak self] in self?.paste() },
            nextKeyboard: { [weak self] in self?.advanceToNextInputMode() }
        )

        let host = UIHostingController(rootView: KeyboardView(state: state, clipboard: clipboard, actions: actions))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.heightAnchor.constraint(equalToConstant: KeyboardView.height),
        ])
        host.didMove(toParent: self)
    }

    // needsInputModeSwitchKey is only reliable once the keyboard is laid out.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if state.showsGlobeKey != needsInputModeSwitchKey {
            state.showsGlobeKey = needsInputModeSwitchKey
        }
        if state.hasFullAccess != hasFullAccess {
            state.hasFullAccess = hasFullAccess
        }
    }

    // MARK: - Words

    private func deleteWordBackward() {
        if hasSelection {
            proxy.deleteBackward()
            return
        }
        let word = (proxy.documentContextBeforeInput ?? "").trailingWord
        for _ in 0..<max(word.count, 1) {
            proxy.deleteBackward()
        }
    }

    private func deleteWordForward() {
        if hasSelection {
            proxy.deleteBackward()
            return
        }
        let word = (proxy.documentContextAfterInput ?? "").leadingWord
        guard !word.isEmpty else { return }
        // Hosts count cursor offsets in UTF-16 units, while deleteBackward removes whole characters.
        proxy.adjustTextPosition(byCharacterOffset: word.utf16.count)
        for _ in 0..<word.count {
            proxy.deleteBackward()
        }
    }

    private func moveCursorByWord(forward: Bool) {
        if forward {
            let word = (proxy.documentContextAfterInput ?? "").leadingWord
            proxy.adjustTextPosition(byCharacterOffset: word.utf16.count)
        } else {
            let word = (proxy.documentContextBeforeInput ?? "").trailingWord
            proxy.adjustTextPosition(byCharacterOffset: -word.utf16.count)
        }
    }

    private var hasSelection: Bool {
        !(proxy.selectedText ?? "").isEmpty
    }

    // MARK: - Clipboard

    private func copySelection(cut: Bool) {
        guard hasFullAccess else {
            showToast("Turn on Allow Full Access to use the clipboard")
            return
        }
        guard let selected = proxy.selectedText, !selected.isEmpty else {
            showToast("Select some text first")
            return
        }
        UIPasteboard.general.string = selected
        clipboard.add(selected)
        if cut {
            proxy.deleteBackward()
        }
        showToast(cut ? "Cut" : "Copied")
    }

    private func paste() {
        guard hasFullAccess else {
            showToast("Turn on Allow Full Access to use the clipboard")
            return
        }
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            showToast("Clipboard is empty")
            return
        }
        proxy.insertText(text)
        clipboard.add(text)
    }

    private func showToast(_ message: String) {
        state.toast = message
        toastDismissal?.cancel()
        let dismissal = DispatchWorkItem { [weak self] in self?.state.toast = nil }
        toastDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: dismissal)
    }
}

final class KeyboardState: ObservableObject {
    @Published var showsGlobeKey = true
    @Published var hasFullAccess = false
    @Published var isShifted = false
    @Published var mode = KeyboardMode.letters
    @Published var pendingAccent: Accent?
    @Published var showsClipboard = false
    @Published var toast: String?
}

private extension String {
    /// The word just before the end, including any whitespace after it: "see you  " -> "you  ".
    var trailingWord: Substring {
        var start = endIndex
        while start > startIndex, self[index(before: start)].isWhitespace {
            start = index(before: start)
        }
        while start > startIndex, !self[index(before: start)].isWhitespace {
            start = index(before: start)
        }
        return self[start...]
    }

    /// The word at the start, including any whitespace before it: "  see you" -> "  see".
    var leadingWord: Substring {
        var end = startIndex
        while end < endIndex, self[end].isWhitespace {
            end = index(after: end)
        }
        while end < endIndex, !self[end].isWhitespace {
            end = index(after: end)
        }
        return self[..<end]
    }
}
