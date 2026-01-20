import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class PropertiesViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var isLoading = false
    
    private let supabase = SupabaseService.shared.supabase
    
    func loadProperties() async {
        isLoading = true
        do {
            let response: [Property] = try await supabase
                .from("properties")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                properties = response
                print("✅ Loaded \(response.count) properties")
            }
        } catch {
            print("❌ Error loading properties: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

@MainActor
class PropertyDetailViewModel: ObservableObject {
    @Published var currentReservation: Reservation?
    @Published var upcomingReservations: [Reservation] = []
    @Published var cleaningSchedules: [CleaningSchedule] = []
    @Published var maintenanceReports: [MaintenanceReport] = []
    
    private var reporterNameMap: [UUID: String] = [:]
    
    private let supabase = SupabaseService.shared.supabase
    
    func loadData(for propertyId: UUID) async {
        await loadProfiles()
        await loadReservations(for: propertyId)
        await loadCleaningSchedules(for: propertyId)
        await loadMaintenanceReports(for: propertyId)
    }
    
    func reporterName(for reporterId: UUID) -> String? {
        reporterNameMap[reporterId]
    }
    
    private func loadProfiles() async {
        do {
            let response: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                reporterNameMap = Dictionary(uniqueKeysWithValues: response.map { ($0.id, "\($0.firstName) \($0.lastName)") })
            }
        } catch {
            print("Error loading profiles: \(error)")
        }
    }
    
    private func loadReservations(for propertyId: UUID) async {
        do {
            let now = Date()
            let reservations: [Reservation] = try await supabase
                .from("reservations")
                .select()
                .eq("property_id", value: propertyId)
                .eq("status", value: "confirmed")
                .execute()
                .value
            
            currentReservation = reservations.first { $0.isActive }
            upcomingReservations = reservations
                .filter { $0.checkIn > now }
                .sorted { $0.checkIn < $1.checkIn }
        } catch {
            print("Error loading reservations: \(error)")
        }
    }
    
    private func loadCleaningSchedules(for propertyId: UUID) async {
        do {
            let schedules: [CleaningSchedule] = try await supabase
                .from("cleaning_schedules")
                .select()
                .eq("property_id", value: propertyId)
                .order("scheduled_start", ascending: false)
                .execute()
                .value
            
            cleaningSchedules = schedules
        } catch {
            print("Error loading cleaning schedules: \(error)")
        }
    }
    
    private func loadMaintenanceReports(for propertyId: UUID) async {
        do {
            let reports: [MaintenanceReport] = try await supabase
                .from("maintenance_reports")
                .select()
                .eq("property_id", value: propertyId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                maintenanceReports = reports
            }
        } catch {
            print("Error loading maintenance reports: \(error)")
        }
    }
}
