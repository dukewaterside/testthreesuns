import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    
    private var client: SupabaseClient?
    
    private init() {}
    
    func configure(url: URL, key: String) {
        // Create client with basic configuration
        // The emitLocalSessionAsInitialSession warning is informational and won't break production
        // It will be the default behavior in future SDK versions
        // For now, we'll use the basic configuration to ensure it builds and runs
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
    
    var supabase: SupabaseClient {
        guard let client = client else {
            fatalError("Supabase client not configured. Call configure() first.")
        }
        return client
    }
}
