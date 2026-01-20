import SwiftUI
import Supabase
import PostgREST
import Functions

struct MaintenanceChecklistView: View {
    let checklist: Checklist
    var onCompleted: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var presentedSheet: PresentedSheet?
    @State private var nowDueTasks: [RecurringTask] = []
    @State private var upcomingTasks: [RecurringTask] = []
    @State private var isLoading = false
    @State private var completedItems: [String: Bool] = [:]
    @State private var items: [String: Bool] = [:]
    @State private var propertyStatus: Checklist.PropertyStatus = .ready
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    
    // Maintenance checklist structure
    private let maintenanceSections: [MaintenanceSection] = [
        MaintenanceSection(title: "Maintenance Items", items: [
            "Smoke detect Batteries",
            "Patio Furniture",
            "Terminex visit",
            "Order Hand Soap",
            "Exterior cameras check",
            "Change HVAC Filters",
            "Exterior window cleaning",
            "Steam clean couch & throw pillows",
            "Trash to curb",
            "Check welcome book"
        ])
    ]
    
    var allSelected: Bool {
        !items.isEmpty && items.values.allSatisfy { $0 }
    }
    
    enum PresentedSheet: Identifiable {
        case createReport
        case createTask
        
        var id: Int {
            switch self {
            case .createReport: return 0
            case .createTask: return 1
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                Button(action: {
                    let newValue = !allSelected
                    items = Dictionary(uniqueKeysWithValues: items.keys.map { ($0, newValue) })
                }) {
                    HStack {
                        Text(allSelected ? "Deselect All" : "Select All")
                            .foregroundColor(.brandPrimary)
                        Spacer()
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.brandPrimary)
                    }
                }
            }
            
            // Regular maintenance checklist items
            ForEach(maintenanceSections) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { items[item] ?? false },
                            set: { items[item] = $0 }
                        ))
                    }
                }
            }
            
            Section {
                Button(action: {
                    presentedSheet = .createReport
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "wrench.and.screwdriver")
                        Text("Create Damage Ticket")
                        Spacer()
                    }
                    .padding()
                    .background(Color.brandPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    presentedSheet = .createTask
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "repeat")
                        Text("Create Recurring Task")
                        Spacer()
                    }
                    .padding()
                    .background(Color.brandPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            Section("Recurring Tasks") {
                Text("Check items completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                MaintenanceTaskSection(
                    title: "Now Due",
                    staticTasks: [],
                    recurringTasks: nowDueTasks,
                    onTaskCompletion: {
                        Task {
                            await loadTasks()
                        }
                    }
                )
                
                MaintenanceTaskSection(
                    title: "Upcoming",
                    staticTasks: [],
                    recurringTasks: upcomingTasks,
                    onTaskCompletion: {
                        Task {
                            await loadTasks()
                        }
                    }
                )
            }
            
            Section("Property Status") {
                Picker("Final Status", selection: $propertyStatus) {
                    Text("Ready for Use").tag(Checklist.PropertyStatus.ready)
                    Text("Issues Found").tag(Checklist.PropertyStatus.issuesFound)
                }
            }
            
            Section {
                Button(action: submitChecklist) {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Complete Checklist")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || checklist.isCompleted)
            }
        }
        .navigationTitle("Maintenance Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .createReport:
                CreateMaintenanceReportView()
            case .createTask:
                CreateRecurringTaskView(
                    propertyId: checklist.propertyId,
                    onTaskCreated: {
                        Task {
                            await loadTasks()
                        }
                    }
                )
            }
        }
        .alert("Checklist Completed", isPresented: $showSuccessAlert) {
            Button("OK") {
                onCompleted?()
                dismiss()
            }
        } message: {
            Text("Maintenance checklist has been submitted successfully.")
        }
        .onAppear {
            loadItems()
        }
        .task {
            await loadTasks()
        }
        .refreshable {
            await loadTasks()
        }
    }
    
    private func loadItems() {
        // Initialize all items from all sections
        var allItems: [String: Bool] = [:]
        for section in maintenanceSections {
            for item in section.items {
                if let existingValue = checklist.items[item],
                   let bool = existingValue.value as? Bool {
                    allItems[item] = bool
                } else {
                    allItems[item] = false
                }
            }
        }
        items = allItems
    }
    
    private func submitChecklist() {
        isSubmitting = true
        
        Task {
            do {
                guard let _ = try? await SupabaseService.shared.supabase.auth.session else {
                    isSubmitting = false
                    return
                }
                
                let bodyDict: [String: AnyCodable] = [
                    "checklist_id": AnyCodable(checklist.id.uuidString),
                    "items": AnyCodable(items),
                    "property_status": AnyCodable(propertyStatus.rawValue)
                ]
                
                let _ = try await SupabaseService.shared.supabase.functions
                    .invoke("complete-manager-checklist", options: FunctionInvokeOptions(body: bodyDict))
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                print("Error submitting checklist: \(error)")
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
    
    private func loadTasks() async {
        isLoading = true
        do {
            let now = Date()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            
            let allTasks: [RecurringTask] = try await SupabaseService.shared.supabase
                .from("recurring_tasks")
                .select()
                .eq("property_id", value: checklist.propertyId)
                .execute()
                .value
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            nowDueTasks = allTasks.filter { task in
                guard let dueDateCodable = task.dueDate,
                      let dueDateString = dueDateCodable.value as? String,
                      let dueDate = dateFormatter.date(from: dueDateString) else { return false }
                let taskDate = calendar.startOfDay(for: dueDate)
                return taskDate <= today
            }.sorted { task1, task2 in
                let date1 = (task1.dueDate?.value as? String).flatMap { dateFormatter.date(from: $0) } ?? Date.distantPast
                let date2 = (task2.dueDate?.value as? String).flatMap { dateFormatter.date(from: $0) } ?? Date.distantPast
                return date1 < date2
            }
            
            upcomingTasks = allTasks.filter { task in
                guard let dueDateCodable = task.dueDate,
                      let dueDateString = dueDateCodable.value as? String,
                      let dueDate = dateFormatter.date(from: dueDateString) else { return false }
                let taskDate = calendar.startOfDay(for: dueDate)
                return taskDate > today
            }.sorted { task1, task2 in
                let date1 = (task1.dueDate?.value as? String).flatMap { dateFormatter.date(from: $0) } ?? Date.distantFuture
                let date2 = (task2.dueDate?.value as? String).flatMap { dateFormatter.date(from: $0) } ?? Date.distantFuture
                return date1 < date2
            }
            
        } catch {
            print("Error loading recurring tasks: \(error)")
        }
        isLoading = false
    }
    
}

struct MaintenanceSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
}

struct MaintenanceTaskSection: View {
    let title: String
    let staticTasks: [String] // Not used anymore, kept for compatibility
    let recurringTasks: [RecurringTask]
    @State private var completedItems: [String: Bool] = [:]
    var onTaskCompletion: (() -> Void)?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    private var displayDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
    
    private func formattedTaskName(for task: RecurringTask) -> String {
        var components: [String] = [task.title]
        
        // Add date
        if let dueDateString = task.dueDate?.value as? String,
           let dueDate = dateFormatter.date(from: dueDateString) {
            components.append("(\(displayDateFormatter.string(from: dueDate)))")
        }
        
        // Add frequency
        if let pattern = task.recurrencePattern, pattern != "one_time" {
            let frequencyDisplay = pattern.capitalized
            components.append("(\(frequencyDisplay))")
        }
        
        return components.joined(separator: " ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !recurringTasks.isEmpty {
                Text(title)
                    .font(.headline)
                    .padding(.top, 8)
                
                // Recurring tasks only (static tasks moved to regular checklist)
                ForEach(recurringTasks) { task in
                    RecurringTaskToggle(
                        task: task,
                        displayName: formattedTaskName(for: task),
                        isCompleted: Binding(
                            get: { 
                                // Check if task is completed in DB
                                if task.completedAt != nil {
                                    return true
                                }
                                return completedItems[task.id.uuidString] ?? false
                            },
                            set: { completedItems[task.id.uuidString] = $0 }
                        ),
                        onCompletion: onTaskCompletion
                    )
                }
            }
        }
        .onAppear {
            // Initialize all recurring tasks as false
            for task in recurringTasks {
                if completedItems[task.id.uuidString] == nil {
                    completedItems[task.id.uuidString] = false
                }
            }
        }
    }
}

struct RecurringTaskToggle: View {
    let task: RecurringTask
    let displayName: String
    @Binding var isCompleted: Bool
    @State private var isUpdating = false
    var onCompletion: (() -> Void)?
    
    var body: some View {
        Toggle(displayName, isOn: Binding(
            get: { isCompleted },
            set: { newValue in
                isCompleted = newValue
                // Toggle completion state (can check or uncheck)
                markAsComplete()
            }
        ))
        .disabled(isUpdating)
    }
    
    private func markAsComplete() {
        // Store the new value before async call
        let newCompletedValue = isCompleted
        isUpdating = true
        
        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                
                // Build update data conditionally
                // If completing, set completed_at to current timestamp
                // If uncompleting, set completed_at to NULL
                var updateData: [String: AnyCodable] = [:]
                
                if newCompletedValue {
                    // Completing the task - set completed_at to current time
                    updateData["completed_at"] = AnyCodable(formatter.string(from: Date()))
                } else {
                    // Uncompleting the task - set completed_at to NULL
                    // Use NSNull which AnyCodable can encode properly
                    updateData["completed_at"] = AnyCodable(NSNull())
                }
                
                try await SupabaseService.shared.supabase
                    .from("recurring_tasks")
                    .update(updateData)
                    .eq("id", value: task.id)
                    .execute()
                
                await MainActor.run {
                    isUpdating = false
                    onCompletion?()
                }
            } catch {
                print("Error toggling task: \(error)")
                await MainActor.run {
                    // Revert the toggle on error
                    isCompleted = !newCompletedValue
                    isUpdating = false
                }
            }
        }
    }
}

struct RecurringTaskRow: View {
    let task: RecurringTask
    @State private var isCompleting = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    private var formattedDueDate: String? {
        guard let dueDateString = task.dueDate?.value as? String,
              let dueDate = dateFormatter.date(from: dueDateString) else {
            return nil
        }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: dueDate)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                
                if let formattedDate = formattedDueDate {
                    Text("Due: \(formattedDate)")
                        .font(.caption)
                        .foregroundColor(.brandPrimary)
                }
            }
            
            Spacer()
            
            if !isCompleting {
                Button(action: {
                    markAsComplete()
                }) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                }
            } else {
                ProgressView()
            }
        }
    }
    
    private func markAsComplete() {
        isCompleting = true
        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                
                let updateData: [String: AnyCodable] = [
                    "completed_at": AnyCodable(formatter.string(from: Date()))
                ]
                
                try await SupabaseService.shared.supabase
                    .from("recurring_tasks")
                    .update(updateData)
                    .eq("id", value: task.id)
                    .execute()
                
                await MainActor.run {
                    isCompleting = false
                }
            } catch {
                print("Error completing task: \(error)")
                await MainActor.run {
                    isCompleting = false
                }
            }
        }
    }
}

struct RecurringTask: Identifiable, Codable {
    let id: UUID
    let propertyId: UUID
    let title: String
    let description: String?
    let dueDate: AnyCodable? // Store as AnyCodable to handle date string from DB
    let recurrencePattern: String?
    let nextDueDate: AnyCodable?
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case title
        case description
        case dueDate = "due_date"
        case recurrencePattern = "recurrence_pattern"
        case nextDueDate = "next_due_date"
        case completedAt = "completed_at"
    }
}

struct CreateRecurringTaskView: View {
    let propertyId: UUID
    var onTaskCreated: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var recurrencePattern = "one_time"
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                }
                
                Section("Due Date") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("Recurrence") {
                    Picker("Pattern", selection: $recurrencePattern) {
                        Text("One Time").tag("one_time")
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                        Text("Yearly").tag("yearly")
                    }
                }
                
                Section {
                    Button(action: createTask) {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Create Task")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting || title.isEmpty)
                }
            }
            .navigationTitle("New Recurring Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createTask() {
        isSubmitting = true
        Task {
            do {
                guard let session = try? await SupabaseService.shared.supabase.auth.session else {
                    isSubmitting = false
                    return
                }
                let userId = session.user.id
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(identifier: "UTC")
                
                let taskData: [String: AnyCodable] = [
                    "property_id": AnyCodable(propertyId.uuidString),
                    "title": AnyCodable(title),
                    "due_date": AnyCodable(dateFormatter.string(from: dueDate)),
                    "recurrence_pattern": AnyCodable(recurrencePattern),
                    "created_by": AnyCodable(userId.uuidString)
                ]
                
                try await SupabaseService.shared.supabase
                    .from("recurring_tasks")
                    .insert(taskData)
                    .execute()
                
                await MainActor.run {
                    onTaskCreated?()
                    dismiss()
                }
            } catch {
                print("Error creating recurring task: \(error)")
            }
            isSubmitting = false
        }
    }
}
