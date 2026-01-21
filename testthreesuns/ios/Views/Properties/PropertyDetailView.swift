import SwiftUI

struct PropertyDetailView: View {
    let property: Property
    @StateObject private var viewModel = PropertyDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PropertyHeader(property: property)
                
                CurrentReservationSection(viewModel: viewModel, propertyName: property.displayName)
                
                UpcomingReservationsSection(viewModel: viewModel, propertyName: property.displayName)
                
                CleaningSchedulesSection(viewModel: viewModel, propertyName: property.displayName)
                
                MaintenanceReportsSection(viewModel: viewModel, propertyName: property.displayName)
            }
            .padding()
        }
        .navigationTitle(property.displayName)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData(for: property.id)
        }
    }
}

struct PropertyHeader: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusBadge(status: property.status)
            
            Text(property.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CurrentReservationSection: View {
    @ObservedObject var viewModel: PropertyDetailViewModel
    let propertyName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Reservation")
                .font(.headline)
            
            if let reservation = viewModel.currentReservation {
                ReservationCard(reservation: reservation, propertyName: propertyName)
            } else {
                Text("No active reservation")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

struct UpcomingReservationsSection: View {
    @ObservedObject var viewModel: PropertyDetailViewModel
    let propertyName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Reservations")
                .font(.headline)
            
            if viewModel.upcomingReservations.isEmpty {
                Text("No upcoming reservations")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.upcomingReservations.prefix(5)) { reservation in
                    ReservationCard(reservation: reservation, propertyName: propertyName)
                }
            }
        }
    }
}

struct CleaningSchedulesSection: View {
    @ObservedObject var viewModel: PropertyDetailViewModel
    let propertyName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleaning Schedules")
                .font(.headline)
            
            if viewModel.cleaningSchedules.isEmpty {
                Text("No cleaning schedules")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.cleaningSchedules.prefix(5)) { schedule in
                    CleaningScheduleCard(cleaning: schedule, propertyName: propertyName)
                }
            }
        }
    }
}

struct MaintenanceReportsSection: View {
    @ObservedObject var viewModel: PropertyDetailViewModel
    let propertyName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Maintenance Reports")
                .font(.headline)
            
            if viewModel.maintenanceReports.isEmpty {
                Text("No maintenance reports")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.maintenanceReports.prefix(5)) { report in
                    MaintenanceReportCard(
                        report: report,
                        propertyName: propertyName,
                        reporterName: viewModel.reporterName(for: report.reporterId)
                    )
                }
            }
        }
    }
}
