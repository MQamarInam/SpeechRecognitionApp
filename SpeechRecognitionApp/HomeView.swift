import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \SpeechModel.createdAt, order: .reverse) var smodels: [SpeechModel]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddNewView = false
    
    var body: some View {
        NavigationStack {
            Group {
                if smodels.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "waveform",
                        description: Text("Start speaking to add new conversations")
                    )
                } else {
                    List {
                        ForEach(smodels) { sm in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sm.text)
                                    .font(.headline)
                                Text(sm.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Conversations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddNewView = true }) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddNewView) {
                AddNewTodoView()
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(smodels[index])
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save context after deletion: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: SpeechModel.self, inMemory: true)
}
