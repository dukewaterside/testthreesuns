import SwiftUI
import Supabase
import Functions

struct ManagerChecklistView: View {
    let checklist: Checklist
    @Environment(\.dismiss) var dismiss
    @State private var items: [String: Bool] = [:]
    @State private var initialItems: [String: Bool] = [:]
    @State private var propertyStatus: Checklist.PropertyStatus = .ready
    @State private var initialPropertyStatus: Checklist.PropertyStatus = .ready
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showCancelConfirmation = false
    
    var allSelected: Bool {
        !items.isEmpty && items.values.allSatisfy { $0 }
    }
    
    private var hasUnsavedChanges: Bool {
        items != initialItems || propertyStatus != initialPropertyStatus
    }
    
    var body: some View {
        Form {
            Section {
                Button(action: {
                    let newValue = !allSelected
                    items = Dictionary(uniqueKeysWithValues: items.keys.map { ($0, newValue) })
                }) {
                    HStack {
                        Text(allSelected ? "Deselect All" : "Select All")
                            .foregroundColor(.brandPrimary)
                        Spacer()
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.brandPrimary)
                    }
                }
            }
            
            Section("Checklist Items") {
                ForEach(Array(items.keys.sorted()), id: \.self) { key in
                    Toggle(key, isOn: Binding(
                        get: { items[key] ?? false },
                        set: { items[key] = $0 }
                    ))
                }
            }
            
            Section("Property Status") {
                Picker("Final Status", selection: $propertyStatus) {
                    Text("Ready for Use").tag(Checklist.PropertyStatus.ready)
                    Text("Issues Found").tag(Checklist.PropertyStatus.issuesFound)
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
        .navigationTitle("Manager Checklist")
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
            Text("Manager checklist has been submitted successfully.")
        }
        .alert("Discard changes?", isPresented: $showCancelConfirmation) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You have checklist items marked off or status changes. Are you sure you want to discard your changes?")
        }
    }
    
    private func loadItems() {
        // checklist.items is [String: AnyCodable], convert to [String: Bool]
        let mapped = checklist.items.mapValues { codable in
            if let bool = codable.value as? Bool {
                return bool
            }
            return false
        }
        items = mapped
        initialItems = mapped
        initialPropertyStatus = propertyStatus
    }
    
    private func submitChecklist() {
        isSubmitting = true
        
        Task {
            do {
                guard let _ = try? await SupabaseService.shared.supabase.auth.session else {
                    isSubmitting = false
                    return
                }
                
                let bodyDict: [String: AnyCodable] = [
                    "checklist_id": AnyCodable(checklist.id.uuidString),
                    "items": AnyCodable(items),
                    "property_status": AnyCodable(propertyStatus.rawValue)
                ]
                
                let _ = try await SupabaseService.shared.supabase.functions
                    .invoke("complete-manager-checklist", options: FunctionInvokeOptions(body: bodyDict))
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                print("Error submitting checklist: \(error)")
            }
            
            isSubmitting = false
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
