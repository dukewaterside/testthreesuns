import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var reservations: [Reservation] = []
    @Published var cleaningSchedules: [CleaningSchedule] = []
    @Published var checklists: [Checklist] = []
    @Published var maintenanceReports: [MaintenanceReport] = []
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    
    // Map property IDs to property names for quick lookup
    private var propertyNameMap: [UUID: String] = [:]
    private var reporterNameMap: [UUID: String] = [:]
    
    private let supabase = SupabaseService.shared.supabase
    
    var propertiesCount: Int { properties.count }
    var activeReservationsCount: Int {
        reservations.filter { $0.isActive }.count
    }
    var pendingMaintenanceCount: Int {
        maintenanceReports.filter { $0.status == .reported }.count
    }
    
    var openMaintenanceReports: [MaintenanceReport] {
        maintenanceReports.filter { $0.status == .reported }
            .sorted { $0.severity == .urgent && $1.severity != .urgent }
    }
    var unreadNotificationsCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    var upcomingCheckouts: [Reservation] {
        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        return reservations
            .filter { $0.status == .confirmed && $0.checkOut >= now && $0.checkOut <= nextWeek }
            .sorted { $0.checkOut < $1.checkOut }
    }
    
    var upcomingCheckins: [Reservation] {
        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        return reservations
            .filter { $0.status == .confirmed && $0.checkIn >= now && $0.checkIn <= nextWeek }
            .sorted { $0.checkIn < $1.checkIn }
    }
    
    var pendingChecklists: [Checklist] {
        checklists.filter { !$0.isCompleted }
    }
    
    // Count only inspection, supplies, and maintenance checklists (for property managers)
    var pendingChecklistsCount: Int {
        checklists.filter { 
            !$0.isCompleted && 
            ($0.checklistType == .inspection || $0.checklistType == .supplies || $0.checklistType == .maintenance)
        }.count
    }
    
    // Count cleaning checklists that are from reservations that have checked out
    // This is a computed property that will be updated when reservations are loaded
    var pendingCleaningChecklistsCount: Int {
        let now = Date()
        return checklists.filter { checklist in
            guard !checklist.isCompleted,
                  checklist.checklistType == .cleaning,
                  let reservationId = checklist.reservationId else {
                return false
            }
            
            // Check if reservation exists and has checked out
            if let reservation = reservations.first(where: { $0.id == reservationId }) {
                return reservation.checkOut < now && reservation.status == .confirmed
            }
            
            return false
        }.count
    }
    
    var pendingMaintenanceReportsCount: Int {
        maintenanceReports.filter { $0.status == .reported }.count
    }
    
    var todaysCleanings: [CleaningSchedule] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return cleaningSchedules
            .filter { $0.scheduledStart >= today && $0.scheduledStart < tomorrow }
            .sorted { $0.scheduledStart < $1.scheduledStart }
    }
    
    var upcomingCleanings: [CleaningSchedule] {
        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        return cleaningSchedules
            .filter { $0.scheduledStart >= now && $0.scheduledStart <= nextWeek }
            .sorted { $0.scheduledStart < $1.scheduledStart }
    }
    
    var availableWindows: [AvailableCleaningWindow] {
        []
    }
    
    var recentNotifications: [AppNotification] {
        notifications.sorted { $0.sentAt > $1.sentAt }
    }
    
    func loadData() async {
        isLoading = true
        await loadProperties()
        await loadProfiles()
        await loadReservations()
        await loadCleaningSchedules()
        await loadChecklists()
        await loadMaintenanceReports()
        await loadNotifications()
        isLoading = false
    }
    
    
    func refresh() async {
        await loadData()
    }
    
    private func loadProperties() async {
        do {
            let response: [Property] = try await supabase
                .from("properties")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                properties = response
                // Build property name map
                propertyNameMap = Dictionary(uniqueKeysWithValues: response.map { ($0.id, $0.name) })
                print("✅ Dashboard: Loaded \(response.count) properties")
            }
        } catch {
            print("❌ Dashboard: Error loading properties: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
    
    func propertyName(for reservation: Reservation) -> String? {
        propertyNameMap[reservation.propertyId]
    }
    
    func propertyName(for propertyId: UUID) -> String? {
        propertyNameMap[propertyId]
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
                print("✅ Dashboard: Loaded \(response.count) confirmed reservations")
                // Debug: Print reservation details
                for reservation in response {
                    print("  - Reservation \(reservation.id): \(reservation.checkIn) to \(reservation.checkOut), status: \(reservation.status.rawValue)")
                }
            }
        } catch {
            print("❌ Dashboard: Error loading reservations: \(error)")
            print("   Error details: \(error.localizedDescription)")
            if let postgrestError = error as? PostgrestError {
                print("   PostgrestError: \(postgrestError.message)")
            }
        }
    }
    
    private func loadCleaningSchedules() async {
        do {
            let response: [CleaningSchedule] = try await supabase
                .from("cleaning_schedules")
                .select()
                .execute()
                .value
            
            cleaningSchedules = response
        } catch {
            print("Error loading cleaning schedules: \(error)")
        }
    }
    
    func loadChecklists() async {
        do {
            // Load checklists for the current user (manager) or all for cleaner/owner
            let response: [Checklist] = try await supabase
                .from("checklists")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                checklists = response
            }
        } catch {
            // Also try loading all checklists if user-specific query fails (for owner view)
            do {
                let response: [Checklist] = try await supabase
                    .from("checklists")
                    .select()
                    .execute()
                    .value
                
                await MainActor.run {
                    checklists = response
                }
            } catch {
                print("Error loading checklists: \(error)")
            }
        }
    }
    
    
    private func loadMaintenanceReports() async {
        do {
            let response: [MaintenanceReport] = try await supabase
                .from("maintenance_reports")
                .select()
                .execute()
                .value
            
            maintenanceReports = response
        } catch {
            print("Error loading maintenance reports: \(error)")
        }
    }
    
    private func loadNotifications() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let response: [AppNotification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("sent_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            notifications = response
        } catch {
            print("Error loading notifications: \(error)")
        }
    }
}

struct AvailableCleaningWindow: Identifiable {
    let id = UUID()
    let reservationId: UUID
    let propertyId: UUID
    let propertyName: String
    let windowStart: Date
    let windowEnd: Date
}
