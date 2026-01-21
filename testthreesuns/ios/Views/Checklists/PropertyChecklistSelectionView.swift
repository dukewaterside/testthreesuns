import SwiftUI
import Supabase
import PostgREST

struct PropertyChecklistSelectionView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedProperty: Property?
    @State private var checklists: [Checklist] = []
    @State private var isLoading = false
    
    // Properties that have pending checklists (after checkout)
    var propertiesWithPendingChecklists: [Property] {
        let propertyIds = Set(checklists.filter { !$0.isCompleted }.map { $0.propertyId })
        return viewModel.properties.filter { propertyIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if propertiesWithPendingChecklists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Cleaning checklist will be available to complete after a checkout")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("Once a guest checks out, the cleaning checklist will appear here for you to complete.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(propertiesWithPendingChecklists) { property in
                        Button(action: {
                            selectedProperty = property
                            loadChecklist(for: property)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(property.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(property.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if checklists.contains(where: { $0.propertyId == property.id && !$0.isCompleted }) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedProperty) { property in
                Group {
                    if let checklist = checklists.first(where: { $0.propertyId == property.id && !$0.isCompleted }) {
                        CleaningChecklistView(checklist: checklist)
                    } else {
                        // Show empty checklist for this property
                        EmptyCleaningChecklistView(property: property)
                    }
                }
                .interactiveDismissDisabled(true)
            }
            .task {
                await viewModel.loadData()
                await loadAllChecklists()
            }
            .refreshable {
                await viewModel.loadData()
                await loadAllChecklists()
            }
        }
    }
    
    private func loadAllChecklists() async {
        isLoading = true
        do {
            // Load cleaning checklists that are:
            // 1. Pending (not completed)
            // 2. Associated with reservations that have checked out (check_out < NOW())
            let now = Date()
            
            // First, get all pending cleaning checklists
            let allChecklists: [Checklist] = try await SupabaseService.shared.supabase
                .from("checklists")
                .select()
                .eq("checklist_type", value: "cleaning")
                .is("completed_at", value: nil)
                .execute()
                .value
            
            // Then, get reservations for these checklists to filter by checkout
            var validChecklists: [Checklist] = []
            
            for checklist in allChecklists {
                // If checklist has a reservation_id, check if checkout has passed
                if let reservationId = checklist.reservationId {
                    let reservation: Reservation? = try? await SupabaseService.shared.supabase
                        .from("reservations")
                        .select()
                        .eq("id", value: reservationId)
                        .single()
                        .execute()
                        .value
                    
                    // Only include if reservation exists and checkout has passed
                    if let reservation = reservation,
                       reservation.checkOut < now,
                       reservation.status == .confirmed {
                        validChecklists.append(checklist)
                    }
                }
                // If no reservation_id, skip it (orphaned checklist)
            }
            
            await MainActor.run {
                checklists = validChecklists
                isLoading = false
            }
        } catch {
            print("Error loading checklists: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadChecklist(for property: Property) {
        Task {
            await loadAllChecklists()
        }
    }
}

struct EmptyCleaningChecklistView: View {
    let property: Property
    @Environment(\.dismiss) var dismiss
    @State private var items: [String: Bool] = [:]
    @State private var initialItems: [String: Bool] = [:]
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var showCancelConfirmation = false
    
    // Cleaning checklist structure - same as CleaningChecklistView
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
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle(property.displayName)
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
    
    private func loadItems() {
        var allItems: [String: Bool] = [:]
        for section in cleaningSections {
            for item in section.items {
                allItems[item] = false
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
                let session = try await SupabaseService.shared.supabase.auth.session
                let userId = session.user.id
                
                // Create a new checklist entry for this property
                // Note: property_status_after_cleaning is NOT a column - it's only a parameter for the edge function
                // manager_id is required, so we use the cleaner's user ID
                let checklistData: [String: AnyCodable] = [
                    "property_id": AnyCodable(property.id.uuidString),
                    "checklist_type": AnyCodable("cleaning"),
                    "items": AnyCodable(items),
                    "manager_id": AnyCodable(userId.uuidString)
                ]
                
                // First create the checklist
                let createdChecklist: Checklist = try await SupabaseService.shared.supabase
                    .from("checklists")
                    .insert(checklistData)
                    .select()
                    .single()
                    .execute()
                    .value
                
                // Then complete it via the edge function
                let bodyDict: [String: AnyCodable] = [
                    "checklist_id": AnyCodable(createdChecklist.id.uuidString),
                    "items": AnyCodable(items),
                    "property_status_after_cleaning": AnyCodable("ready")
                ]
                
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
