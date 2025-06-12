import Foundation
import Speech
import AVFoundation
import SwiftUI
import SwiftData

final class SpeechRecognizer: ObservableObject {
    
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        case recognitionTaskError(Error?)
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Speech recognizer not available."
            case .notAuthorizedToRecognize: return "Speech recognition not authorized. Please enable it in Settings."
            case .notPermittedToRecord: return "Microphone access not permitted. Please enable it in Settings."
            case .recognizerIsUnavailable: return "Speech recognizer is currently unavailable."
            case .recognitionTaskError(let error):
                return "Recognition error: \(error?.localizedDescription ?? "Unknown error")"
            }
        }
    }
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isSaved: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    private var hasReceivedSpeech: Bool = false
    private var recordingTimer: Timer?
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer()
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            DispatchQueue.main.async {
                self.handleError(RecognizerError.nilRecognizer)
            }
            return
        }
        
        Task(priority: .background) {
            await requestAuthorization()
        }
    }
    
    deinit {
        reset()
    }
    
    // MARK: - Public Methods
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            do {
                try startRecording()
            } catch {
                handleError(error)
            }
        }
    }
    
    func saveTranscript(modelContext: ModelContext) {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "No text to save. Start recording first!")
            return
        }
        
        let newSpeech = SpeechModel(text: transcript, createdAt: Date())
        modelContext.insert(newSpeech)
        do {
            try modelContext.save()
            isSaved = true
            transcript = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isSaved = false
            }
        } catch {
            showAlert(message: "Failed to save: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    private func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume()
            }
        }
        
        let audioGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        DispatchQueue.main.async {
            if SFSpeechRecognizer.authorizationStatus() != .authorized {
                self.handleError(RecognizerError.notAuthorizedToRecognize)
            } else if !audioGranted {
                self.handleError(RecognizerError.notPermittedToRecord)
            }
        }
    }
    
    private func startRecording() throws {
        guard !isRecording else { return }
        reset()
        
        transcript = ""
        hasReceivedSpeech = false
        recordingDuration = 0
        
        // Setup audio session with playAndRecord and mixWithOthers
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Start timer
        startRecordingTimer()
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { throw RecognizerError.recognizerIsUnavailable }
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine else { throw RecognizerError.recognizerIsUnavailable }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                let newTranscript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = newTranscript
                    if !newTranscript.isEmpty {
                        self.hasReceivedSpeech = true
                    }
                }
            }
            
            if let error {
                let nsError = error as NSError
                if nsError.domain == SFSpeechErrorDomain && nsError.code == 1 {
                    print("Recording stopped normally")
                } else {
                    DispatchQueue.main.async {
                        self.handleError(RecognizerError.recognitionTaskError(error))
                    }
                }
                self.stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        stopRecordingTimer()
        recognitionTask?.finish()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Audio session deactivation error: \(error.localizedDescription)")
        }
        
        isRecording = false
        reset()
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func reset() {
        stopRecordingTimer()
        recognitionTask?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            if let error = error as? RecognizerError {
                self.alertMessage = error.message
            } else {
                self.alertMessage = error.localizedDescription
            }
            self.showAlert = true
        }
    }
    
    private func showAlert(message: String) {
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showAlert = true
        }
    }
}
