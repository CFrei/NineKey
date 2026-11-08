import SwiftUI
import UIKit

enum HapticStyle: String, Codable, CaseIterable, Identifiable {
    case light, medium, heavy, soft, rigid, tick

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "Light"
        case .medium: "Med"
        case .heavy: "Heavy"
        case .soft: "Soft"
        case .rigid: "Rigid"
        case .tick: "Tick"
        }
    }

    var hasStrength: Bool { self != .tick }
}

struct Haptic: Codable, Equatable {
    var isOn: Bool
    var style: HapticStyle
    var strength: Double
}

/// Tuning values for the two vibrations, stored in the keyboard's own container.
final class HapticSettings: ObservableObject {
    @Published var press: Haptic { didSet { save() } }
    @Published var slide: Haptic { didSet { save() } }

    private struct Stored: Codable {
        var press: Haptic
        var slide: Haptic
    }

    private static let storageKey = "hapticSettings"

    init() {
        let stored = UserDefaults.standard.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        press = stored?.press ?? Haptic(isOn: true, style: .light, strength: 0.7)
        slide = stored?.slide ?? Haptic(isOn: true, style: .rigid, strength: 0.5)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Stored(press: press, slide: slide)) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

/// Plays the key-press and slide vibrations, and knows where every key is so a slide can tell
/// when the finger moves onto a different key. iOS only vibrates for keyboards with Full Access.
final class KeyFeedback {
    let settings: HapticSettings
    var keyFrames: [UUID: CGRect] = [:]

    private var impactGenerators: [HapticStyle: UIImpactFeedbackGenerator] = [:]
    private let selectionGenerator = UISelectionFeedbackGenerator()

    init(settings: HapticSettings) {
        self.settings = settings
    }

    func keyPressed() {
        play(settings.press)
        prepare(settings.slide)
    }

    func enteredKey() {
        play(settings.slide)
        prepare(settings.slide)
    }

    func key(at point: CGPoint) -> UUID? {
        keyFrames.first { $0.value.contains(point) }?.key
    }

    func play(_ haptic: Haptic) {
        guard haptic.isOn else { return }
        if haptic.style == .tick {
            selectionGenerator.selectionChanged()
        } else {
            impactGenerator(for: haptic.style).impactOccurred(intensity: CGFloat(haptic.strength))
        }
    }

    // Wakes the Taptic Engine so the next vibration fires without delay.
    private func prepare(_ haptic: Haptic) {
        guard haptic.isOn else { return }
        if haptic.style == .tick {
            selectionGenerator.prepare()
        } else {
            impactGenerator(for: haptic.style).prepare()
        }
    }

    private func impactGenerator(for style: HapticStyle) -> UIImpactFeedbackGenerator {
        if let generator = impactGenerators[style] {
            return generator
        }
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light, .tick: generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy: generator = UIImpactFeedbackGenerator(style: .heavy)
        case .soft: generator = UIImpactFeedbackGenerator(style: .soft)
        case .rigid: generator = UIImpactFeedbackGenerator(style: .rigid)
        }
        impactGenerators[style] = generator
        return generator
    }
}

private struct KeyFeedbackEnvironmentKey: EnvironmentKey {
    static let defaultValue: KeyFeedback? = nil
}

extension EnvironmentValues {
    var keyFeedback: KeyFeedback? {
        get { self[KeyFeedbackEnvironmentKey.self] }
        set { self[KeyFeedbackEnvironmentKey.self] = newValue }
    }
}

struct HapticsPanel: View {
    @ObservedObject var settings: HapticSettings
    let hasFullAccess: Bool
    let preview: (Haptic) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Vibration").font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if !hasFullAccess {
                Text("Vibration needs Allow Full Access for NineKey (Settings › General › Keyboard › Keyboards › NineKey).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ScrollView {
                VStack(spacing: 8) {
                    HapticEditor(title: "Key press", haptic: $settings.press, preview: preview)
                    HapticEditor(title: "Sliding onto another key", haptic: $settings.slide, preview: preview)
                }
            }
        }
    }
}

private struct HapticEditor: View {
    let title: String
    @Binding var haptic: Haptic
    let preview: (Haptic) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: $haptic.isOn)
                .font(.subheadline.weight(.medium))
            if haptic.isOn {
                Picker("Style", selection: $haptic.style) {
                    ForEach(HapticStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Strength").font(.caption)
                    Slider(value: $haptic.strength, in: 0.1...1, step: 0.05, onEditingChanged: { editing in
                        if !editing { preview(haptic) }
                    })
                    .disabled(!haptic.style.hasStrength)
                    Text(haptic.style.hasStrength ? "\(Int((haptic.strength * 100).rounded()))%" : "–")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.letterKey))
        .onChange(of: haptic.style) { _ in preview(haptic) }
    }
}
