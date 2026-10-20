import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let state = KeyboardState()

    override func viewDidLoad() {
        super.viewDidLoad()

        let keyboardView = KeyboardView(
            state: state,
            onInsert: { [weak self] text in self?.textDocumentProxy.insertText(text) },
            onDelete: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            onMoveCursor: { [weak self] offset in self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset) },
            onNextKeyboard: { [weak self] in self?.advanceToNextInputMode() }
        )

        let host = UIHostingController(rootView: keyboardView)
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
    }
}

final class KeyboardState: ObservableObject {
    @Published var showsGlobeKey = true
    @Published var isShifted = false
}
