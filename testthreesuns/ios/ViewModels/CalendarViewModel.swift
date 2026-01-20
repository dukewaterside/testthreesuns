import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var reservations: [Reservation] = []
    @Published var cleaningSchedules: [CleaningSchedule] = []
    @Published var properties: [Property] = []
    
    // Map property IDs to property names for quick lookup
    private var propertyNameMap: [UUID: String] = [:]
    
    private let supabase = SupabaseService.shared.supabase
    
    func loadProperties() async {
        do {
            let response: [Property] = try await supabase
                .from("properties")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                properties = response
                propertyNameMap = Dictionary(uniqueKeysWithValues: response.map { ($0.id, $0.name) })
            }
        } catch {
            print("❌ Error loading properties: \(error)")
        }
    }
    
    func loadReservations() async {
        do {
            let response: [Reservation] = try await supabase
                .from("reservations")
                .select()
                .eq("status", value: "confirmed")
                .execute()
                .value
            
            await MainActor.run {
                reservations = response
                print("✅ Loaded \(response.count) reservations")
            }
        } catch {
            print("❌ Error loading reservations: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
    
    func loadCleaningSchedules() async {
        do {
            let response: [CleaningSchedule] = try await supabase
                .from("cleaning_schedules")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                cleaningSchedules = response
                print("✅ Loaded \(response.count) cleaning schedules")
            }
        } catch {
            print("❌ Error loading cleaning schedules: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
    
    func propertyName(for reservation: Reservation) -> String? {
        propertyNameMap[reservation.propertyId]
    }
}
