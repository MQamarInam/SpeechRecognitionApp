//
//  SpeechRecognitionAppApp.swift
//  SpeechRecognitionApp
//
//  Created by Qaim's Macbook  on 30/05/2025.
//

import SwiftUI
import SwiftData

@main
struct SpeechRecognitionAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SpeechModel.self)
    }
}
