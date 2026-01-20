import SwiftUI

struct ApprovalPendingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.brandPrimary)
            
            Text("Account Pending Approval")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Text("Your account is waiting for administrator approval.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("You will receive an email notification once your account has been approved, and then you can sign in immediately.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
                Button("Check Status") {
                    Task {
                        await authViewModel.loadUserProfile()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 20)
                
                Button("Sign Out") {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            // Refresh profile when view appears to check if approval happened
            Task {
                await authViewModel.loadUserProfile()
            }
        }
        .task {
            // Also refresh periodically while on this screen
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await authViewModel.loadUserProfile()
            }
        }
    }
}
