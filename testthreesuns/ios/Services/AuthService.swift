import Foundation
import Supabase
import Functions

class AuthService {
    private let supabase = SupabaseService.shared.supabase
    
    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, requestedRole: String) async throws {
        // Sign up with email confirmation enabled
        // Note: Supabase will send confirmation email automatically if enabled in dashboard
        // We don't pass data here since we call the edge function separately to create the profile
        let response = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        
        // response.user is non-optional, so we can use it directly
        let user = response.user
        
        // Call create-profile edge function to create profile and trigger admin approval email
        let codableBody: [String: AnyCodable] = [
            "user_id": AnyCodable(user.id.uuidString),
            "first_name": AnyCodable(firstName),
            "last_name": AnyCodable(lastName),
            "requested_role": AnyCodable(requestedRole)
        ]
        let _ = try await supabase.functions.invoke("create-profile", options: FunctionInvokeOptions(body: codableBody))
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func getCurrentUser() async throws -> UUID? {
        let session = try await supabase.auth.session
        return session.user.id
    }
    
    enum AuthError: Error {
        case signUpFailed
        case userNotFound
    }
}
