import SwiftUI
import UIKit
import Supabase
import PostgREST

struct MaintenanceDetailView: View {
    let report: MaintenanceReport
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MaintenanceViewModel()
    @State private var isUpdating = false
    @State private var currentReport: MaintenanceReport
    
    init(report: MaintenanceReport) {
        self.report = report
        _currentReport = State(initialValue: report)
    }
    
    var canUpdateStatus: Bool {
        // Owners and property managers can update maintenance report status
        let role = authViewModel.userProfile?.role
        return role == .owner || role == .propertyManager
    }
    
    var propertyName: String? {
        viewModel.propertyName(for: report.propertyId)
    }
    
    var reporterName: String? {
        viewModel.reporterName(for: report.reporterId)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary Card (Header)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentReport.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let propertyName = propertyName {
                                Text(propertyName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Status Badge
                        HStack(spacing: 4) {
                            Image(systemName: currentReport.status == .reported ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(currentReport.status == .reported ? Color(.systemGray4) : Color.green)
                            Text(currentReport.status == .reported ? "Not Repaired" : "Completed")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(currentReport.status == .reported ? Color(.systemGray4) : Color.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(currentReport.status == .reported ? Color(.systemGray6) : Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // Details Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 16) {
                        if let location = currentReport.location {
                            DetailRow(label: "Location", value: location)
                        }
                        
                        if let reporterName = reporterName {
                            DetailRow(label: "Reported By", value: reporterName)
                        }
                        
                        if let createdAt = currentReport.createdAt {
                            DetailRow(label: "Reported Date", value: formatDate(createdAt))
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Description Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(currentReport.description)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Photos Section
                if let photos = currentReport.photos, !photos.isEmpty {
                    PhotosSection(photos: photos)
                }
                
                // Resolved Button (for owners only, only show if not already resolved)
                if canUpdateStatus && currentReport.status == .reported {
                    Button(action: {
                        markAsResolved()
                    }) {
                        HStack(spacing: 8) {
                            if isUpdating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Marking as Resolved...")
                                    .font(.headline)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Resolved?")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUpdating ? Color.brandPrimary.opacity(0.7) : Color.brandPrimary)
                        .cornerRadius(12)
                    }
                    .disabled(isUpdating)
                }
            }
            .padding()
        }
        .navigationTitle("Maintenance Report Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func markAsResolved() {
        isUpdating = true
        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                
                let updateData: [String: AnyCodable] = [
                    "status": AnyCodable("resolved"),
                    "resolved_at": AnyCodable(formatter.string(from: Date()))
                ]
                
                try await SupabaseService.shared.supabase
                    .from("maintenance_reports")
                    .update(updateData)
                    .eq("id", value: currentReport.id)
                    .execute()
                
                // Reload the report from database to reflect the change
                await viewModel.loadReports()
                if let updatedReport = viewModel.reports.first(where: { $0.id == currentReport.id }) {
                    await MainActor.run {
                        currentReport = updatedReport
                        isUpdating = false
                    }
                    
                    // Success - no haptic needed
                } else {
                    await MainActor.run {
                        isUpdating = false
                    }
                }
            } catch {
                print("Error updating status: \(error)")
                await MainActor.run {
                    isUpdating = false
                }
                
                // Error - no haptic needed
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct PhotosSection: View {
    let photos: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photos, id: \.self) { photoUrl in
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 200, height: 200)
                        .clipped()
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

