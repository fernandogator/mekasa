import AVFoundation
import Foundation
import Speech

/// On-device speech recognition for voice item entry (REQ-007).
/// Spec version: 1.0
@MainActor
final class VoiceSpeechRecognizer: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case listening
        case unavailable(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var partialTranscript: String = ""

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var isAvailable: Bool {
        speechRecognizer?.isAvailable == true
    }

    func toggleListening(onFinal: @escaping (String) -> Void) {
        switch status {
        case .listening:
            let text = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            stop()
            if !text.isEmpty {
                onFinal(text)
            }
        case .idle, .unavailable:
            start(onFinal: onFinal)
        case .requestingPermission:
            break
        }
    }

    func start(onFinal: @escaping (String) -> Void) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            status = .unavailable("Speech recognition isn’t available on this device.")
            return
        }

        status = .requestingPermission
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor in
                guard let self else { return }
                switch auth {
                case .authorized:
                    self.beginSession(recognizer: speechRecognizer, onFinal: onFinal)
                case .denied, .restricted:
                    self.status = .unavailable("Allow speech recognition in Settings to dictate items.")
                case .notDetermined:
                    self.status = .idle
                @unknown default:
                    self.status = .idle
                }
            }
        }
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if case .listening = status {
            status = .idle
        }
    }

    private func beginSession(recognizer: SFSpeechRecognizer, onFinal: @escaping (String) -> Void) {
        stop()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            status = .unavailable("Couldn’t access the microphone.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            status = .unavailable("Couldn’t start listening.")
            stop()
            return
        }

        partialTranscript = ""
        status = .listening

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        let text = result.bestTranscription.formattedString
                        self.stop()
                        onFinal(text)
                    }
                }
                if error != nil, self.status == .listening {
                    let text = self.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.stop()
                    if !text.isEmpty {
                        onFinal(text)
                    }
                }
            }
        }
    }
}
