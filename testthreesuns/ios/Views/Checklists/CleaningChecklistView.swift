import SwiftUI
import Supabase
import Functions

struct CleaningChecklistView: View {
    let checklist: Checklist
    let cleaningSchedule: CleaningSchedule?
    @Environment(\.dismiss) var dismiss
    @State private var items: [String: Bool] = [:]
    @State private var initialItems: [String: Bool] = [:]
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var showCancelConfirmation = false
    
    init(checklist: Checklist, cleaningSchedule: CleaningSchedule? = nil) {
        self.checklist = checklist
        self.cleaningSchedule = cleaningSchedule
    }
    
    // Cleaning checklist structure
    private let cleaningSections: [CleaningSection] = [
        CleaningSection(title: "Ground Floor", items: [
            "Back Bedroom",
            "Front Bedroom",
            "Bathroom",
            "Games Room"
        ]),
        CleaningSection(title: "2nd Floor", items: [
            "Powder Room",
            "Kitchen",
            "Fridge",
            "Freezer",
            "Dishwasher 1",
            "Dishwasher 2",
            "Coffee Maker",
            "Sink",
            "Living Room",
            "Back Patio",
            "Back Wet Bar",
            "Bar Fridge",
            "Front Bed/Bath",
            "Back Bed/Bath"
        ]),
        CleaningSection(title: "3rd Floor", items: [
            "Front Bed/Bath",
            "Back Bed/Bath",
            "Balcony"
        ]),
        CleaningSection(title: "Additional", items: [
            "1 Beach towel - each guest",
            "Welcome drink displayed"
        ])
    ]
    
    private var hasUnsavedChanges: Bool {
        items != initialItems
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Cleaning Checklist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            handleCancel()
                        }
                    }
                }
                .onAppear {
                    loadItems()
                }
                .alert("Checklist Completed", isPresented: $showSuccessAlert) {
                    Button("OK") {
                        dismiss()
                    }
                } message: {
                    Text("The cleaning checklist has been submitted successfully. Property manager and owner have been notified.")
                }
                .alert("Discard changes?", isPresented: $showCancelConfirmation) {
                    Button("Keep Editing", role: .cancel) { }
                    Button("Discard Changes", role: .destructive) {
                        dismiss()
                    }
                } message: {
                    Text("You have checklist items marked off. Are you sure you want to discard your changes?")
                }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        Form {
            ForEach(cleaningSections) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { items[item] ?? false },
                            set: { items[item] = $0 }
                        ))
                    }
                }
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: submitChecklist) {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Complete Checklist")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || checklist.isCompleted)
            }
        }
    }
    
    private func loadItems() {
        // Initialize items from all sections first
        var allItems: [String: Bool] = [:]
        for section in cleaningSections {
            for item in section.items {
                allItems[item] = false
            }
        }
        
        // Then populate from checklist if available
        for (key, codable) in checklist.items {
            if let bool = codable.value as? Bool {
                allItems[key] = bool
            }
        }
        
        items = allItems
        initialItems = allItems
    }
    
    private func submitChecklist() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                // Cleaners always set property status to 'ready' (which maps to 'vacant_ready' in DB)
                var bodyDict: [String: AnyCodable] = [
                    "checklist_id": AnyCodable(checklist.id.uuidString),
                    "items": AnyCodable(items),
                    "property_status_after_cleaning": AnyCodable("ready")  // Always 'ready' for cleaners
                ]
                
                // If this is associated with a cleaning schedule, include it to update completion time
                if let cleaningSchedule = cleaningSchedule {
                    bodyDict["cleaning_schedule_id"] = AnyCodable(cleaningSchedule.id.uuidString)
                }
                
                let _: Void = try await SupabaseService.shared.supabase.functions
                    .invoke("complete-cleaning-checklist", options: FunctionInvokeOptions(body: bodyDict))
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    if error is FunctionsError {
                        errorMessage = "Authentication failed. Please sign out and sign in again."
                    } else {
                        errorMessage = "Failed to submit checklist: \(error.localizedDescription)"
                    }
                    print("Error submitting checklist: \(error)")
                    isSubmitting = false
                }
            }
        }
    }
    
    private func handleCancel() {
        if hasUnsavedChanges {
            showCancelConfirmation = true
        } else {
            dismiss()
        }
    }
}

struct CleaningSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
}
