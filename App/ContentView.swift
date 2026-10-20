import SwiftUI

struct ContentView: View {
    @State private var testText = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section("Enable the keyboard") {
                    Text("1. Open Settings › General › Keyboard › Keyboards")
                    Text("2. Tap Add New Keyboard… and choose NineKey")
                    Text("3. In any text field, tap the globe key to switch to it")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
                Section("Try it here") {
                    TextField("Type something…", text: $testText, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("NineKey")
        }
    }
}
