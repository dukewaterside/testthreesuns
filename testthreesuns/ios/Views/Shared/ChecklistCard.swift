import SwiftUI

struct ChecklistCard: View {
    let checklist: Checklist
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text((checklist.checklistType ?? .inspection).displayName)
                    .font(.headline)
                
                if let status = checklist.propertyStatus {
                    Text(status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if checklist.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.brandPrimary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
