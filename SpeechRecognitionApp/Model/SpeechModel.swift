//
//  SpeechModel.swift
//  SpeechRecognization
//
//  Created by Qaim's Macbook  on 28/05/2025.
//

import Foundation
import SwiftData

@Model
final class SpeechModel {
    var text: String
    var createdAt: Date
    
    init(text: String, createdAt: Date) {
        self.text = text
        self.createdAt = createdAt
    }
}
