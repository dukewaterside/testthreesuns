import SwiftUI
import Supabase
import Functions

struct InspectionChecklistView: View {
    let checklist: Checklist
    var onCompleted: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var items: [String: Bool] = [:]
    @State private var propertyStatus: Checklist.PropertyStatus = .ready
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    
    // Inspection checklist structure
    private let inspectionSections: [InspectionSection] = [
        InspectionSection(title: "HOME IS GUEST READY", items: [
            "HOME IS GUEST READY",
            "KEY CODE SENT"
        ]),
        InspectionSection(title: "Check each item completed", items: [
            "Laundry Dropoff/Pickup",
            "House has needed linens",
            "Check for stains & damage"
        ]),
        InspectionSection(title: "Exterior Front", items: [
            "Grill",
            "Grill Propane",
            "Powerwash Upper Deck",
            "Check Deck Furniture",
            "Pool Check",
            "Pool Temp",
            "Lights",
            "Jets",
            "Pool Deck",
            "Pool Furniture",
            "Pool toys",
            "Front yard debris",
            "Rake driveway"
        ]),
        InspectionSection(title: "Amenities", items: [
            "Bikes (4)",
            "Bike Tires",
            "Bike Helmets (4)",
            "Kayaks (3)",
            "Kayak Paddles (3)",
            "Pack & Play",
            "High Chair",
            "Clothes Iron",
            "Hair Dryer"
        ]),
        InspectionSection(title: "Exterior Back", items: [
            "Ping-pong",
            "Balls & Paddles",
            "Putting Green",
            "Flags",
            "Lights",
            "Putters & Balls",
            "Beach Rake",
            "Beach Kayaks",
            "Boat Lines Secure",
            "Dock Powerwash",
            "Dock Lights"
        ]),
        InspectionSection(title: "1st Floor", items: [
            "Laundry machine check"
        ]),
        InspectionSection(title: "Misc", items: [
            "TV remotes",
            "Shade remotes",
            "WIFI Reset",
            "All windows clean",
            "Key in lockbox",
            "Trash",
            "Windows / doors locked",
            "Supply closet check"
        ])
    ]
    
    var allSelected: Bool {
        !items.isEmpty && items.values.allSatisfy { $0 }
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
            
            ForEach(inspectionSections) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { items[item] ?? false },
                            set: { items[item] = $0 }
                        ))
                    }
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
        .navigationTitle("Inspection Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadItems()
        }
        .alert("Checklist Completed", isPresented: $showSuccessAlert) {
            Button("OK") {
                onCompleted?()
                dismiss()
            }
        } message: {
            Text("Inspection checklist has been submitted successfully.")
        }
    }
    
    private func loadItems() {
        // Initialize all items from all sections
        var allItems: [String: Bool] = [:]
        for section in inspectionSections {
            for item in section.items {
                if let existingValue = checklist.items[item],
                   let bool = existingValue.value as? Bool {
                    allItems[item] = bool
                } else {
                    allItems[item] = false
                }
            }
        }
        items = allItems
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
}

struct InspectionSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
}
