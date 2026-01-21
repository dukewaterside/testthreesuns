import SwiftUI

struct ReservationCard: View {
    let reservation: Reservation
    let propertyName: String?
    let cleaning: CleaningSchedule?
    let showCleaningStatus: Bool
    
    init(
        reservation: Reservation,
        propertyName: String? = nil,
        cleaning: CleaningSchedule? = nil,
        showCleaningStatus: Bool = false
    ) {
        self.reservation = reservation
        self.propertyName = propertyName
        self.cleaning = cleaning
        self.showCleaningStatus = showCleaningStatus
    }
    
    private var displayName: String {
        propertyName ?? reservation.guestName
    }
    
    private var now: Date {
        Date()
    }
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var checkInIsToday: Bool {
        calendar.isDateInToday(reservation.checkIn)
    }
    
    private var checkOutIsToday: Bool {
        calendar.isDateInToday(reservation.checkOut)
    }
    
    private var checkInIsTomorrowOrFuture: Bool {
        reservation.checkIn > now && !checkInIsToday
    }
    
    private var checkInHasPassed: Bool {
        reservation.checkIn <= now
    }
    
    private var checkOutHasPassed: Bool {
        reservation.checkOut <= now
    }
    
    private var checkInTimeHasPassed: Bool {
        reservation.checkIn <= now
    }
    
    private var checkOutTimeHasPassed: Bool {
        reservation.checkOut <= now
    }
    
    private enum ReservationStatus {
        case checkInToday // Check-in is today but hasn't happened yet
        case activeStay // Check-in has happened, checkout hasn't
        case activeStayCheckoutToday // Checkout is today but hasn't happened
        case upcoming // Check-in is tomorrow or future
        case past // Checkout has passed
    }
    
    private var status: ReservationStatus {
        if checkOutHasPassed {
            return .past
        } else if checkOutIsToday && !checkOutTimeHasPassed {
            return .activeStayCheckoutToday
        } else if checkInIsToday && !checkInTimeHasPassed {
            return .checkInToday
        } else if checkInHasPassed && !checkOutHasPassed {
            return .activeStay
        } else if checkInIsTomorrowOrFuture {
            return .upcoming
        } else {
            return .activeStay
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(displayName)
                    .font(.headline)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Primary status badge
                    switch status {
                    case .checkInToday:
                        Text("Check-in")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.checkInColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.checkInBackground)
                            .cornerRadius(8)
                    case .activeStay, .activeStayCheckoutToday:
                        Text("Active Stay")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(status == .activeStayCheckoutToday ? Color.checkOutColor : Color.inProgressColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(status == .activeStayCheckoutToday ? Color.checkOutBackground : Color.inProgressBackground)
                            .cornerRadius(8)
                    case .upcoming:
                        Text("Upcoming")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.upcomingColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.upcomingBackground)
                            .cornerRadius(8)
                    case .past:
                        Text("Check-out")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.checkOutColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.checkOutBackground)
                            .cornerRadius(8)
                    }
                    
                    // Secondary status badge for checkout today
                    if status == .activeStayCheckoutToday {
                        Text("Check out today")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(Color.checkOutColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.checkOutBackground.opacity(0.7))
                            .cornerRadius(6)
                    }
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
                
                if showCleaningStatus {
                    HStack(spacing: 8) {
                        if let cleaning {
                            Image(systemName: "bubbles.and.sparkles")
                                .foregroundColor(.primary)
                                .font(.caption)
                            Text("Cleaning: \(cleaning.scheduledStart, style: .date) at \(cleaning.scheduledStart, style: .time)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("No cleaning scheduled for this stay")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(cleaning == nil ? Color.orange.opacity(0.12) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(cleaning == nil ? Color.orange.opacity(0.6) : Color(.systemGray4), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Static function to get background color for wrapping
    static func backgroundColor(for reservation: Reservation) -> Color {
        let now = Date()
        let calendar = Calendar.current
        
        let checkInIsToday = calendar.isDateInToday(reservation.checkIn)
        let checkOutIsToday = calendar.isDateInToday(reservation.checkOut)
        let checkInHasPassed = reservation.checkIn <= now
        let checkOutHasPassed = reservation.checkOut <= now
        let checkInIsTomorrowOrFuture = reservation.checkIn > now && !checkInIsToday
        
        if checkOutHasPassed {
            return .checkOutBackground
        } else if checkOutIsToday && !checkOutHasPassed {
            return .checkOutBackground
        } else if checkInIsToday && !checkInHasPassed {
            return .checkInBackground
        } else if checkInHasPassed && !checkOutHasPassed {
            return .inProgressBackground
        } else if checkInIsTomorrowOrFuture {
            return .upcomingBackground
        } else {
            return .inProgressBackground
        }
    }
}
