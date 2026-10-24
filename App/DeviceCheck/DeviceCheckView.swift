import SwiftUI
import UniformTypeIdentifiers

struct DeviceCheckView: View {
    @State private var model = DeviceCheckModel()
    @State private var choosingAudio = false

    var body: some View {
        List {
            Section {
                Text("Check the phone before building the full recording flow. These are developer tests, not a clinical safety check.")
                Text("Fictional data only. No microphone recording or consultation storage is used here.")
                    .foregroundStyle(.secondary)
                Text("System: \(ProcessInfo.processInfo.operatingSystemVersionString)")
                #if targetEnvironment(simulator)
                Text("You are using a simulator. Repeat these checks on a supported physical iPhone; simulator results do not prove phone support.")
                    .font(.headline)
                #endif
                Button("Check again") {
                    Task { await model.refresh() }
                }
                .disabled(model.isBusy)
                if model.isBusy {
                    ProgressView("Working on the phone…")
                }
            }

            Section("1. British-English speech") {
                Text(model.speechStatus)
                if model.speechLocale != nil && !model.speechInstalled {
                    Text("Downloading speech files needs an internet connection and may take time. No audio is uploaded by this app.")
                        .foregroundStyle(.secondary)
                    Button("Download speech files") {
                        Task { await model.downloadSpeechFiles() }
                    }
                    .disabled(model.isBusy)
                }
                Text("Choose a clear fictional clip from Files, up to 60 seconds. Compare the returned words with what was said. If the clip is in iCloud, Files may download it first.")
                    .foregroundStyle(.secondary)
                Button("Choose fictional audio clip") {
                    choosingAudio = true
                }
                .disabled(model.isBusy || !model.speechInstalled)
                Text(model.speechResult)
                    .textSelection(.enabled)
            }

            Section("2. Apple's built-in AI") {
                Text(model.aiStatus)
                Text("The test asks for the name and species in ‘Pip is a cat’. It checks structured output, not medical advice or note accuracy.")
                    .foregroundStyle(.secondary)
                Button("Run fictional AI test") {
                    Task { await model.testAI() }
                }
                .disabled(model.isBusy || !model.aiAvailable)
                Text(model.aiResult)
                    .textSelection(.enabled)
            }

            Section("3. Check without a connection") {
                Text("After the speech and AI files are ready, keep the audio clip on the phone. Turn on Airplane Mode and turn Wi-Fi off, then repeat both tests. Record the phone model, iOS version, results and time taken in the device-check notes. Nothing on this screen is saved by the app.")
            }
        }
        .navigationTitle("Check this iPhone")
        .task { await model.refresh() }
        .fileImporter(isPresented: $choosingAudio, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                Task { await model.testAudio(at: url) }
            case .failure(let error):
                model.audioSelectionFailed(error)
            }
        }
    }
}
