//
//  SpeechRecognizer.swift
//  SpeechRecognization
//
//  Created by Qaim's Macbook  on 28/05/2025.

import Foundation
import Speech
import AVFoundation
import SwiftUI
import SwiftData

final class SpeechRecognizer: ObservableObject {
    
    enum RecognizerError: Error {  // Changed to uppercase for enum name convention
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord  // Fixed typo in case name
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer:
                return "Can't initialize Speech Recognizer"
            case .notAuthorizedToRecognize:
                return "Not Authorized to Recognize Speech"
            case .notPermittedToRecord:  // Fixed to match case name
                return "Not Permitted to Record Audio"
            case .recognizerIsUnavailable:
                return "Recognizer is Unavailable"
            }
        }
    }
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false  // Added to track recording state
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    
    init() {
        recognizer = SFSpeechRecognizer()
        Task(priority: .background) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                recognizeError(error)  // Fixed method name typo
            }
        }
    }
    
    func startRecording(modelContext: ModelContext) throws {
        guard !isRecording else { return }  // Prevent multiple recordings
        
        reset()
        audioEngine = AVAudioEngine()
        request = SFSpeechAudioBufferRecognitionRequest()
        
        guard let audioEngine = audioEngine, let request = request else {
            throw RecognizerError.nilRecognizer
        }
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw RecognizerError.recognizerIsUnavailable
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true  // Update recording state
        
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let newTranscript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = newTranscript
                    let speech = SpeechModel(text: newTranscript, createdAt: Date())
                    modelContext.insert(speech)
                    do {
                        try modelContext.save()
                    } catch {
                        print("Failed to save speech: \(error.localizedDescription)")
                    }
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }  // Only stop if actually recording
        
        task?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        
        isRecording = false  // Update recording state
        reset()
    }
    
    private func recognizeError(_ error: Error) {  // Fixed method name typo
        var errorMessage: String
        if let error = error as? RecognizerError {
            errorMessage = error.message
        } else {
            errorMessage = error.localizedDescription
        }
        DispatchQueue.main.async {
            self.transcript = "<<\(errorMessage)>>"
        }
    }
    
    func reset() {
        task = nil
        request = nil
        audioEngine = nil
    }
    
    deinit {
        reset()
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
