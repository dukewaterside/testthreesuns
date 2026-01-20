import SwiftUI
import UIKit

struct OwnerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Welcome Section with gradient background
                WelcomeSection(
                    firstName: authViewModel.userProfile?.firstName ?? "User",
                    role: authViewModel.userProfile?.role ?? .owner
                )
                
                // Content Section
                VStack(spacing: 20) {
                    // Quick Actions Section
                    QuickActionsSection(viewModel: viewModel)
                    
                    ActiveReservationsSection(viewModel: viewModel)
                    
                    OpenMaintenanceReportsSection(viewModel: viewModel)
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

struct WelcomeSection: View {
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

struct ActiveReservationsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var activeReservations: [Reservation] {
        viewModel.reservations.filter { $0.isActive }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Reservations")
                    .font(.headline)
                Spacer()
                NavigationLink("See All", destination: ActiveReservationsView())
                    .font(.subheadline)
                    .foregroundColor(.brandPrimary)
            }
            
            if activeReservations.isEmpty {
                Text("No active reservations")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(activeReservations.prefix(5)) { reservation in
                    NavigationLink(destination: ActiveReservationDetailView(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))) {
                        ReservationCard(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


struct OpenMaintenanceReportsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Open Maintenance Reports")
                    .font(.headline)
                Spacer()
                if !viewModel.openMaintenanceReports.isEmpty {
                    NavigationLink("See All", destination: MaintenanceReportsListView())
                        .font(.subheadline)
                        .foregroundColor(.brandPrimary)
                }
            }
            
            if viewModel.openMaintenanceReports.isEmpty {
                Text("No open maintenance reports")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.openMaintenanceReports.prefix(5)) { report in
                    NavigationLink(destination: MaintenanceDetailView(report: report)) {
                        MaintenanceReportCard(
                            report: report,
                            propertyName: viewModel.propertyName(for: report.propertyId),
                            reporterName: viewModel.reporterName(for: report.reporterId)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
