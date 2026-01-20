import SwiftUI

struct MaintenanceReportsListView: View {
    @StateObject private var viewModel = MaintenanceViewModel()
    @State private var showingCreateReport = false
    
    var pendingReports: [MaintenanceReport] {
        viewModel.reports.filter { $0.status == .reported }
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    var completedReports: [MaintenanceReport] {
        Array(viewModel.reports.filter { $0.status == .resolved }
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
            .prefix(30))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.reports.isEmpty {
                    EmptyStateView(message: "No maintenance reports")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Repair Pending Section
                            if !pendingReports.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Repair Pending")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal)
                                    
                                    ForEach(pendingReports) { report in
                                        NavigationLink(destination: MaintenanceDetailView(report: report)) {
                                            MaintenanceReportCard(
                                                report: report,
                                                propertyName: viewModel.propertyName(for: report.propertyId),
                                                reporterName: viewModel.reporterName(for: report.reporterId)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Repair Completed Section (within last month)
                            if !completedReports.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Repair Completed")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal)
                                    
                                    ForEach(completedReports) { report in
                                        NavigationLink(destination: MaintenanceDetailView(report: report)) {
                                            MaintenanceReportCard(
                                                report: report,
                                                propertyName: viewModel.propertyName(for: report.propertyId),
                                                reporterName: viewModel.reporterName(for: report.reporterId)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Maintenance Reports")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreateReport = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateReport) {
                CreateMaintenanceReportView()
                    .interactiveDismissDisabled(true)
            }
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
}
