import SwiftUI
import UIKit

struct CleanerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Welcome Section
                DashboardHeaderView(
                    firstName: authViewModel.userProfile?.firstName ?? "User",
                    role: authViewModel.userProfile?.role ?? .cleaningStaff,
                    viewModel: viewModel
                )
                
                // Content Section
                VStack(spacing: 20) {
                    // Urgent cleaning banner - show if there are urgent cleanings needed within 24 hours
                    if !viewModel.urgentCleaningsNeeded.isEmpty {
                        UrgentCleaningBanner(
                            reservations: viewModel.urgentCleaningsNeeded,
                            viewModel: viewModel
                        )
                    }
                    
                    CleanerQuickActionsView(viewModel: viewModel)
                    
                    UpcomingCleaningsSection(viewModel: viewModel)
                    
                    CleaningsNeedingSchedulingSection(viewModel: viewModel)
                }
                .padding()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct CleanerQuickActionsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showingPropertySelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(destination: CalendarView()) {
                    QuickActionButton(icon: "calendar", title: "View Calendar", color: .brandPrimary)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    showingPropertySelection = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        QuickActionButton(icon: "checklist", title: "See Checklist", color: .brandPrimary)
                        
                        // Badge for pending checklists
                        if viewModel.pendingCleaningChecklistsCount > 0 {
                            Text("\(viewModel.pendingCleaningChecklistsCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: CleaningsNeedingSchedulingView(viewModel: viewModel)) {
                    QuickActionButton(icon: "calendar.badge.plus", title: "Schedule a Cleaning", color: .brandPrimary)
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: CreateMaintenanceReportView(showCancelButton: false)) {
                    QuickActionButton(icon: "wrench.and.screwdriver", title: "Report Maintenance", color: .brandPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showingPropertySelection) {
            PropertyChecklistSelectionView()
                .interactiveDismissDisabled(true)
        }
    }
}

struct UpcomingCleaningsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var todaysDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }
    
    var upcomingCleanings: [CleaningSchedule] {
        let now = Date()
        return viewModel.cleaningSchedules
            .filter { $0.scheduledStart >= now && $0.status == .scheduled }
            .sorted { $0.scheduledStart < $1.scheduledStart }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Cleanings")
                    .font(.headline)
                Spacer()
                NavigationLink("See All", destination: CleaningScheduleView())
                    .font(.subheadline)
                    .foregroundColor(.brandPrimary)
            }
            
            if upcomingCleanings.isEmpty {
                Text("No upcoming cleanings")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(upcomingCleanings.prefix(2)) { cleaning in
                    UpcomingCleaningCard(
                        cleaning: cleaning,
                        propertyName: viewModel.propertyName(for: cleaning.propertyId),
                        viewModel: viewModel
                    )
                }
            }
        }
    }
}

struct CleaningsNeedingSchedulingSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedProperty: Property?
    @State private var showingAll = false
    
    var reservationsNeedingCleaning: [Reservation] {
        let now = Date()
        
        // Get all upcoming confirmed reservations
        var upcomingReservations = viewModel.reservations
            .filter { $0.status == .confirmed && $0.checkIn >= now }
        
        // Filter by property if selected
        if let property = selectedProperty {
            upcomingReservations = upcomingReservations.filter { $0.propertyId == property.id }
        }
        
        // Get all scheduled cleaning reservation IDs from DB
        let scheduledCleaningReservationIds = Set(viewModel.cleaningSchedules
            .compactMap { $0.reservationId })
        
        // Find reservations that DON'T have a cleaning scheduled
        let withoutScheduling = upcomingReservations
            .filter { !scheduledCleaningReservationIds.contains($0.id) }
            .sorted { $0.checkIn < $1.checkIn }
        
        return withoutScheduling
    }
    
    var displayedReservations: [Reservation] {
        if showingAll {
            return reservationsNeedingCleaning
        } else {
            return Array(reservationsNeedingCleaning.prefix(2))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cleanings Needing Scheduling")
                    .font(.headline)
                Spacer()
                if !reservationsNeedingCleaning.isEmpty {
                    Text("\(reservationsNeedingCleaning.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
                    // Property Filter - Use LazyVGrid with 2 columns for better pill width
            if !viewModel.properties.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Filter by Property")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        Button(action: {
                            selectedProperty = nil
                        }) {
                            Text("All")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedProperty == nil ? Color.brandPrimary : Color(.systemGray5))
                                .foregroundColor(selectedProperty == nil ? .white : .primary)
                                .cornerRadius(10)
                        }
                        
                        ForEach(viewModel.properties) { property in
                            Button(action: {
                                selectedProperty = property
                            }) {
                                Text(property.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedProperty?.id == property.id ? Color.brandPrimary : Color(.systemGray5))
                                    .foregroundColor(selectedProperty?.id == property.id ? .white : .primary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            
            if reservationsNeedingCleaning.isEmpty {
                Text("All upcoming cleanings are scheduled")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(displayedReservations) { reservation in
                    NavigationLink(destination: ScheduleCleaningView(preSelectedReservation: reservation)) {
                        ReservationCard(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))
                    }
                    .buttonStyle(.plain)
                }
                
                // Show "See All" or "Show Less" button
                if reservationsNeedingCleaning.count > 2 {
                    Button(action: {
                        withAnimation {
                            showingAll.toggle()
                        }
                    }) {
                        HStack {
                            Text(showingAll ? "Show Less" : "See All (\(reservationsNeedingCleaning.count))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: showingAll ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct ActiveCleaningsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var activeCleanings: [CleaningSchedule] {
        let now = Date()
        let fifteenMinutesAgo = Calendar.current.date(byAdding: .minute, value: -15, to: now)!
        
        // Cleanings that are in progress or just finished (within last 15 minutes)
        return viewModel.cleaningSchedules
            .filter { schedule in
                let isInProgress = schedule.status == .inProgress || schedule.status == .completed
                let isRecent = schedule.scheduledStart <= now && schedule.scheduledEnd ?? schedule.scheduledStart >= fifteenMinutesAgo
                return isInProgress && isRecent
            }
            .sorted { $0.scheduledStart < $1.scheduledStart }
    }
    
    var body: some View {
        if !activeCleanings.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active Cleanings")
                    .font(.headline)
                
                ForEach(activeCleanings) { cleaning in
                    ActiveCleaningCard(cleaning: cleaning, viewModel: viewModel)
                }
            }
        }
    }
}

struct ActiveCleaningCard: View {
    let cleaning: CleaningSchedule
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showingChecklist = false
    @State private var checklist: Checklist?
    @State private var isLoadingChecklist = false
    @State private var checklistError: String?
    
    var isWithin15Minutes: Bool {
        let now = Date()
        let fifteenMinutesAgo = Calendar.current.date(byAdding: .minute, value: -15, to: now)!
        return cleaning.scheduledEnd ?? cleaning.scheduledStart >= fifteenMinutesAgo && cleaning.scheduledEnd ?? cleaning.scheduledStart <= now
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cleaning in Progress")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await loadChecklistForCleaning()
                        showingChecklist = true
                    }
                }) {
                    Text("Complete Checklist")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.brandPrimary)
                        .cornerRadius(8)
                }
                .disabled(isLoadingChecklist)
            }
            
            Text("Complete within 15 minutes of finishing")
                .font(.caption)
                .foregroundColor(isWithin15Minutes ? .brandPrimary : .secondary)
            
            if !isWithin15Minutes {
                Text("⚠️ Time window closing soon")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.brandPrimary.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showingChecklist) {
            Group {
                if isLoadingChecklist {
                    NavigationStack {
                        VStack {
                            ProgressView()
                            Text("Loading checklist...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Cleaning Checklist")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingChecklist = false
                                }
                            }
                        }
                    }
                } else if let checklist = checklist {
                    CleaningChecklistView(checklist: checklist, cleaningSchedule: cleaning)
                } else if let error = checklistError {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Checklist Not Found")
                                .font(.headline)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Cleaning Checklist")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingChecklist = false
                                }
                            }
                        }
                    }
                } else {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Checklist Not Found")
                                .font(.headline)
                            Text("No cleaning checklist found for this cleaning. Please contact your manager.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Cleaning Checklist")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingChecklist = false
                                }
                            }
                        }
                    }
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
    
    private func loadChecklistForCleaning() async {
        isLoadingChecklist = true
        checklistError = nil
        
        // First, try to find checklist in already loaded data
        var foundChecklist: Checklist?
        
        if let reservationId = cleaning.reservationId {
            foundChecklist = viewModel.checklists.first { checklist in
                checklist.reservationId == reservationId &&
                checklist.checklistType == .cleaning &&
                !checklist.isCompleted
            }
        } else {
            foundChecklist = viewModel.checklists.first { checklist in
                checklist.propertyId == cleaning.propertyId &&
                checklist.checklistType == .cleaning &&
                !checklist.isCompleted
            }
        }
        
        // If not found, reload checklists from server
        if foundChecklist == nil {
            await viewModel.loadChecklists()
            
            // Try again after reload
            if let reservationId = cleaning.reservationId {
                foundChecklist = viewModel.checklists.first { checklist in
                    checklist.reservationId == reservationId &&
                    checklist.checklistType == .cleaning &&
                    !checklist.isCompleted
                }
            } else {
                foundChecklist = viewModel.checklists.first { checklist in
                    checklist.propertyId == cleaning.propertyId &&
                    checklist.checklistType == .cleaning &&
                    !checklist.isCompleted
                }
            }
        }
        
        await MainActor.run {
            if let found = foundChecklist {
                checklist = found
                checklistError = nil
            } else {
                checklist = nil
                checklistError = "No cleaning checklist found for this cleaning schedule. The checklist may not have been created yet."
            }
            isLoadingChecklist = false
        }
    }
}

struct UpcomingCleaningCard: View {
    let cleaning: CleaningSchedule
    let propertyName: String?
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var isExpanded = false
    @State private var showingChecklist = false
    @State private var checklist: Checklist?
    @State private var isLoadingChecklist = false
    @State private var checklistError: String?
    
    private var statusBackgroundColor: Color {
        switch cleaning.status {
        case .scheduled:
            return .scheduledBackground
        case .inProgress:
            return .inProgressBackground
        case .completed:
            return .completedBackground
        case .overdue:
            return .overdueBackground
        }
    }
    
    private var property: Property? {
        viewModel.properties.first { $0.id == cleaning.propertyId }
    }
    
    private var mapsURL: URL? {
        guard
            let address = property?.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            !address.isEmpty
        else { return nil }
        return URL(string: "http://maps.apple.com/?daddr=\(address)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                CleaningScheduleCard(
                    cleaning: cleaning,
                    propertyName: propertyName
                )
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Label("Address", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let url = mapsURL {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond")
                                        .font(.caption)
                                    Text("Directions")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.brandPrimary)
                            }
                        }
                    }
                    
                    Text(property?.address ?? "Address unavailable")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text("Property Status")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let status = property?.status {
                            StatusBadge(status: status)
                        } else {
                            Text("Unknown")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .slide))
            }
            
            // Start Checklist button - always show, not just for today
            Button(action: {
                Task {
                    await loadChecklistForCleaning()
                    showingChecklist = true
                }
            }) {
                HStack {
                    Image(systemName: "checklist")
                        .font(.subheadline)
                    Text("Start Checklist")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.brandPrimary)
                .cornerRadius(10)
            }
            .disabled(isLoadingChecklist)
        }
        .padding()
        .background(statusBackgroundColor)
        .cornerRadius(12)
        .sheet(isPresented: $showingChecklist) {
            Group {
                if isLoadingChecklist {
                    NavigationStack {
                        VStack {
                            ProgressView()
                            Text("Loading checklist...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Cleaning Checklist")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingChecklist = false
                                }
                            }
                        }
                    }
                } else if let checklist = checklist {
                    CleaningChecklistView(checklist: checklist, cleaningSchedule: cleaning)
                } else if let error = checklistError {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Checklist Not Found")
                                .font(.headline)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Cleaning Checklist")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingChecklist = false
                                }
                            }
                        }
                    }
                } else {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Checklist Not Found")
                                .font(.headline)
                            Text("No cleaning checklist found for this cleaning. Please contact your manager.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Cleaning Checklist")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingChecklist = false
                                }
                            }
                        }
                    }
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
    
    private func loadChecklistForCleaning() async {
        isLoadingChecklist = true
        checklistError = nil
        
        // First, try to find checklist in already loaded data
        var foundChecklist: Checklist?
        
        if let reservationId = cleaning.reservationId {
            foundChecklist = viewModel.checklists.first { checklist in
                checklist.reservationId == reservationId &&
                checklist.checklistType == .cleaning &&
                !checklist.isCompleted
            }
        } else {
            foundChecklist = viewModel.checklists.first { checklist in
                checklist.propertyId == cleaning.propertyId &&
                checklist.checklistType == .cleaning &&
                !checklist.isCompleted
            }
        }
        
        // If not found, reload checklists from server
        if foundChecklist == nil {
            await viewModel.loadChecklists()
            
            // Try again after reload
            if let reservationId = cleaning.reservationId {
                foundChecklist = viewModel.checklists.first { checklist in
                    checklist.reservationId == reservationId &&
                    checklist.checklistType == .cleaning &&
                    !checklist.isCompleted
                }
            } else {
                foundChecklist = viewModel.checklists.first { checklist in
                    checklist.propertyId == cleaning.propertyId &&
                    checklist.checklistType == .cleaning &&
                    !checklist.isCompleted
                }
            }
        }
        
        await MainActor.run {
            if let found = foundChecklist {
                checklist = found
                checklistError = nil
            } else {
                checklist = nil
                checklistError = "No cleaning checklist found for this cleaning schedule. The checklist may not have been created yet."
            }
            isLoadingChecklist = false
        }
    }
}

struct UrgentCleaningBanner: View {
    let reservations: [Reservation]
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedReservation: Reservation?
    @State private var showingScheduleView = false
    
    private var nextReservation: Reservation? {
        reservations.sorted { $0.checkIn < $1.checkIn }.first
    }
    
    var body: some View {
        NavigationLink(destination: CleaningsNeedingSchedulingView(viewModel: viewModel)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Urgent: Cleaning Needed")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let reservation = nextReservation {
                            let propertyName = viewModel.propertyName(for: reservation) ?? "Upcoming check-in"
                            Text("Next: \(propertyName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(reservation.checkIn, style: .date) at \(reservation.checkIn, style: .time) • in \(timeUntilCheckIn(reservation.checkIn))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Schedule")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                
                if reservations.count > 1 {
                    Text("+ \(reservations.count - 1) more within 24 hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func timeUntilCheckIn(_ checkIn: Date) -> String {
        let now = Date()
        let timeInterval = checkIn.timeIntervalSince(now)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
}

struct ScheduleCleaningButton: View {
    @State private var showingScheduleView = false
    
    var body: some View {
        Button(action: {
            showingScheduleView = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Schedule Cleaning")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingScheduleView) {
            ScheduleCleaningView(isPresentedAsSheet: true)
                .interactiveDismissDisabled(true)
        }
    }
}

