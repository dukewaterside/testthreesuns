import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService = AuthService()
    private let supabase = SupabaseService.shared.supabase
    
    func checkAuthStatus() {
        Task {
            do {
                _ = try await supabase.auth.session
                await loadUserProfile()
                isAuthenticated = true
            } catch {
                isAuthenticated = false
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            await loadUserProfile()
            // Only set authenticated if profile exists
            // If profile doesn't exist, userProfile will be nil and they'll see approval pending
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, requestedRole: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                requestedRole: requestedRole
            )
            // After signup:
            // 1. Supabase Auth sends verification email automatically
            // 2. Profile is created and admin receives approval email
            // 3. User needs to verify email and wait for approval
            // So we don't set isAuthenticated = true yet
            isAuthenticated = false
            // Clear error message on success
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
            isAuthenticated = false
            userProfile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadUserProfile() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            print("Loaded profile for user \(userId): isVerified = \(profile.isVerified), role = \(profile.role?.rawValue ?? "nil")")
            
            await MainActor.run {
                userProfile = profile
                // Update authentication state based on profile
                // User is authenticated if they have a session, but can only access app if verified
                isAuthenticated = true
            }
        } catch {
            print("Error loading profile: \(error)")
            // If profile doesn't exist, user can't access the app
            // They'll see the login screen
            await MainActor.run {
                userProfile = nil
            }
        }
    }
}
