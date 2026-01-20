import SwiftUI

struct AvailableWindowCard: View {
    let window: AvailableCleaningWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(window.propertyName)
                .font(.headline)
            
            HStack {
                Text(window.windowStart, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                Text(window.windowEnd, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
