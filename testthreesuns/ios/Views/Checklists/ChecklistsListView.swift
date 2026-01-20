import SwiftUI

struct ChecklistsListView: View {
    @StateObject private var viewModel = ChecklistViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var pendingChecklists: [Checklist] {
        viewModel.checklists.filter { !$0.isCompleted }
    }
    
    var completedChecklists: [Checklist] {
        viewModel.checklists.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !pendingChecklists.isEmpty {
                    Section("Pending") {
                        ForEach(pendingChecklists) { checklist in
                            NavigationLink(destination: checklistDetailView(for: checklist)) {
                                ChecklistCard(checklist: checklist)
                            }
                        }
                    }
                }
                
                if !completedChecklists.isEmpty {
                    Section("Completed") {
                        ForEach(completedChecklists) { checklist in
                            NavigationLink(destination: checklistDetailView(for: checklist)) {
                                ChecklistCard(checklist: checklist)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Checklists")
            .refreshable {
                await viewModel.loadChecklists()
            }
            .task {
                await viewModel.loadChecklists()
            }
        }
    }
    
    @ViewBuilder
    private func checklistDetailView(for checklist: Checklist) -> some View {
        switch checklist.checklistType ?? .inspection {
        case .inspection:
            InspectionChecklistView(checklist: checklist)
        case .cleaning:
            if authViewModel.userProfile?.role == .cleaningStaff {
                CleaningChecklistView(checklist: checklist)
            } else {
                Text("No access")
            }
        case .supplies:
            SuppliesChecklistView(checklist: checklist)
        case .maintenance:
            MaintenanceChecklistView(checklist: checklist)
        }
    }
}
