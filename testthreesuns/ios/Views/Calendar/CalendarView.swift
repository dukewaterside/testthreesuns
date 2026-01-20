import SwiftUI

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Calendar Type", selection: $selectedTab) {
                    Text("Stays").tag(0)
                    Text("Cleaning").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    ReservationsCalendarView(selectedDate: $selectedDate)
                } else {
                    CleaningCalendarView(selectedDate: $selectedDate)
                }
            }
            .navigationTitle("Calendar")
        }
    }
}

struct ReservationsCalendarView: View {
    @Binding var selectedDate: Date
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedProperty: Property?
    
    var filteredReservations: [Reservation] {
        if let property = selectedProperty {
            return viewModel.reservations.filter { $0.propertyId == property.id }
        }
        return viewModel.reservations
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Property Filter - Button Style (Stacked)
                if !viewModel.properties.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter by Property")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        // Use LazyVGrid for better layout with 3 columns
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            Button(action: {
                                selectedProperty = nil
                            }) {
                                Text("All")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedProperty == nil ? .brandPrimary : Color(.systemGray5))
                                    .foregroundColor(selectedProperty == nil ? .white : .primary)
                                    .cornerRadius(10)
                            }
                            
                            ForEach(viewModel.properties) { property in
                                Button(action: {
                                    selectedProperty = property
                                }) {
                                    Text(property.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedProperty?.id == property.id ? .brandPrimary : Color(.systemGray5))
                                        .foregroundColor(selectedProperty?.id == property.id ? .white : .primary)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                
                MonthCalendarView(
                    selectedDate: $selectedDate,
                    reservations: filteredReservations,
                    cleaningSchedules: nil,
                    onDateSelected: { date in
                        selectedDate = date
                    }
                )
                
                ReservationsForDateView(date: selectedDate, reservations: filteredReservations, viewModel: viewModel)
            }
            .padding()
        }
        .task {
            await viewModel.loadProperties()
            await viewModel.loadReservations()
        }
    }
}

struct CleaningCalendarView: View {
    @Binding var selectedDate: Date
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedProperty: Property?
    
    var filteredCleanings: [CleaningSchedule] {
        if let property = selectedProperty {
            return viewModel.cleaningSchedules.filter { $0.propertyId == property.id }
        }
        return viewModel.cleaningSchedules
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Property Filter - Button Style (Stacked)
                if !viewModel.properties.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter by Property")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        // Use LazyVGrid for better layout with 3 columns
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            Button(action: {
                                selectedProperty = nil
                            }) {
                                Text("All")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedProperty == nil ? .brandPrimary : Color(.systemGray5))
                                    .foregroundColor(selectedProperty == nil ? .white : .primary)
                                    .cornerRadius(10)
                            }
                            
                            ForEach(viewModel.properties) { property in
                                Button(action: {
                                    selectedProperty = property
                                }) {
                                    Text(property.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedProperty?.id == property.id ? .brandPrimary : Color(.systemGray5))
                                        .foregroundColor(selectedProperty?.id == property.id ? .white : .primary)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                
                MonthCalendarView(
                    selectedDate: $selectedDate,
                    reservations: nil,
                    cleaningSchedules: filteredCleanings,
                    onDateSelected: { date in
                        selectedDate = date
                    }
                )
                
                CleaningsForDateView(
                    date: selectedDate,
                    cleanings: filteredCleanings,
                    propertyNameMap: Dictionary(uniqueKeysWithValues: viewModel.properties.map { ($0.id, $0.name) })
                )
            }
            .padding()
        }
        .task {
            await viewModel.loadProperties()
            await viewModel.loadCleaningSchedules()
        }
    }
}

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let reservations: [Reservation]?
    let cleaningSchedules: [CleaningSchedule]?
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { changeMonth(-1) }) {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedDate))
                    .font(.headline)
                
                Spacer()
                
                Button(action: { changeMonth(1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            
            CalendarGridView(
                selectedDate: $selectedDate,
                reservations: reservations,
                cleaningSchedules: cleaningSchedules,
                onDateSelected: onDateSelected
            )
        }
    }
    
    private func changeMonth(_ direction: Int) {
        if let newDate = calendar.date(byAdding: .month, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let reservations: [Reservation]?
    let cleaningSchedules: [CleaningSchedule]?
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                    let reservationInfo = hasReservation(on: date)
                    CalendarDayView(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isCheckIn: reservationInfo.isCheckIn,
                        isCheckOut: reservationInfo.isCheckOut,
                        isDuringStay: reservationInfo.isDuringStay,
                        hasCleaning: hasCleaning(on: date),
                        onTap: {
                            selectedDate = date
                            onDateSelected(date)
                        }
                    )
                }
            }
        }
    }
    
    private func daysInMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let firstDay = calendar.dateInterval(of: .month, for: selectedDate)?.start else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date] = []
        
        for _ in 0..<firstWeekday {
            days.append(Date.distantPast)
        }
        
        var currentDate = firstDay
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private func hasReservation(on date: Date) -> (isCheckIn: Bool, isCheckOut: Bool, isDuringStay: Bool) {
        guard let reservations = reservations else { return (false, false, false) }
        var isCheckIn = false
        var isCheckOut = false
        var isDuringStay = false
        
        let dateStartOfDay = calendar.startOfDay(for: date)
        
        for reservation in reservations {
            let checkInStart = calendar.startOfDay(for: reservation.checkIn)
            let checkOutStart = calendar.startOfDay(for: reservation.checkOut)
            
            if calendar.isDate(date, inSameDayAs: reservation.checkIn) {
                isCheckIn = true
            }
            if calendar.isDate(date, inSameDayAs: reservation.checkOut) {
                isCheckOut = true
            }
            // Check if date is during the stay (between check-in and check-out, exclusive)
            if dateStartOfDay > checkInStart && dateStartOfDay < checkOutStart {
                isDuringStay = true
            }
        }
        
        return (isCheckIn, isCheckOut, isDuringStay)
    }
    
    private func hasCleaning(on date: Date) -> Bool {
        guard let cleaningSchedules = cleaningSchedules else { return false }
        return cleaningSchedules.contains { schedule in
            calendar.isDate(date, inSameDayAs: schedule.scheduledStart)
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isCheckIn: Bool
    let isCheckOut: Bool
    let isDuringStay: Bool
    let hasCleaning: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        if date == Date.distantPast {
            Color.clear
        } else {
            Button(action: onTap) {
                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    // Show dots for reservation status
                    // Style guide colors: Green = check in, Orange/Red = check out, Purple = scheduled, Blue = active stay
                    if isCheckIn || isCheckOut || isDuringStay || hasCleaning {
                        HStack(spacing: 2) {
                            if isCheckIn {
                                Circle()
                                    .fill(Color.checkInColor)
                                    .frame(width: 4, height: 4)
                            }
                            if isDuringStay {
                                Circle()
                                    .fill(Color.brandPrimary)
                                    .frame(width: 4, height: 4)
                            }
                            if isCheckOut {
                                Circle()
                                    .fill(Color.checkOutColor)
                                    .frame(width: 4, height: 4)
                            }
                            if hasCleaning {
                                Circle()
                                    .fill(Color.scheduledColor)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.brandPrimary : Color.clear)
                .cornerRadius(8)
            }
        }
    }
}

struct ReservationsForDateView: View {
    let date: Date
    let reservations: [Reservation]
    @ObservedObject var viewModel: CalendarViewModel
    
    private let calendar = Calendar.current
    
    var reservationsForDate: [Reservation] {
        reservations.filter { reservation in
            calendar.isDate(date, inSameDayAs: reservation.checkIn) ||
            calendar.isDate(date, inSameDayAs: reservation.checkOut) ||
            (reservation.checkIn <= date && reservation.checkOut >= date)
        }
    }
    
    private func reservationStatus(for reservation: Reservation) -> (isCheckIn: Bool, isCheckOut: Bool, isDuringStay: Bool) {
        let isCheckIn = calendar.isDate(date, inSameDayAs: reservation.checkIn)
        let isCheckOut = calendar.isDate(date, inSameDayAs: reservation.checkOut)
        
        // Check if date is during the stay (between check-in and check-out, exclusive)
        let dateStartOfDay = calendar.startOfDay(for: date)
        let checkInStart = calendar.startOfDay(for: reservation.checkIn)
        let checkOutStart = calendar.startOfDay(for: reservation.checkOut)
        let isDuringStay = dateStartOfDay > checkInStart && dateStartOfDay < checkOutStart
        
        return (isCheckIn, isCheckOut, isDuringStay)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reservations for \(date, style: .date)")
                    .font(.headline)
                Spacer()
            }
            
            if reservationsForDate.isEmpty {
                Text("No reservations")
                    .foregroundColor(.secondary)
            } else {
                ForEach(reservationsForDate) { reservation in
                    let status = reservationStatus(for: reservation)
                    NavigationLink(destination: ActiveReservationDetailView(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))) {
                        ReservationCardWithStatus(
                            reservation: reservation,
                            propertyName: viewModel.propertyName(for: reservation),
                            isCheckIn: status.isCheckIn,
                            isCheckOut: status.isCheckOut,
                            isDuringStay: status.isDuringStay
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ReservationCardWithStatus: View {
    let reservation: Reservation
    let propertyName: String?
    let isCheckIn: Bool
    let isCheckOut: Bool
    let isDuringStay: Bool
    
    var statusColor: Color {
        // Style guide colors: Orange/Red = check out, Green = check in, Blue = active stay
        if isCheckOut { return .checkOutColor }
        if isCheckIn { return .checkInColor }
        if isDuringStay { return .brandPrimary }
        return .gray
    }
    
    var statusBackground: Color {
        if isCheckOut { return .checkOutBackground }
        if isCheckIn { return .checkInBackground }
        if isDuringStay { return .brandPrimary.opacity(0.1) }
        return .gray.opacity(0.1)
    }
    
    var statusText: String {
        if isCheckIn { return "Check-in" }
        if isCheckOut { return "Check-out" }
        if isDuringStay { return "Active Stay" }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(propertyName ?? reservation.guestName)
                    .font(.headline)
                Spacer()
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusBackground)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check-in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(reservation.checkIn, style: .date)
                            .font(.subheadline)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(reservation.checkIn, style: .time)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check-out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(reservation.checkOut, style: .date)
                            .font(.subheadline)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(reservation.checkOut, style: .time)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct CleaningsForDateView: View {
    let date: Date
    let cleanings: [CleaningSchedule]
    let propertyNameMap: [UUID: String]
    
    private let calendar = Calendar.current
    
    var cleaningsForDate: [CleaningSchedule] {
        cleanings.filter { cleaning in
            calendar.isDate(date, inSameDayAs: cleaning.scheduledStart)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleanings for \(date, style: .date)")
                .font(.headline)
            
            if cleaningsForDate.isEmpty {
                Text("No cleanings scheduled")
                    .foregroundColor(.secondary)
            } else {
                ForEach(cleaningsForDate) { cleaning in
                    CleaningScheduleCard(
                        cleaning: cleaning,
                        propertyName: propertyNameMap[cleaning.propertyId]
                    )
                }
            }
        }
    }
}
