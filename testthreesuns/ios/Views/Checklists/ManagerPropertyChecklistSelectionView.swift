import SwiftUI
import Supabase
import PostgREST

struct ManagerPropertyChecklistSelectionView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedProperty: Property?
    @State private var checklists: [Checklist] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.properties.isEmpty {
                    Text("No properties available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(viewModel.properties) { property in
                        Button(action: {
                            selectedProperty = property
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(property.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(property.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                // Show badge with count of pending checklists (only inspection, supplies, maintenance)
                                let pendingCount = checklists.filter { 
                                    $0.propertyId == property.id && 
                                    !$0.isCompleted &&
                                    ($0.checklistType == .inspection || $0.checklistType == .supplies || $0.checklistType == .maintenance)
                                }.count
                                if pendingCount > 0 {
                                    Text("\(pendingCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.red)
                                        .clipShape(Circle())
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
            .sheet(item: $selectedProperty) { property in
                ManagerChecklistTypesView(
                    property: property, 
                    checklists: checklists.filter { $0.propertyId == property.id },
                    onChecklistCompleted: {
                        // Refresh checklists after completion
                        Task {
                            await loadAllChecklists()
                            await viewModel.loadData()
                        }
                    }
                )
                .interactiveDismissDisabled(true)
            }
            .task {
                await viewModel.loadData()
                await loadAllChecklists()
            }
        }
    }
    
    private func loadAllChecklists() async {
        isLoading = true
        do {
            // Load inspection, supplies, and maintenance checklists
            let response: [Checklist] = try await SupabaseService.shared.supabase
                .from("checklists")
                .select()
                .in("checklist_type", values: ["inspection", "supplies", "maintenance"])
                .execute()
                .value
            
            await MainActor.run {
                checklists = response
                isLoading = false
            }
        } catch {
            print("Error loading checklists: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ManagerChecklistTypesView: View {
    let property: Property
    let checklists: [Checklist]
    let onChecklistCompleted: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var inspectionChecklists: [Checklist] {
        checklists.filter { $0.checklistType == .inspection && !$0.isCompleted }
    }
    
    var suppliesChecklists: [Checklist] {
        checklists.filter { $0.checklistType == .supplies && !$0.isCompleted }
    }
    
    var maintenanceChecklists: [Checklist] {
        checklists.filter { $0.checklistType == .maintenance && !$0.isCompleted }
    }
    
    var inspectionChecklist: Checklist? {
        inspectionChecklists.first
    }
    
    var suppliesChecklist: Checklist? {
        suppliesChecklists.first
    }
    
    var maintenanceChecklist: Checklist? {
        maintenanceChecklists.first
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Checklists for \(property.name)") {
                    // Inspection Checklist
                    NavigationLink(destination: {
                        if let checklist = inspectionChecklist {
                            InspectionChecklistView(checklist: checklist, onCompleted: onChecklistCompleted)
                        } else {
                            VStack(spacing: 8) {
                                Text("Inspection checklist will be available to complete after a checkout")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Text("Once a guest checks out, the inspection checklist will appear here.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.brandPrimary)
                            Text("Inspection")
                            Spacer()
                            if !inspectionChecklists.isEmpty {
                                if inspectionChecklists.count > 1 {
                                    Text("\(inspectionChecklists.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    // Supplies Checklist
                    NavigationLink(destination: {
                        if let checklist = suppliesChecklist {
                            SuppliesChecklistView(checklist: checklist, onCompleted: onChecklistCompleted)
                        } else {
                            VStack(spacing: 8) {
                                Text("Supplies checklist will be available to complete after a checkout")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Text("Once a guest checks out, the supplies checklist will appear here.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }) {
                        HStack {
                            Image(systemName: "bag")
                                .foregroundColor(.brandPrimary)
                            Text("Supplies")
                            Spacer()
                            if !suppliesChecklists.isEmpty {
                                if suppliesChecklists.count > 1 {
                                    Text("\(suppliesChecklists.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    // Maintenance Checklist
                    NavigationLink(destination: {
                        if let checklist = maintenanceChecklist {
                            MaintenanceChecklistView(checklist: checklist, onCompleted: onChecklistCompleted)
                        } else {
                            VStack(spacing: 8) {
                                Text("Maintenance checklist will be available to complete after a checkout")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Text("Once a guest checks out, the maintenance checklist will appear here.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.brandPrimary)
                            Text("Maintenance")
                            Spacer()
                            if !maintenanceChecklists.isEmpty {
                                if maintenanceChecklists.count > 1 {
                                    Text("\(maintenanceChecklists.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(property.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
}
