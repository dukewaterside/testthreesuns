import SwiftUI

struct CleaningScheduleCard: View {
    let cleaning: CleaningSchedule
    let propertyName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(propertyName ?? "Unknown Property")
                    .font(.headline)
                Spacer()
                Text("Cleaning scheduled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.scheduledColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.scheduledBackground)
                    .cornerRadius(8)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(cleaning.scheduledStart, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(cleaning.scheduledStart, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let end = cleaning.scheduledEnd {
                    Text(" - ")
                        .foregroundColor(.secondary)
                    Text(end, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
