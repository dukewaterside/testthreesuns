import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationService = NotificationService()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let profile = authViewModel.userProfile {
                        LabeledContent("Name", value: profile.fullName)
                        LabeledContent("Role", value: profile.role?.displayName ?? "Pending")
                    }
                }
                
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: .constant(true))
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
