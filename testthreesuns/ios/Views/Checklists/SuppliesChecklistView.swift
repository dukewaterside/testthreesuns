import SwiftUI
import Supabase
import Functions

struct SuppliesChecklistView: View {
    let checklist: Checklist
    var onCompleted: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var items: [String: Bool] = [:]
    @State private var initialItems: [String: Bool] = [:]
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showReorderReview = false
    @State private var showCancelConfirmation = false
    
    // Supplies checklist structure
    private let suppliesSections: [SuppliesSection] = [
        SuppliesSection(title: "Bathrooms", items: [
            "Indiv Soaps",
            "Hand Soap",
            "Indiv Conditioner",
            "Indiv Body Wash",
            "Hand towels",
            "Bath Towels",
            "Bath Mats",
            "Facecloth"
        ]),
        SuppliesSection(title: "Laundry", items: [
            "Laundry Pods",
            "Laundry Bleach"
        ]),
        SuppliesSection(title: "Kitchen", items: [
            "Kitchen Pods",
            "Dish Soap",
            "Sponge",
            "Dish Towel",
            "Glass Cleaner",
            "Trash Bags",
            "Coffee",
            "Welcome drink supplies",
            "Juice",
            "Vodka"
        ]),
        SuppliesSection(title: "Bedrooms", items: [
            "3 sets per bed",
            "Fitted Sheets",
            "Top Sheets",
            "Blankets",
            "Pillow Cases",
            "Throw Pillows"
        ]),
        SuppliesSection(title: "Misc", items: [
            "Light bulbs",
            "Grill cleaner"
        ])
    ]
    
    var checkedItems: [String] {
        items.filter { $0.value }.map { $0.key }
    }
    
    private var checkedItemsSorted: [String] {
        checkedItems.sorted()
    }
    
    private var hasUnsavedChanges: Bool {
        items != initialItems
    }
    
    var body: some View {
        Form {
            Section {
                Text("Check items that need to be ordered. Submitting will notify the property manager and owner.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(suppliesSections) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { items[item] ?? false },
                            set: { items[item] = $0 }
                        ))
                    }
                }
            }
            
            Section("Reorder Review") {
                Button {
                    showReorderReview = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.brandPrimary)
                        Text("Review items to reorder")
                        Spacer()
                        Text("\(checkedItems.count)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption.weight(.semibold))
                    }
                }
                .disabled(checkedItems.isEmpty)
                
                if checkedItems.isEmpty {
                    Text("No items selected yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(checkedItemsSorted.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
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
                        Text("Submit Supplies Order")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || checklist.isCompleted)
            }
        }
        .navigationTitle("Supplies Checklist")
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
        .safeAreaInset(edge: .bottom) {
            if !checkedItems.isEmpty && !checklist.isCompleted {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(checkedItems.count) item\(checkedItems.count == 1 ? "" : "s") to reorder")
                            .font(.subheadline.weight(.semibold))
                        Text(checkedItemsSorted.prefix(2).joined(separator: ", ") + (checkedItems.count > 2 ? "…" : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button("Review") {
                        showReorderReview = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showReorderReview) {
            NavigationStack {
                List {
                    if checkedItemsSorted.isEmpty {
                        ContentUnavailableView("No items selected", systemImage: "cart", description: Text("Check items in the checklist to add them here."))
                    } else {
                        Section("Items to reorder") {
                            ForEach(checkedItemsSorted, id: \.self) { item in
                                Toggle(item, isOn: Binding(
                                    get: { items[item] ?? false },
                                    set: { items[item] = $0 }
                                ))
                            }
                        }
                    }
                }
                .navigationTitle("Reorder Review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { showReorderReview = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { clearAllSelections() }
                            .disabled(checkedItemsSorted.isEmpty)
                    }
                }
            }
        }
        .alert("Checklist Submitted", isPresented: $showSuccessAlert) {
            Button("OK") {
                onCompleted?()
                dismiss()
            }
        } message: {
            if !checkedItems.isEmpty {
                Text("Supplies order submitted. Property manager and owner have been notified.")
            } else {
                Text("Supplies checklist submitted successfully.")
            }
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
    
    private func loadItems() {
        // Always initialize all items as false (unchecked)
        // Don't load from database as it might have wrong items from other checklist types
        var allItems: [String: Bool] = [:]
        for section in suppliesSections {
            for item in section.items {
                allItems[item] = false
            }
        }
        items = allItems
        initialItems = allItems
    }
    
    private func submitChecklist() {
        isSubmitting = true
        
        Task {
            do {
                guard let session = try? await SupabaseService.shared.supabase.auth.session else {
                    isSubmitting = false
                    return
                }
                let userId = session.user.id
                
                let bodyDict: [String: AnyCodable] = [
                    "checklist_id": AnyCodable(checklist.id.uuidString),
                    "completed_by_user_id": AnyCodable(userId.uuidString),
                    "items": AnyCodable(items),
                    "items_to_order": AnyCodable(checkedItems)
                ]
                
                let _ = try await SupabaseService.shared.supabase.functions
                    .invoke("complete-supplies-checklist", options: FunctionInvokeOptions(body: bodyDict))
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                print("Error submitting supplies checklist: \(error)")
            }
            
            isSubmitting = false
        }
    }
    
    private func clearAllSelections() {
        for key in items.keys {
            items[key] = false
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

struct SuppliesSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
}
