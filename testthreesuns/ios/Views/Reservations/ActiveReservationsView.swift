import SwiftUI
import Combine
import Supabase
import PostgREST

struct ActiveReservationsView: View {
    @StateObject private var viewModel = ReservationsViewModel()
    
    var activeReservations: [Reservation] {
        viewModel.reservations.filter { $0.isActive }
            .sorted { $0.checkIn < $1.checkIn }
    }
    
    var upcomingReservations: [Reservation] {
        let now = Date()
        // Show all confirmed reservations that haven't completed yet (checkOut hasn't passed)
        return viewModel.reservations
            .filter { $0.status == .confirmed && $0.checkOut > now }
            .sorted { $0.checkIn < $1.checkIn }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Active Reservations Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Active Reservations")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        if activeReservations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                Text("No active reservations")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(activeReservations) { reservation in
                                NavigationLink(destination: ActiveReservationDetailView(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))) {
                                    ReservationCard(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Upcoming Reservations Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upcoming Reservations")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        if upcomingReservations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                Text("No upcoming reservations")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(upcomingReservations.prefix(10)) { reservation in
                                NavigationLink(destination: ActiveReservationDetailView(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))) {
                                    ReservationCard(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Reservations")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .onAppear {
                // Always refresh when view appears to catch new reservations
                Task {
                    await viewModel.loadReservations()
                }
            }
        }
    }
}

struct ActiveReservationDetailView: View {
    let reservation: Reservation
    let propertyName: String?
    @StateObject private var viewModel = ReservationsDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(propertyName ?? reservation.guestName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        // Status badge based on reservation status
                        Text(reservation.status == .confirmed ? "Confirmed" : reservation.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(reservation.status == .confirmed ? Color.brandPrimary : Color.gray)
                            .cornerRadius(8)
                    }
                    
                    // Stay Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stay Details")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            // Check-in Card
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Check-in")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(reservation.checkIn, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(reservation.checkIn, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Check-out Card
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Check-out")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(reservation.checkOut, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(reservation.checkOut, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Duration
                        HStack(spacing: 8) {
                            Image(systemName: "moon.stars.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(daysBetween(reservation.checkIn, reservation.checkOut)) nights")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // Cleaning Schedule Section
                if !viewModel.cleaningSchedules.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cleaning Schedule")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.cleaningSchedules.filter { $0.reservationId == reservation.id }) { schedule in
                            CleaningScheduleCard(
                                cleaning: schedule,
                                propertyName: propertyName
                            )
                            .padding(.horizontal)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cleaning Schedule")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("Not Scheduled")
                                .font(.headline)
                            if let propertyName = propertyName {
                                Text("Cleaning required for \(propertyName) before \(reservation.checkIn, style: .date) at \(reservation.checkIn, style: .time)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Cleaning required before \(reservation.checkIn, style: .date) at \(reservation.checkIn, style: .time)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reservation Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadCleaningSchedules(for: reservation.propertyId, reservationId: reservation.id)
        }
        .onAppear {
            Task {
                await viewModel.loadCleaningSchedules(for: reservation.propertyId, reservationId: reservation.id)
            }
        }
        .refreshable {
            await viewModel.loadCleaningSchedules(for: reservation.propertyId, reservationId: reservation.id)
        }
    }
    
    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

@MainActor
class ReservationsViewModel: ObservableObject {
    @Published var reservations: [Reservation] = []
    @Published var properties: [Property] = []
    
    private var propertyNameMap: [UUID: String] = [:]
    private let supabase = SupabaseService.shared.supabase
    
    func loadData() async {
        await loadProperties()
        await loadReservations()
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
                propertyNameMap = Dictionary(uniqueKeysWithValues: response.map { ($0.id, $0.name) })
            }
        } catch {
            print("Error loading properties: \(error)")
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
                print("✅ ReservationsViewModel: Loaded \(response.count) confirmed reservations")
                // Debug: Print reservation details
                for reservation in response {
                    print("  - Reservation \(reservation.id): \(reservation.checkIn) to \(reservation.checkOut), status: \(reservation.status.rawValue)")
                }
            }
        } catch {
            print("❌ ReservationsViewModel: Error loading reservations: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("   PostgrestError: \(postgrestError.message)")
            }
        }
    }
    
    func propertyName(for reservation: Reservation) -> String? {
        propertyNameMap[reservation.propertyId]
    }
}

@MainActor
class ReservationsDetailViewModel: ObservableObject {
    @Published var cleaningSchedules: [CleaningSchedule] = []
    
    private let supabase = SupabaseService.shared.supabase
    
    func loadCleaningSchedules(for propertyId: UUID, reservationId: UUID) async {
        do {
            let response: [CleaningSchedule] = try await supabase
                .from("cleaning_schedules")
                .select()
                .eq("property_id", value: propertyId)
                .eq("reservation_id", value: reservationId)
                .execute()
                .value
            
            await MainActor.run {
                cleaningSchedules = response
            }
        } catch {
            print("Error loading cleaning schedules: \(error)")
            // Try fallback without reservation filter
            do {
                let response: [CleaningSchedule] = try await supabase
                    .from("cleaning_schedules")
                    .select()
                    .eq("property_id", value: propertyId)
                    .execute()
                    .value
                
                await MainActor.run {
                    cleaningSchedules = response.filter { $0.reservationId == reservationId }
                }
            } catch {
                print("Error loading cleaning schedules (fallback): \(error)")
            }
        }
    }
}
