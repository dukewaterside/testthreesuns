import SwiftUI
import Supabase
import Functions

struct ScheduleCleaningView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CleaningViewModel()
    
    let preSelectedReservation: Reservation?
    @State private var selectedReservation: Reservation?
    @State private var scheduledStart = Date()
    @State private var scheduledEnd = Date()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingScheduleSheet = false
    @State private var showingSuccessAlert = false
    
    @State private var selectedProperty: Property?
    
    init(preSelectedReservation: Reservation? = nil) {
        self.preSelectedReservation = preSelectedReservation
    }
    
    var filteredReservations: [Reservation] {
        var filtered = viewModel.availableReservations
        
        // If a property is selected, filter by it
        if let property = selectedProperty {
            filtered = filtered.filter { $0.propertyId == property.id }
        }
        
        // If a reservation is selected, show only that one (or all if none selected)
        if let selected = selectedReservation {
            filtered = filtered.filter { $0.id == selected.id }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Property Filter
                    if !viewModel.properties.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Filter by Property")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Menu {
                                Button(action: {
                                    selectedProperty = nil
                                }) {
                                    Label("All Properties", systemImage: selectedProperty == nil ? "checkmark" : "")
                                }
                                
                                ForEach(viewModel.properties) { property in
                                    Button(action: {
                                        selectedProperty = property
                                    }) {
                                        Label(property.name, systemImage: selectedProperty?.id == property.id ? "checkmark" : "")
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedProperty?.name ?? "All Properties")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if filteredReservations.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No Available Reservations")
                                .font(.headline)
                            Text("There are no upcoming reservations that need cleaning scheduled.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(filteredReservations) { reservation in
                            ReservationScheduleCard(
                                reservation: reservation,
                                propertyName: viewModel.propertyName(for: reservation),
                                isSelected: selectedReservation?.id == reservation.id,
                                onTap: {
                                    selectedReservation = reservation
                                    // Set default times based on reservation window
                                    if let previousCheckout = previousCheckout(for: reservation) {
                                        scheduledStart = previousCheckout
                                    } else {
                                        scheduledStart = reservation.checkIn
                                    }
                                    scheduledEnd = reservation.checkIn
                                    showingScheduleSheet = true
                                }
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Schedule Cleaning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadProperties()
                await viewModel.loadAvailableReservations()
                
                // Pre-select reservation if provided
                if let preSelected = preSelectedReservation {
                    selectedReservation = preSelected
                    if let previousCheckout = previousCheckout(for: preSelected) {
                        scheduledStart = previousCheckout
                    } else {
                        scheduledStart = preSelected.checkIn
                    }
                    scheduledEnd = preSelected.checkIn
                    selectedProperty = viewModel.properties.first { $0.id == preSelected.propertyId }
                    showingScheduleSheet = true
                }
            }
            .sheet(isPresented: $showingScheduleSheet) {
                if let reservation = selectedReservation {
                    ScheduleCleaningBottomSheet(
                        reservation: reservation,
                        cleaningWindowStart: cleaningWindowStart(for: reservation),
                        cleaningWindowEnd: cleaningWindowEnd(for: reservation),
                        scheduledStart: $scheduledStart,
                        scheduledEnd: $scheduledEnd,
                        showingError: $showingError,
                        errorMessage: $errorMessage,
                        onSchedule: {
                            scheduleCleaning()
                        },
                        onCancel: {
                            showingScheduleSheet = false
                            selectedReservation = nil
                        }
                    )
                }
            }
            .alert("Cleaning Scheduled", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your cleaning has been successfully scheduled.")
            }
        }
    }
    
    private func previousCheckout(for reservation: Reservation) -> Date? {
        // Find previous reservation's checkout for this property
        let now = Date()
        return viewModel.availableReservations
            .filter { 
                $0.propertyId == reservation.propertyId && 
                $0.checkOut < reservation.checkIn &&
                $0.checkOut < now
            }
            .sorted { $0.checkOut > $1.checkOut }
            .first?
            .checkOut
    }
    
    private func nextCheckin(for reservation: Reservation) -> Date? {
        // Find next reservation's check-in for this property
        return viewModel.availableReservations
            .filter { 
                $0.propertyId == reservation.propertyId && 
                $0.checkIn > reservation.checkOut &&
                $0.id != reservation.id
            }
            .sorted { $0.checkIn < $1.checkIn }
            .first?
            .checkIn
    }
    
    private func cleaningWindowStart(for reservation: Reservation) -> Date {
        // Cleaning window starts at the current reservation's checkout time (after guest leaves)
        // The cleaning happens AFTER this reservation ends
        return reservation.checkOut
    }
    
    private func cleaningWindowEnd(for reservation: Reservation) -> Date? {
        // Cleaning window ends at next check-in (if exists)
        return nextCheckin(for: reservation)
    }
    
    private func scheduleCleaning() {
        guard let reservation = selectedReservation else { return }
        
        // Validate dates
        if scheduledStart >= scheduledEnd {
            errorMessage = "Start time must be before end time"
            showingError = true
            return
        }
        
        Task {
            do {
                // Ensure we have a valid session
                let session = try await SupabaseService.shared.supabase.auth.session
                let userId = session.user.id
                
                // Format dates as ISO8601 strings without fractional seconds
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                formatter.timeZone = TimeZone.current
                
                let scheduledStartString = formatter.string(from: scheduledStart)
                let scheduledEndString = formatter.string(from: scheduledEnd)
                
                print("Scheduling cleaning with:")
                print("  reservation_id: \(reservation.id.uuidString)")
                print("  cleaner_id: \(userId.uuidString)")
                print("  scheduled_start: \(scheduledStartString)")
                print("  scheduled_end: \(scheduledEndString)")
                
                let bodyDict: [String: AnyCodable] = [
                    "reservation_id": AnyCodable(reservation.id.uuidString),
                    "cleaner_id": AnyCodable(userId.uuidString),
                    "scheduled_start": AnyCodable(scheduledStartString),
                    "scheduled_end": AnyCodable(scheduledEndString)
                ]
                
                let _: Void = try await SupabaseService.shared.supabase.functions
                    .invoke("schedule-cleaning", options: FunctionInvokeOptions(body: bodyDict))
                
                // Reload cleaning schedules after successful scheduling
                await viewModel.loadCleaningSchedules()
                
                await MainActor.run {
                    showingScheduleSheet = false
                    selectedReservation = nil
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    // Try to extract error message from response
                    if let httpError = error as? URLError {
                        errorMessage = "Network error: \(httpError.localizedDescription)"
                    } else {
                        errorMessage = "Failed to schedule cleaning: \(error.localizedDescription)"
                    }
                    showingError = true
                    print("Error scheduling cleaning: \(error)")
                    
                    // Print detailed error for debugging
                    if let nsError = error as NSError? {
                        print("Error domain: \(nsError.domain)")
                        print("Error code: \(nsError.code)")
                        print("Error userInfo: \(nsError.userInfo)")
                    }
                }
            }
        }
    }
}

struct ScheduleCleaningBottomSheet: View {
    let reservation: Reservation
    let cleaningWindowStart: Date
    let cleaningWindowEnd: Date?
    @Binding var scheduledStart: Date
    @Binding var scheduledEnd: Date
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    let onSchedule: () -> Void
    let onCancel: () -> Void
    
    var cleaningWindowMessage: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let startDateString = dateFormatter.string(from: cleaningWindowStart)
        
        if let endDate = cleaningWindowEnd {
            let endDateString = dateFormatter.string(from: endDate)
            return "Must be between \(startDateString) and \(endDateString)"
        } else {
            return "Must be after \(startDateString)"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Schedule Cleaning Time")
                        .font(.headline)
                    
                    Text("Reservation: \(reservation.checkIn, style: .date) - \(reservation.checkOut, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Cleaning window message
                    Text(cleaningWindowMessage)
                        .font(.caption)
                        .foregroundColor(.brandPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.brandPrimary.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    DatePicker("Start Time", selection: $scheduledStart, displayedComponents: [.date, .hourAndMinute])
                    
                    DatePicker("End Time", selection: $scheduledEnd, displayedComponents: [.date, .hourAndMinute])
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                if showingError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button(action: onSchedule) {
                    Text("Schedule Cleaning")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary)
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Schedule Cleaning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
