import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.userProfile?.isVerified == true {
                    MainTabView()
                } else {
                    ApprovalPendingView()
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            authViewModel.checkAuthStatus()
        }
    }
}
