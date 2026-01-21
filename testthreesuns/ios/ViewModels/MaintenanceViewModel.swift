import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class MaintenanceViewModel: ObservableObject {
    @Published var reports: [MaintenanceReport] = []
    @Published var properties: [Property] = []
    @Published var profiles: [UserProfile] = []
    @Published var isLoading = false
    @Published var canUpdateStatus = false
    
    private var propertyNameMap: [UUID: String] = [:]
    private var reporterNameMap: [UUID: String] = [:]
    
    private let supabase = SupabaseService.shared.supabase
    
    func loadData() async {
        isLoading = true
        await loadProperties()
        await loadProfiles()
        await loadReports()
        isLoading = false
    }
    
    func loadReports() async {
        do {
            let response: [MaintenanceReport] = try await supabase
                .from("maintenance_reports")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                reports = response
            }
        } catch {
            print("Error loading reports: \(error)")
        }
    }
    
    func loadProperties() async {
        do {
            let response: [Property] = try await supabase
                .from("properties")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                properties = response
                propertyNameMap = Dictionary(uniqueKeysWithValues: response.map { ($0.id, $0.displayName) })
            }
        } catch {
            print("Error loading properties: \(error)")
        }
    }
    
    func loadProfiles() async {
        do {
            let response: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                profiles = response
                reporterNameMap = Dictionary(uniqueKeysWithValues: response.map { ($0.id, "\($0.firstName) \($0.lastName)") })
            }
        } catch {
            print("Error loading profiles: \(error)")
        }
    }
    
    func propertyName(for propertyId: UUID) -> String? {
        propertyNameMap[propertyId]
    }
    
    func reporterName(for reporterId: UUID) -> String? {
        reporterNameMap[reporterId]
    }
}
