//
//  SavedConversationsView.swift
//  SpeechRecognitionApp
//
//  Created by Qaim's Macbook  on 31/05/2025.

import SwiftUI
import SwiftData

struct SavedConversationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpeechModel.createdAt, order: .reverse) private var speeches: [SpeechModel]
    @State private var searchText = ""
    
    var filteredSpeeches: [SpeechModel] {
        if searchText.isEmpty {
            return speeches
        } else {
            return speeches.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredSpeeches) { speech in
                NavigationLink {
                    ConversationDetailView(speech: speech)
                } label: {
                    VStack(alignment: .leading) {
                        Text(speech.text.prefix(60) + (speech.text.count > 60 ? "..." : ""))
                            .lineLimit(1)
                        Text(speech.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Saved Conversations")
        .toolbar {
            EditButton()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(speeches[index])
            }
        }
    }
}

#Preview {
    SavedConversationsView()
}

struct ConversationDetailView: View {
    let speech: SpeechModel
    
    var body: some View {
        ScrollView {
            Text(speech.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Conversation Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
