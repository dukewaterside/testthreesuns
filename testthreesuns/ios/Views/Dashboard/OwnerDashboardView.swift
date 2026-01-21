import SwiftUI
import UIKit

struct OwnerDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Welcome Section with gradient background
                DashboardHeaderView(
                    firstName: authViewModel.userProfile?.firstName ?? "User",
                    role: authViewModel.userProfile?.role ?? .owner,
                    viewModel: viewModel
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
                        ReservationCard(
                            reservation: reservation,
                            propertyName: viewModel.propertyName(for: reservation),
                            cleaning: viewModel.cleaningForReservation(reservation),
                            showCleaningStatus: true
                        )
                        .padding(8)
                        .background(ReservationCard.backgroundColor(for: reservation))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


struct OpenMaintenanceReportsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    private func severityBackground(for report: MaintenanceReport) -> Color {
        // If completed, use green background to indicate it's done
        if report.status == .resolved {
            return .completedBackground
        }
        
        // Otherwise use severity-based color
        switch report.severity {
        case .low:
            return .checkInBackground
        case .medium:
            return .checkOutBackground
        case .high, .urgent:
            return .repairedBackground
        }
    }
    
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
                        .padding(8)
                        .background(severityBackground(for: report))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
