import SwiftUI

struct MaintenanceReportsListView: View {
    @StateObject private var viewModel = MaintenanceViewModel()
    @State private var showingCreateReport = false
    @State private var selectedSeverity: MaintenanceReport.Severity?
    @State private var selectedPropertyId: UUID?
    @State private var showCompleted = false
    
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
    
    var pendingReports: [MaintenanceReport] {
        var reports = viewModel.reports.filter { $0.status == .reported }
        
        if let selectedSeverity {
            reports = reports.filter { $0.severity == selectedSeverity }
        }
        
        if let selectedPropertyId {
            reports = reports.filter { $0.propertyId == selectedPropertyId }
        }
        
        return reports.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity.priorityRank < rhs.severity.priorityRank
            }
            let lhsDate = lhs.createdAt ?? Date.distantPast
            let rhsDate = rhs.createdAt ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }
    
    var completedReports: [MaintenanceReport] {
        var reports = viewModel.reports.filter { $0.status == .resolved }
        
        if let selectedSeverity {
            reports = reports.filter { $0.severity == selectedSeverity }
        }
        
        if let selectedPropertyId {
            reports = reports.filter { $0.propertyId == selectedPropertyId }
        }
        
        let sorted = reports.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity.priorityRank < rhs.severity.priorityRank
            }
            let lhsDate = lhs.createdAt ?? Date.distantPast
            let rhsDate = rhs.createdAt ?? Date.distantPast
            return lhsDate > rhsDate
        }
        
        return Array(sorted.prefix(30))
    }
    
    var selectedPropertyName: String? {
        guard let selectedPropertyId = selectedPropertyId else { return nil }
        return viewModel.propertyName(for: selectedPropertyId)
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
                            // Filters
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Filters")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 12) {
                                    // Severity filter
                                    Menu {
                                        Button("All Severities") {
                                            selectedSeverity = nil
                                        }
                                        Divider()
                                        Button("Urgent") {
                                            selectedSeverity = .urgent
                                        }
                                        Button("High") {
                                            selectedSeverity = .high
                                        }
                                        Button("Medium") {
                                            selectedSeverity = .medium
                                        }
                                        Button("Low") {
                                            selectedSeverity = .low
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle")
                                            Text(selectedSeverity?.displayName ?? "Severity: All")
                                        }
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    
                                    // Property filter
                                    Menu {
                                        Button("All Properties") {
                                            selectedPropertyId = nil
                                        }
                                        Divider()
                                        ForEach(viewModel.properties) { property in
                                            Button(property.displayName) {
                                                selectedPropertyId = property.id
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "house")
                                            Text(selectedPropertyName.map { "Property: \($0)" } ?? "Property: All")
                                        }
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
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
                                            .padding(8)
                                            .background(severityBackground(for: report))
                                            .cornerRadius(16)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Repair Completed Section (within last month)
                            if !completedReports.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    DisclosureGroup(
                                        isExpanded: $showCompleted,
                                        content: {
                                            VStack(alignment: .leading, spacing: 16) {
                                                ForEach(completedReports) { report in
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
                                                    .padding(.horizontal)
                                                }
                                            }
                                            .padding(.top, 8)
                                        },
                                        label: {
                                            Text("Repair Completed")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .padding(.horizontal)
                                        }
                                    )
                                    .padding(.trailing)
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
