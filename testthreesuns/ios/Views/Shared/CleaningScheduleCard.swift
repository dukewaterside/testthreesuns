import SwiftUI

struct CleaningScheduleCard: View {
    let cleaning: CleaningSchedule
    let propertyName: String?
    
    private var statusColor: Color {
        switch cleaning.status {
        case .scheduled:
            return .scheduledColor
        case .inProgress:
            return .inProgressColor
        case .completed:
            return .completedColor
        case .overdue:
            return .overdueColor
        }
    }
    
    private var statusBackground: Color {
        switch cleaning.status {
        case .scheduled:
            return .scheduledBackground
        case .inProgress:
            return .inProgressBackground
        case .completed:
            return .completedBackground
        case .overdue:
            return .overdueBackground
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(propertyName ?? "Unknown Property")
                    .font(.headline)
                Spacer()
                Text(cleaning.status.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusBackground)
                    .cornerRadius(8)
            }
            
            // Date row
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(cleaning.scheduledStart, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Time row - more prominent
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.subheadline)
                    .foregroundColor(statusColor)
                Text(cleaning.scheduledStart, style: .time)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let end = cleaning.scheduledEnd {
                    Text("–")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    Text(end, style: .time)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
