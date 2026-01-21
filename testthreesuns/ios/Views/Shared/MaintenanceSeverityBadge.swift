import SwiftUI

struct MaintenanceSeverityBadge: View {
    let severity: MaintenanceReport.Severity
    
    private var text: String {
        switch severity {
        case .urgent:
            return "URGENT"
        default:
            return severity.displayName
        }
    }
    
    private var foregroundColor: Color {
        switch severity {
        case .low:
            return .checkInColor
        case .medium:
            return .checkOutColor
        case .high, .urgent:
            return .repairedColor
        }
    }
    
    private var backgroundColor: Color {
        switch severity {
        case .low:
            return .checkInBackground
        case .medium:
            return .checkOutBackground
        case .high, .urgent:
            return .repairedBackground
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if severity == .urgent {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(foregroundColor)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(foregroundColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

