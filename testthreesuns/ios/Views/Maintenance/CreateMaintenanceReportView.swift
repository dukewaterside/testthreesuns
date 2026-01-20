import SwiftUI
import PhotosUI
import UIKit
import Supabase
import PostgREST
import Storage

struct CreateMaintenanceReportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = MaintenanceViewModel()
    
    @State private var selectedProperty: Property?
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var severity: MaintenanceReport.Severity = .medium
    @State private var reportType: MaintenanceReport.ReportType = .maintenance
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    Picker("Property", selection: $selectedProperty) {
                        Text("Select property").tag(nil as Property?)
                        ForEach(viewModel.properties) { property in
                            Text(property.name).tag(property as Property?)
                        }
                    }
                }
                
                Section("Report Details") {
                    TextField("Title", text: $title)
                    TextField("Location (e.g., Pool, Kitchen)", text: $location)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Severity", selection: $severity) {
                        ForEach([MaintenanceReport.Severity.low, .medium, .high, .urgent], id: \.self) { severity in
                            Text(severity.displayName).tag(severity)
                        }
                    }
                    
                    Picker("Type", selection: $reportType) {
                        Text("Maintenance").tag(MaintenanceReport.ReportType.maintenance)
                        Text("Damage").tag(MaintenanceReport.ReportType.damage)
                    }
                }
                
                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotos) { oldValue, newValue in
                        Task {
                            photoData = []
                            for item in newValue {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    photoData.append(data)
                                }
                            }
                        }
                    }
                    
                    if !photoData.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(photoData.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: photoData[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: submitReport) {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Submit Report")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting || selectedProperty == nil || title.isEmpty)
                }
            }
            .navigationTitle("New Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadProperties()
            }
        }
    }
    
    private func submitReport() {
        guard let property = selectedProperty else { return }
        
        isSubmitting = true
        
        Task {
            guard let session = try? await SupabaseService.shared.supabase.auth.session else {
                isSubmitting = false
                return
            }
            let userId = session.user.id
            do {
                var photoUrls: [String] = []
                
                for data in photoData {
                    let fileName = UUID().uuidString + ".jpg"
                    
                    // Upload to Supabase Storage using a path that includes user ID
                    let userPath = "\(userId.uuidString)/\(fileName)"
                    
                    // Upload to Supabase Storage
                    let _ = try await SupabaseService.shared.supabase.storage
                        .from("maintenance-photos")
                        .upload(userPath, data: data, options: FileOptions(upsert: false))
                    
                    // Get public URL
                    let publicUrl = try SupabaseService.shared.supabase.storage
                        .from("maintenance-photos")
                        .getPublicURL(path: userPath)
                    
                    photoUrls.append(publicUrl.absoluteString)
                }
                
                var reportData: [String: AnyCodable] = [
                    "property_id": AnyCodable(property.id.uuidString),
                    "reporter_id": AnyCodable(userId.uuidString),
                    "title": AnyCodable(title),
                    "description": AnyCodable(description),
                    "severity": AnyCodable(severity.rawValue),
                    "status": AnyCodable("reported"),
                    "photos": AnyCodable(photoUrls),
                    "report_type": AnyCodable(reportType.rawValue)
                ]
                
                if !location.isEmpty {
                    reportData["location"] = AnyCodable(location)
                }
                
                let _: MaintenanceReport = try await SupabaseService.shared.supabase
                    .from("maintenance_reports")
                    .insert(reportData)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error submitting report: \(error)")
            }
            
            await MainActor.run {
                isSubmitting = false
            }
        }
    }
}
