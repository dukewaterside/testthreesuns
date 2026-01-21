import SwiftUI
import PhotosUI
import UIKit
import Supabase
import PostgREST
import Storage

struct CreateMaintenanceReportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = MaintenanceViewModel()
    
    let showCancelButton: Bool
    
    @State private var selectedProperty: Property?
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var severity: MaintenanceReport.Severity = .medium
    @State private var reportType: MaintenanceReport.ReportType = .maintenance
    @State private var photoData: [Data] = []
    @State private var isSubmitting = false
    
    @State private var showingPhotoSourceDialog = false
    @State private var showingLibraryPicker = false
    @State private var showingCameraPicker = false
    @State private var showingCameraUnavailableAlert = false
    
    init(showCancelButton: Bool = true) {
        self.showCancelButton = showCancelButton
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    Picker("Property", selection: $selectedProperty) {
                        Text("Select property").tag(nil as Property?)
                        ForEach(viewModel.properties) { property in
                            Text(property.displayName).tag(property as Property?)
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
                    Button {
                        showingPhotoSourceDialog = true
                    } label: {
                        Label("Add Photos", systemImage: "photo")
                    }
                    .confirmationDialog("Add Photos", isPresented: $showingPhotoSourceDialog, titleVisibility: .visible) {
                        Button("Choose from Library") {
                            showingLibraryPicker = true
                        }
                        
                        Button("Take Photo") {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showingCameraPicker = true
                            } else {
                                showingCameraUnavailableAlert = true
                            }
                        }
                        
                        Button("Cancel", role: .cancel) {}
                    }
                    .sheet(isPresented: $showingLibraryPicker) {
                        PhotoLibraryPicker(isPresented: $showingLibraryPicker, selectionLimit: 10) { selectedData in
                            // Mirror existing behavior: library selection replaces the current set
                            photoData = selectedData
                        }
                    }
                    .fullScreenCover(isPresented: $showingCameraPicker) {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            CameraPhotoPicker(isPresented: $showingCameraPicker) { capturedData in
                                // Camera adds a single photo (up to the same 10 photo limit)
                                guard photoData.count < 10 else { return }
                                photoData.append(capturedData)
                            }
                        }
                    }
                    .alert("Camera Unavailable", isPresented: $showingCameraUnavailableAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("This device doesn’t have a camera available.")
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
                if showCancelButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
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

private struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let selectionLimit: Int
    let onComplete: ([Data]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = selectionLimit
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onComplete: onComplete)
    }
    
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding private var isPresented: Bool
        private let onComplete: ([Data]) -> Void
        
        init(isPresented: Binding<Bool>, onComplete: @escaping ([Data]) -> Void) {
            _isPresented = isPresented
            self.onComplete = onComplete
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            isPresented = false
            guard !results.isEmpty else {
                onComplete([])
                return
            }
            
            let group = DispatchGroup()
            var dataByIndex = Array<Data?>(repeating: nil, count: results.count)
            
            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage else { return }
                    
                    // Normalize to JPEG so the uploaded .jpg extension is correct
                    if let jpeg = image.jpegData(compressionQuality: 0.85) {
                        dataByIndex[index] = jpeg
                    } else if let png = image.pngData() {
                        dataByIndex[index] = png
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.onComplete(dataByIndex.compactMap { $0 })
            }
        }
    }
}

private struct CameraPhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPhoto: (Data) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.view.backgroundColor = .black
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPhoto: onPhoto)
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var isPresented: Bool
        private let onPhoto: (Data) -> Void
        
        init(isPresented: Binding<Bool>, onPhoto: @escaping (Data) -> Void) {
            _isPresented = isPresented
            self.onPhoto = onPhoto
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            isPresented = false
            guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }
            
            if let jpeg = image.jpegData(compressionQuality: 0.85) {
                onPhoto(jpeg)
            } else if let png = image.pngData() {
                onPhoto(png)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented = false
        }
    }
}
