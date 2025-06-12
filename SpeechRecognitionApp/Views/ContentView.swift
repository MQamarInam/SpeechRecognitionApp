import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @Environment(\.modelContext) private var modelContext
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ScrollView {
                    Text(speechRecognizer.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .frame(maxHeight: 200)
                
                if speechRecognizer.isRecording {
                    VStack {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0.8 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                            .onAppear { isAnimating = true }
                            .onDisappear { isAnimating = false }
                        
                        HStack(spacing: 3) {
                            ForEach(0..<5) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .frame(width: 4, height: CGFloat.random(in: 5...20))
                                    .foregroundColor(.blue)
                            }
                        }
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                        
                        // Timer
                        Text(formattedTime(time: speechRecognizer.recordingDuration))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .padding(.top, 5)
                    }
                    .padding(.vertical, 10)
                }
                
                // Recording Button
                Button(action: {
                    speechRecognizer.toggleRecording()
                }) {
                    Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                }
                
                // Save Button
                if !speechRecognizer.transcript.isEmpty && !speechRecognizer.isRecording {
                    Button(action: {
                        speechRecognizer.saveTranscript(modelContext: modelContext)
                    }) {
                        HStack {
                            Image(systemName: speechRecognizer.isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                            Text(speechRecognizer.isSaved ? "Saved!" : "Save Conversation")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(speechRecognizer.isSaved ? Color.green : Color.blue)
                        .cornerRadius(10)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
            .animation(.default, value: speechRecognizer.isSaved)
            .navigationTitle("Speech to Text")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SavedConversationsView()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .alert("Error", isPresented: $speechRecognizer.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(speechRecognizer.alertMessage)
            }
        }
    }
    
    private func formattedTime(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SpeechModel.self, inMemory: true)
}
