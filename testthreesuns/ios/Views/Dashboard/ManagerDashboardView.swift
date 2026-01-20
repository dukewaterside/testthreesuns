import SwiftUI
import UIKit

struct ManagerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Welcome Section
                ManagerWelcomeSection(
                    firstName: authViewModel.userProfile?.firstName ?? "User",
                    role: authViewModel.userProfile?.role ?? .propertyManager
                )
                
                // Content Section
                VStack(spacing: 20) {
                    ManagerQuickActionsView(viewModel: viewModel)
                    
                    UpcomingReservationsWeekView(viewModel: viewModel)
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
        .onAppear {
            // Always refresh when returning to dashboard to catch new reservations/checklists
            Task {
                await viewModel.loadReservations()
                await viewModel.loadChecklists()
            }
        }
    }
}

struct ManagerWelcomeSection: View {
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

extension ManagerDashboardView {
    struct ManagerQuickActionsView: View {
        @ObservedObject var viewModel: DashboardViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    NavigationLink(destination: ManagerPropertyChecklistSelectionView()) {
                        ZStack(alignment: .topTrailing) {
                            QuickActionButton(icon: "checklist", title: "Checklists", color: .brandPrimary)
                            
                            // Badge for pending checklists
                            if viewModel.pendingChecklistsCount > 0 {
                                Text("\(viewModel.pendingChecklistsCount)")
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
                    
                    NavigationLink(destination: MaintenanceReportsListView()) {
                        ZStack(alignment: .topTrailing) {
                            QuickActionButton(icon: "wrench.and.screwdriver", title: "Maintenance Reports", color: .brandPrimary)
                            
                            // Badge for pending maintenance reports
                            if viewModel.pendingMaintenanceReportsCount > 0 {
                                Text("\(viewModel.pendingMaintenanceReportsCount)")
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
                    
                    NavigationLink(destination: CleaningScheduleView()) {
                        QuickActionButton(icon: "list.bullet.rectangle", title: "Cleaning Schedules", color: .brandPrimary)
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: ActiveReservationsView()) {
                        QuickActionButton(icon: "calendar.badge.clock", title: "Reservations", color: .brandPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct UpcomingReservationsWeekView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var upcomingReservations: [Reservation] {
        let now = Date()
        let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        // Show confirmed reservations that are either:
        // - Starting within the next week, OR
        // - Ending within the next week, OR  
        // - Currently active (checkIn <= now && checkOut >= now)
        return viewModel.reservations
            .filter { 
                $0.status == .confirmed && 
                ($0.checkIn <= oneWeekFromNow || $0.checkOut <= oneWeekFromNow || $0.isActive)
            }
            .sorted { $0.checkIn < $1.checkIn }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Reservations (This Week)")
                .font(.headline)
            
            if upcomingReservations.isEmpty {
                Text("No upcoming reservations this week")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(upcomingReservations) { reservation in
                    NavigationLink(destination: ActiveReservationDetailView(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))) {
                        ReservationCardWithChecklistButton(
                            reservation: reservation,
                            propertyName: viewModel.propertyName(for: reservation),
                            viewModel: viewModel
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ReservationCardWithChecklistButton: View {
    let reservation: Reservation
    let propertyName: String?
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedProperty: Property?
    
    var isPastCheckout: Bool {
        reservation.checkOut < Date()
    }
    
    var nextCheckIn: Reservation? {
        let now = Date()
        return viewModel.reservations
            .filter { $0.status == .confirmed && $0.propertyId == reservation.propertyId && $0.checkIn > now }
            .sorted { $0.checkIn < $1.checkIn }
            .first
    }
    
    var hasPendingChecklists: Bool {
        // Check if there are any pending checklists for this reservation
        viewModel.checklists.contains { 
            $0.reservationId == reservation.id && 
            !$0.isCompleted &&
            ($0.checklistType == .inspection || $0.checklistType == .supplies || $0.checklistType == .maintenance)
        }
    }
    
    var allChecklistsCompleted: Bool {
        // Check if all checklists are completed
        let relevantChecklists = viewModel.checklists.filter { 
            $0.reservationId == reservation.id &&
            ($0.checklistType == .inspection || $0.checklistType == .supplies || $0.checklistType == .maintenance)
        }
        return !relevantChecklists.isEmpty && relevantChecklists.allSatisfy { $0.isCompleted }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReservationCard(reservation: reservation, propertyName: propertyName)
            
            // Show Complete Checklist button after checkout
            if isPastCheckout {
                if hasPendingChecklists {
                    VStack(alignment: .leading, spacing: 8) {
                        if let nextCheckIn = nextCheckIn {
                            Text("Deadline: Next check-in on \(nextCheckIn.checkIn, style: .date) at \(nextCheckIn.checkIn, style: .time)")
                                .font(.caption)
                                .foregroundColor(.brandPrimary)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            // Ensure we have the property loaded before presenting the sheet
                            if let property = viewModel.properties.first(where: { $0.id == reservation.propertyId }) {
                                selectedProperty = property
                            } else {
                                Task {
                                    // Load data if needed, then try again
                                    await viewModel.loadData()
                                    if let property = viewModel.properties.first(where: { $0.id == reservation.propertyId }) {
                                        selectedProperty = property
                                    }
                                }
                            }
                        }) {
                            Text("Complete Checklist")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brandPrimary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                } else if allChecklistsCompleted {
                    // All checklists completed
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All Checklists Completed")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(item: $selectedProperty) { property in
            ManagerChecklistTypesView(
                property: property,
                checklists: viewModel.checklists.filter { $0.propertyId == property.id },
                onChecklistCompleted: {
                    Task {
                        await viewModel.loadData()
                    }
                }
            )
            .interactiveDismissDisabled(true)
        }
        .onAppear {
            // Load checklists when view appears
            Task {
                await viewModel.loadData()
            }
        }
    }
}


