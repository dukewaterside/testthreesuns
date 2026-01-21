import SwiftUI

struct PropertiesListView: View {
    @StateObject private var viewModel = PropertiesViewModel()
    @State private var searchText = ""
    @State private var selectedStatus: Property.PropertyStatus?
    
    var filteredProperties: [Property] {
        var filtered = viewModel.properties
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchAndFilterBar(searchText: $searchText, selectedStatus: $selectedStatus)
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredProperties.isEmpty {
                    EmptyStateView(message: "No properties found")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredProperties) { property in
                                NavigationLink(destination: PropertyDetailView(property: property)) {
                                    PropertyRow(property: property)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Properties")
            .refreshable {
                await viewModel.loadProperties()
            }
            .task {
                await viewModel.loadProperties()
            }
        }
    }
}

struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedStatus: Property.PropertyStatus?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search properties", text: $searchText)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: selectedStatus == nil) {
                        selectedStatus = nil
                    }
                    
                    ForEach([Property.PropertyStatus.occupied, .needsCleaning, .vacantReady, .needsMaintenance], id: \.self) { status in
                        FilterChip(title: status.displayName, isSelected: selectedStatus == status) {
                            selectedStatus = status
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

struct PropertyRow: View {
    let property: Property
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(property.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(property.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            StatusBadge(status: property.status)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
