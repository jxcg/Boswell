import AVFoundation
import FoundationModels
import Observation
import Speech

@Generable
struct DeviceCheckReply {
    var name: String
    var species: String
}

/// A developer probe, not the recording or clinical-note pipeline.
@MainActor
@Observable
final class DeviceCheckModel {
    private(set) var speechStatus = "Not checked yet."
    private(set) var aiStatus = "Not checked yet."
    private(set) var speechResult = "No audio test run yet."
    private(set) var aiResult = "No AI test run yet."
    private(set) var isBusy = false
    private(set) var speechInstalled = false
    private(set) var aiAvailable = false
    private(set) var speechLocale: Locale?

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await checkAvailability()
    }

    private func checkAvailability() async {
        speechInstalled = false
        speechLocale = nil
        if !SpeechTranscriber.isAvailable {
            speechStatus = "This device cannot use Apple's on-device speech transcriber. Try a supported physical iPhone."
        } else if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB")) {
            // Apple's equivalent-locale lookup can fall back to another region.
            // Do not silently call a different English model British English.
            if locale.language.region?.identifier == "GB" {
                speechLocale = locale
                speechInstalled = await AssetInventory.status(forModules: [transcriber(locale)]) == .installed
                speechStatus = speechInstalled
                    ? "British-English speech files are installed. Run the audio test to check transcription."
                    : "British English is supported. Download its speech files before testing."
            } else {
                speechStatus = "British English is unavailable. Apple offered \(locale.identifier) instead; this probe will not silently switch regions."
            }
        } else {
            speechStatus = "British English is not supported on this device."
        }

        aiAvailable = false
        switch SystemLanguageModel.default.availability {
        case .available:
            aiAvailable = true
            aiStatus = "Apple's on-device AI is ready. Context limit: \(SystemLanguageModel.default.contextSize) tokens. Run the fictional test below."
        case .unavailable(.deviceNotEligible):
            aiStatus = "This device does not support Apple Intelligence. Use a compatible physical iPhone."
        case .unavailable(.appleIntelligenceNotEnabled):
            aiStatus = "Turn on Apple Intelligence in Settings, then check again."
        case .unavailable(.modelNotReady):
            aiStatus = "Apple's AI model is not ready. Let its download finish in Settings, then check again."
        case .unavailable:
            aiStatus = "Apple's on-device AI is unavailable for another system reason. Check Settings and try again."
        }
    }

    func downloadSpeechFiles() async {
        guard !isBusy, let locale = speechLocale else { return }
        isBusy = true
        defer { isBusy = false }
        speechStatus = "Downloading British-English speech files…"
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber(locale)]) {
                try await request.downloadAndInstall()
            }
            await checkAvailability()
        } catch {
            speechInstalled = false
            speechStatus = "Speech download failed: \(error.localizedDescription). Check your connection and try again."
        }
    }

    func testAI() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await checkAvailability()
        guard aiAvailable else {
            aiResult = "Test not run. Resolve the AI availability message above first."
            return
        }
        aiResult = "Testing structured output on the phone…"
        let started = Date()
        do {
            let model = SystemLanguageModel.default
            let prompt = Prompt {
                "Fictional test: Pip is a cat. Return the pet's name and species exactly as stated."
            }
            let tokens = try await model.tokenCount(for: prompt)
            let session = LanguageModelSession(model: model, instructions: "Extract only the facts in the fictional text. Do not invent details.")
            let response = try await session.respond(
                to: prompt,
                generating: DeviceCheckReply.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(samplingMode: .greedy)
            )
            let reply = response.content
            let matches = reply.name == "Pip" && reply.species == "cat"
            aiResult = "\(matches ? "Passed" : "Needs investigation"): name = \(reply.name), species = \(reply.species). \(tokens) prompt tokens; \(elapsed(since: started)) seconds. This is not a clinical accuracy test."
        } catch {
            aiResult = "AI test failed: \(error.localizedDescription). No cloud fallback was used."
        }
    }

    func testAudio(at url: URL) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await checkAvailability()
        guard speechInstalled, let locale = speechLocale else {
            speechResult = "Test not run. Install the British-English speech files first."
            return
        }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        speechResult = "Transcribing the selected fictional clip on this device…"
        let started = Date()
        do {
            let audio = try AVAudioFile(forReading: url)
            let duration = Double(audio.length) / audio.processingFormat.sampleRate
            guard duration > 0, duration <= 60 else {
                speechResult = "Choose a non-empty fictional recording no longer than 60 seconds."
                return
            }
            let module = transcriber(locale)
            let analyzer = SpeechAnalyzer(modules: [module])
            let results = Task { @MainActor in
                var text = ""
                var timedRuns = 0
                var confidenceRuns = 0
                for try await result in module.results where result.isFinal {
                    text += String(result.text.characters) + " "
                    for run in result.text.runs {
                        if run.audioTimeRange != nil { timedRuns += 1 }
                        if run.transcriptionConfidence != nil { confidenceRuns += 1 }
                    }
                }
                return (text.trimmingCharacters(in: .whitespacesAndNewlines), timedRuns, confidenceRuns)
            }
            do {
                try await analyzer.start(inputAudioFile: audio, finishAfterFile: true)
                let (text, timedRuns, confidenceRuns) = try await results.value
                if text.isEmpty {
                    speechResult = "No speech was returned. Try a clear British-English fictional clip."
                } else {
                    speechResult = "\(text)\n\n\(timedRuns) timed text runs; \(confidenceRuns) text runs with confidence. \(elapsed(since: started)) seconds. Compare these words with the clip; text runs are not necessarily individual words."
                }
            } catch {
                results.cancel()
                await analyzer.cancelAndFinishNow()
                throw error
            }
        } catch {
            speechResult = "Speech test failed: \(error.localizedDescription). The app did not save a copy of the clip."
        }
    }

    func audioSelectionFailed(_ error: Error) {
        speechResult = "Could not open the selected clip: \(error.localizedDescription)"
    }

    private func transcriber(_ locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )
    }

    private func elapsed(since start: Date) -> String {
        String(format: "%.1f", Date().timeIntervalSince(start))
    }
}
