import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class ChecklistViewModel: ObservableObject {
    @Published var checklists: [Checklist] = []
    @Published var isLoading = false
    
    private let supabase = SupabaseService.shared.supabase
    private var userRole: String = ""
    
    func loadChecklists() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            // Get user role - query as dictionary first
            let profileResponse: [String: AnyCodable]? = try? await supabase
                .from("profiles")
                .select("role")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            let role = (profileResponse?["role"]?.value as? String) ?? ""
            
            // For cleaning staff, load cleaning checklists
            // For property managers, load inspection, supplies, and maintenance checklists
            var response: [Checklist] = []
            
            if role == "cleaning_staff" {
                response = try await supabase
                    .from("checklists")
                    .select()
                    .eq("checklist_type", value: "cleaning")
                    .is("completed_at", value: nil)
                    .execute()
                    .value
            } else if role == "property_manager" {
                response = try await supabase
                    .from("checklists")
                    .select()
                    .in("checklist_type", values: ["inspection", "supplies", "maintenance"])
                    .is("completed_at", value: nil)
                    .execute()
                    .value
            } else {
                // Owner or other - load all
                response = try await supabase
                    .from("checklists")
                    .select()
                    .is("completed_at", value: nil)
                    .execute()
                    .value
            }
            
            checklists = response
            userRole = role
        } catch {
            print("Error loading checklists: \(error)")
            // Try loading all checklists as fallback
            do {
                let allChecklists: [Checklist] = try await supabase
                    .from("checklists")
                    .select()
                    .is("completed_at", value: nil)
                    .execute()
                    .value
                checklists = allChecklists
            } catch {
                print("Error loading all checklists: \(error)")
            }
        }
        isLoading = false
    }
}
