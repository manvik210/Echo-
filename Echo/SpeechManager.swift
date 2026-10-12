import Foundation
import Speech
import AVFoundation

final class SpeechManager: ObservableObject {
    @Published var transcript = ""
    @Published var listening = false
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let synth = AVSpeechSynthesizer()

    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async { self.begin() }
        }
    }

    private func begin() {
        synth.stopSpeaking(at: .immediate)
        transcript = ""
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true
        }
        request = req
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024,
                         format: input.outputFormat(forBus: 0)) { buf, _ in
            req.append(buf)
        }
        engine.prepare()
        try? engine.start()
        listening = true
        task = recognizer?.recognitionTask(with: req) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true { self.stop() }
            }
        }
    }

    func stop() {
        guard listening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        listening = false
    }

    func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }
}
