//
//  ContactsView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct ContactsView: View {
    @StateObject private var viewModel: ContactListViewModel
    @State private var selectedFilter: ContactFilter = .all
    @State private var searchText: String = ""
    @State private var showAlert: Bool = false

    init() {
        let viewModel = DIContainer.shared.container.resolve(ContactListViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SearchBarView(placeholder: "Search numbers, names & more", text: $searchText)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                Spacer().frame(height: 20)
                
                TabFiltersView(filters: [ContactFilter.all], selectedFilter: $selectedFilter)
                
                Group {
                    switch viewModel.accessStatus {
                    case .unknown:
                        Spacer()
                        ProgressView()
                        Spacer()
                        
                    case .granted:
                        ContactSectionedList(
                            sections: viewModel.filteredSections(for: searchText)
                        )
                        .background(Design.Color.tabHighlight.opacity(0.12))
                        
                    case .denied:
                        VStack {
                            Spacer()
                            Text("Contacts permission denied.")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                    case .restricted:
                        VStack {
                            Spacer()
                            Text("Contacts access is restricted.")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .background(Design.Color.chatBackground)
            .onAppear {
                viewModel.startContactSync()  // Automatically fetch when the view appears
            }
            .onChange(of: viewModel.accessStatus) { status in
                switch status {
                case .denied:
                    viewModel.showAlertForDeniedPermission()
                    showAlert = true
                case .restricted:
                    viewModel.showAlertForRestrictedAccess()
                    showAlert = true
                default:
                    break
                }
            }
            
            if showAlert, let alertModel = viewModel.alertModel {
                AlertView(model: alertModel) {
                    showAlert = false
                }
            }
        }
    }
}
