import SwiftUI

struct ReservationCard: View {
    let reservation: Reservation
    let propertyName: String?
    
    init(reservation: Reservation, propertyName: String? = nil) {
        self.reservation = reservation
        self.propertyName = propertyName
    }
    
    private var displayName: String {
        propertyName ?? reservation.guestName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(displayName)
                    .font(.headline)
                Spacer()
                
                if reservation.isActive {
                    Text("Check-in")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.checkInColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.checkInBackground)
                        .cornerRadius(8)
                } else if reservation.checkIn > Date() {
                    Text("Upcoming")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.upcomingColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.upcomingBackground)
                        .cornerRadius(8)
                } else if reservation.checkOut < Date() {
                    Text("Check-out")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.checkOutColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.checkOutBackground)
                        .cornerRadius(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(Color.checkInColor)
                        .font(.caption)
                    Text(reservation.checkIn, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("at")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(reservation.checkIn, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.circle.fill")
                        .foregroundColor(Color.checkOutColor)
                        .font(.caption)
                    Text(reservation.checkOut, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("at")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(reservation.checkOut, style: .time)
                        .font(.subheadline)
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
