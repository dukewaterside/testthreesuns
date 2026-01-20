import SwiftUI
import UIKit

struct CleanerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Welcome Section
                CleanerWelcomeSection(
                    firstName: authViewModel.userProfile?.firstName ?? "User",
                    role: authViewModel.userProfile?.role ?? .cleaningStaff
                )
                
                // Content Section
                VStack(spacing: 20) {
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

struct CleanerWelcomeSection: View {
    let firstName: String
    let role: UserProfile.UserRole
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background gradient - using Primary Color 1 from style guide
            LinearGradient(
                colors: [.brandPrimary, .brandPrimary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(firstName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(role.displayName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 180)
        .padding(.top, 20)
        .padding(.bottom, 24)
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
                
                NavigationLink(destination: CleaningScheduleView()) {
                    QuickActionButton(icon: "list.bullet.rectangle", title: "Cleaning Schedule", color: .brandPrimary)
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
                    CleaningScheduleCard(
                        cleaning: cleaning,
                        propertyName: viewModel.propertyName(for: cleaning.propertyId)
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
            
            // Property Filter - Use LazyVGrid for better layout
            if !viewModel.properties.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Filter by Property")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
                                Text(property.name)
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
                    loadChecklistForCleaning()
                    showingChecklist = true
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
            if let checklist = checklist {
                CleaningChecklistView(checklist: checklist, cleaningSchedule: cleaning)
                    .interactiveDismissDisabled(true)
            } else {
                Text("Loading checklist...")
                    .interactiveDismissDisabled(true)
            }
        }
    }
    
    private func loadChecklistForCleaning() {
        // Find checklist associated with this cleaning's reservation or property
        if let reservationId = cleaning.reservationId {
            checklist = viewModel.checklists.first { $0.reservationId == reservationId && !$0.isCompleted }
        } else {
            // Find checklist for this property that's not completed
            checklist = viewModel.checklists.first { $0.propertyId == cleaning.propertyId && !$0.isCompleted }
        }
        
        // If no checklist found, create one or load from server
        if checklist == nil {
            Task {
                await viewModel.loadData()
                if let reservationId = cleaning.reservationId {
                    checklist = viewModel.checklists.first { $0.reservationId == reservationId && !$0.isCompleted }
                } else {
                    checklist = viewModel.checklists.first { $0.propertyId == cleaning.propertyId && !$0.isCompleted }
                }
            }
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
            ScheduleCleaningView()
                .interactiveDismissDisabled(true)
        }
    }
}

