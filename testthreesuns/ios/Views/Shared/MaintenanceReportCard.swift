import SwiftUI

struct MaintenanceReportCard: View {
    let report: MaintenanceReport
    let propertyName: String?
    let reporterName: String?
    
    var statusDisplayText: String {
        report.status == .reported ? "Not Repaired" : "Completed"
    }
    
    var statusIcon: String {
        report.status == .reported ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
    }
    
    var statusColor: Color {
        report.status == .reported ? .repairedColor : .checkInColor
    }
    
    var statusBackground: Color {
        report.status == .reported ? .repairedBackground : .checkInBackground
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                // Title and Property
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let propertyName = propertyName {
                        Text(propertyName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status Badge
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    Text(statusDisplayText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusBackground)
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Navigation Arrow
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
