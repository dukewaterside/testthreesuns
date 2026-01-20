import SwiftUI
import Supabase
import PostgREST
import Functions

struct CleaningScheduleView: View {
    @StateObject private var viewModel = CleaningViewModel()
    @State private var selectedStatus: CleaningSchedule.CleaningStatus?
    
    var filteredSchedules: [CleaningSchedule] {
        if let status = selectedStatus {
            return viewModel.cleaningSchedules.filter { $0.status == status }
        }
        return viewModel.cleaningSchedules
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.cleaningSchedules.isEmpty {
                    EmptyStateView(message: "No cleaning schedules")
                } else {
                    List(viewModel.cleaningSchedules) { schedule in
                        NavigationLink(destination: CleaningDetailView(
                            cleaning: schedule,
                            onUpdate: {
                                Task {
                                    await viewModel.loadCleaningSchedules()
                                }
                            }
                        )) {
                            CleaningScheduleCard(
                                cleaning: schedule,
                                propertyName: viewModel.propertyName(for: schedule.propertyId)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Cleaning Schedules")
            .refreshable {
                await viewModel.loadCleaningSchedules()
            }
            .task {
                await viewModel.loadProperties()
                await viewModel.loadCleaningSchedules()
            }
            .onAppear {
                // Refresh when returning to view
                Task {
                    await viewModel.loadCleaningSchedules()
                }
            }
        }
    }
}

struct CleaningFilterBar: View {
    @Binding var selectedStatus: CleaningSchedule.CleaningStatus?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedStatus == nil) {
                    selectedStatus = nil
                }
                
                ForEach([CleaningSchedule.CleaningStatus.scheduled, .inProgress, .completed, .overdue], id: \.self) { status in
                    FilterChip(title: status.displayName, isSelected: selectedStatus == status) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct CleaningDetailView: View {
    let cleaning: CleaningSchedule
    var onUpdate: (() -> Void)? = nil
    @State private var showingUpdateStatus = false
    @State private var showingEditSchedule = false
    @State private var currentCleaning: CleaningSchedule
    @StateObject private var viewModel = CleaningViewModel()
    @Environment(\.dismiss) var dismiss
    
    init(cleaning: CleaningSchedule, onUpdate: (() -> Void)? = nil) {
        self.cleaning = cleaning
        self.onUpdate = onUpdate
        _currentCleaning = State(initialValue: cleaning)
    }
    
    var body: some View {
        Form {
            Section("Schedule Details") {
                LabeledContent("Status", value: currentCleaning.status.displayName)
                LabeledContent("Start", value: currentCleaning.scheduledStart.formatted())
                if let end = currentCleaning.scheduledEnd {
                    LabeledContent("End", value: end.formatted())
                }
            }
            
            Section {
                Button("Edit Date & Time") {
                    showingEditSchedule = true
                }
                Button("Update Status") {
                    showingUpdateStatus = true
                }
            }
        }
        .navigationTitle("Cleaning Details")
        .sheet(isPresented: $showingUpdateStatus) {
            UpdateCleaningStatusView(cleaning: currentCleaning) {
                // Refresh the cleaning schedule after status update
                Task {
                    await refreshCleaning()
                    onUpdate?()
                }
            }
        }
        .sheet(isPresented: $showingEditSchedule) {
            EditCleaningScheduleView(cleaning: currentCleaning) {
                // Refresh the cleaning schedule after edit
                Task {
                    await refreshCleaning()
                    onUpdate?()
                }
            }
        }
        .task {
            await viewModel.loadProperties()
            await refreshCleaning()
        }
        .onChange(of: showingUpdateStatus) { oldValue, newValue in
            if !newValue {
                // Sheet dismissed, refresh
                Task {
                    await refreshCleaning()
                    onUpdate?()
                }
            }
        }
        .onChange(of: showingEditSchedule) { oldValue, newValue in
            if !newValue {
                // Sheet dismissed, refresh
                Task {
                    await refreshCleaning()
                    onUpdate?()
                }
            }
        }
    }
    
    private func refreshCleaning() async {
        do {
            let updated: CleaningSchedule = try await SupabaseService.shared.supabase
                .from("cleaning_schedules")
                .select()
                .eq("id", value: cleaning.id)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                currentCleaning = updated
            }
        } catch {
            print("Error refreshing cleaning schedule: \(error)")
        }
    }
}

struct UpdateCleaningStatusView: View {
    let cleaning: CleaningSchedule
    var onUpdated: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus: CleaningSchedule.CleaningStatus
    @State private var isSubmitting = false
    
    init(cleaning: CleaningSchedule, onUpdated: (() -> Void)? = nil) {
        self.cleaning = cleaning
        self.onUpdated = onUpdated
        _selectedStatus = State(initialValue: cleaning.status)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Status", selection: $selectedStatus) {
                    ForEach([CleaningSchedule.CleaningStatus.scheduled, .inProgress, .completed], id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateStatus()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
    
    private func updateStatus() {
        isSubmitting = true
        Task {
            do {
                // Use edge function to bypass RLS
                let bodyDict: [String: AnyCodable] = [
                    "cleaning_schedule_id": AnyCodable(cleaning.id.uuidString),
                    "status": AnyCodable(selectedStatus.rawValue)
                ]
                
                let _: Void = try await SupabaseService.shared.supabase.functions
                    .invoke("update-cleaning-schedule", options: FunctionInvokeOptions(body: bodyDict))
                
                await MainActor.run {
                    isSubmitting = false
                    onUpdated?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    print("❌ Error updating status: \(error)")
                    if let functionsError = error as? FunctionsError {
                        print("❌ FunctionsError: \(functionsError)")
                    }
                }
            }
        }
    }
}

struct EditCleaningScheduleView: View {
    let cleaning: CleaningSchedule
    let onUpdated: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CleaningViewModel()
    
    @State private var scheduledStart: Date
    @State private var scheduledEnd: Date
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    
    init(cleaning: CleaningSchedule, onUpdated: @escaping () -> Void) {
        self.cleaning = cleaning
        self.onUpdated = onUpdated
        _scheduledStart = State(initialValue: cleaning.scheduledStart)
        _scheduledEnd = State(initialValue: cleaning.scheduledEnd ?? cleaning.scheduledStart)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let reservationId = cleaning.reservationId {
                    // Load reservation to get window bounds
                    if let reservation = viewModel.availableReservations.first(where: { $0.id == reservationId }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cleaning Window")
                                .font(.headline)
                            
                            let windowStart = cleaningWindowStart(for: reservation)
                            let windowEnd = cleaningWindowEnd(for: reservation)
                            
                            Text(cleaningWindowMessage(start: windowStart, end: windowEnd))
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
                    }
                }
                
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
                
                Button(action: updateSchedule) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Update Schedule")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .cornerRadius(12)
                }
                .disabled(isSubmitting)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Cleaning Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadProperties()
                await viewModel.loadAvailableReservations()
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func cleaningWindowStart(for reservation: Reservation) -> Date {
        // Cleaning window starts at checkout
        return reservation.checkOut
    }
    
    private func cleaningWindowEnd(for reservation: Reservation) -> Date? {
        // Find next reservation's check-in
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
    
    private func cleaningWindowMessage(start: Date, end: Date?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let startString = dateFormatter.string(from: start)
        
        if let endDate = end {
            let endString = dateFormatter.string(from: endDate)
            return "Must be between \(startString) and \(endString)"
        } else {
            return "Must be after \(startString)"
        }
    }
    
    private func updateSchedule() {
        // Validate dates
        if scheduledStart >= scheduledEnd {
            errorMessage = "Start time must be before end time"
            showingError = true
            return
        }
        
        // Validate against window bounds if reservation exists
        if let reservationId = cleaning.reservationId,
           let reservation = viewModel.availableReservations.first(where: { $0.id == reservationId }) {
            let windowStart = cleaningWindowStart(for: reservation)
            let windowEnd = cleaningWindowEnd(for: reservation)
            
            if scheduledStart < windowStart {
                errorMessage = "Start time must be after checkout time"
                showingError = true
                return
            }
            
            if let end = windowEnd, scheduledStart >= end {
                errorMessage = "Start time must be before next check-in"
                showingError = true
                return
            }
            
            if let end = windowEnd, scheduledEnd > end {
                errorMessage = "End time must be before next check-in"
                showingError = true
                return
            }
        }
        
        isSubmitting = true
        showingError = false
        
        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                formatter.timeZone = TimeZone.current
                
                let scheduledStartString = formatter.string(from: scheduledStart)
                let scheduledEndString = formatter.string(from: scheduledEnd)
                
                // Use edge function to bypass RLS
                let bodyDict: [String: AnyCodable] = [
                    "cleaning_schedule_id": AnyCodable(cleaning.id.uuidString),
                    "scheduled_start": AnyCodable(scheduledStartString),
                    "scheduled_end": AnyCodable(scheduledEndString)
                ]
                
                let _: Void = try await SupabaseService.shared.supabase.functions
                    .invoke("update-cleaning-schedule", options: FunctionInvokeOptions(body: bodyDict))
                
                await MainActor.run {
                    isSubmitting = false
                    onUpdated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    print("❌ Error updating schedule: \(error)")
                    if let functionsError = error as? FunctionsError {
                        print("❌ FunctionsError: \(functionsError)")
                        errorMessage = "Failed to update schedule: \(functionsError.localizedDescription)"
                    } else {
                        errorMessage = "Failed to update schedule: \(error.localizedDescription)"
                    }
                    showingError = true
                }
            }
        }
    }
}
