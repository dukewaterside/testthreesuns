import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class CleaningViewModel: ObservableObject {
    @Published var cleaningSchedules: [CleaningSchedule] = []
    @Published var availableReservations: [Reservation] = []
    @Published var properties: [Property] = []
    @Published var isLoading = false
    
    private var propertyNameMap: [UUID: String] = [:]
    
    private let supabase = SupabaseService.shared.supabase
    
    func loadCleaningSchedules() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // Get user role to determine if we should load all schedules
            let profileResponse: [String: AnyCodable]? = try? await supabase
                .from("profiles")
                .select("role")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            let role = (profileResponse?["role"]?.value as? String) ?? ""
            
            // For property_manager and owner, load ALL cleaning schedules
            // For cleaning_staff, only load schedules assigned to them
            let response: [CleaningSchedule]
            
            if role == "property_manager" || role == "owner" {
                // Load all schedules for admins
                response = try await supabase
                    .from("cleaning_schedules")
                    .select()
                    .execute()
                    .value
                
                await MainActor.run {
                    // Sort: past schedules first (most recent first), then future schedules (most upcoming first)
                    let now = Date()
                    let pastSchedules = response.filter { $0.scheduledStart < now }
                        .sorted { $0.scheduledStart > $1.scheduledStart }
                    let futureSchedules = response.filter { $0.scheduledStart >= now }
                        .sorted { $0.scheduledStart < $1.scheduledStart }
                    cleaningSchedules = pastSchedules + futureSchedules
                    print("✅ Loaded \(response.count) cleaning schedules (all schedules for \(role))")
                }
            } else {
                // Load only schedules assigned to this cleaner
                response = try await supabase
                    .from("cleaning_schedules")
                    .select()
                    .eq("cleaner_id", value: userId)
                    .execute()
                    .value
                
                await MainActor.run {
                    // Sort: past schedules first (most recent first), then future schedules (most upcoming first)
                    let now = Date()
                    let pastSchedules = response.filter { $0.scheduledStart < now }
                        .sorted { $0.scheduledStart > $1.scheduledStart }
                    let futureSchedules = response.filter { $0.scheduledStart >= now }
                        .sorted { $0.scheduledStart < $1.scheduledStart }
                    cleaningSchedules = pastSchedules + futureSchedules
                    print("✅ Loaded \(response.count) cleaning schedules for cleaner \(userId)")
                }
            }
        } catch {
            print("❌ Error loading cleaning schedules: \(error)")
        }
        isLoading = false
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
    
    func loadAvailableReservations() async {
        do {
            let now = Date()
            let reservations: [Reservation] = try await supabase
                .from("reservations")
                .select()
                .eq("status", value: "confirmed")
                .gte("check_in", value: now)
                .execute()
                .value
            
            availableReservations = reservations
        } catch {
            print("Error loading available reservations: \(error)")
        }
    }
    
    func propertyName(for reservation: Reservation) -> String? {
        propertyNameMap[reservation.propertyId]
    }
    
    func propertyName(for propertyId: UUID) -> String? {
        propertyNameMap[propertyId]
    }
    
    func previousCheckout(for reservation: Reservation) -> Date? {
        // Find the previous reservation's checkout for this property
        // This would need to query the database - simplified for now
        nil
    }
}
