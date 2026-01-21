import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                switch authViewModel.userProfile?.role {
                case .owner:
                    OwnerDashboardView()
                case .propertyManager:
                    ManagerDashboardView()
                case .cleaningStaff:
                    CleanerDashboardView()
                case .none:
                    Text("Loading...")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
