import SwiftUI

/// Text copied, cut or pasted through NineKey, newest first. Stored in the keyboard's own container.
final class ClipboardHistory: ObservableObject {
    @Published private(set) var items: [String]

    private let defaults = UserDefaults.standard
    private let storageKey = "clipboardHistory"
    private let limit = 20

    init() {
        items = defaults.stringArray(forKey: storageKey) ?? []
    }

    func add(_ text: String) {
        guard !text.isEmpty else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        save()
    }

    func remove(_ text: String) {
        items.removeAll { $0 == text }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        defaults.set(items, forKey: storageKey)
    }
}

struct ClipboardPanel: View {
    let items: [String]
    let hasFullAccess: Bool
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Clipboard").font(.headline)
                Spacer()
                if hasFullAccess && !items.isEmpty {
                    Button("Clear", action: onClear)
                        .padding(.trailing, 8)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if !hasFullAccess {
                message("Turn on Allow Full Access for NineKey in Settings › General › Keyboard › Keyboards › NineKey to use the clipboard.")
            } else if items.isEmpty {
                message("Text you copy, cut or paste with NineKey will show up here.")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(items, id: \.self) { item in
                            HStack(spacing: 8) {
                                Text(item)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button { onRemove(item) } label: {
                                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.letterKey))
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(item) }
                        }
                    }
                }
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
    }
}
