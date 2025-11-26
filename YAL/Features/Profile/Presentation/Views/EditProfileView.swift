//
//  EditProfileView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import PhotosUI

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var showDatePicker = false
    @State private var selectedDate: Date = ISO8601DateFormatter().date(from: "1992-03-10T00:00:00Z") ?? Date()

    private let genders = ["Male", "Female", "Other"]
    @ObservedObject var viewModel: ProfileViewModel

    @Binding var showSuccessPopup: Bool
    @Environment(\.presentationMode) var presentationMode

    init(viewModel: ProfileViewModel, showSuccessPopup: Binding<Bool>) {
        self.viewModel = viewModel
        self._showSuccessPopup = showSuccessPopup
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)

            // Drag Handle
            Capsule()
                .fill(Design.Color.black.opacity(0.2))
                .frame(width: 60, height: 4)
                .cornerRadius(2)
            
            Spacer().frame(height: 10)

            Spacer().frame(height: 20)

            // Title
            Text("Edit Profile")
                .font(Design.Font.bold(16))
                .foregroundColor(Design.Color.primaryText)

            Spacer().frame(height: 20)

            // Form Fields
            Group {
                editTextField(
                    title: "Name",
                    text: Binding(
                        get: { viewModel.editableProfile?.name ?? "" },
                        set: { viewModel.editableProfile?.name = $0 }
                    )
                )
                
                Spacer().frame(height: 12)
                
                genderPicker(
                    title: "Gender",
                    selection: Binding(
                        get: { viewModel.editableProfile?.gender ?? "" },
                        set: { viewModel.editableProfile?.gender = $0 }
                    )
                )
                
                Spacer().frame(height: 12)
                
                editTextField(
                    title: "Email",
                    text: Binding(
                        get: { viewModel.editableProfile?.email ?? "" },
                        set: { viewModel.editableProfile?.email = $0 }
                    )
                )
                
                Spacer().frame(height: 12)
                
                datePickerField(
                    title: "D.O.B.",
                    selectedDate: $selectedDate,
                    dateString: Binding(
                        get: { viewModel.editableProfile?.dob ?? "" },
                        set: { viewModel.editableProfile?.dob = $0 }
                    ),
                    showPicker: $showDatePicker
                )
                
                Spacer().frame(height: 12)
                
                editTextField(
                    title: "Profession",
                    text: Binding(
                        get: { viewModel.editableProfile?.profession ?? "" },
                        set: { viewModel.editableProfile?.profession = $0 }
                    )
                )
                
                Spacer().frame(height: 24)
            }

            Spacer().frame(height: 20)

            // Action Buttons
            HStack(spacing: 24) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()  // Let padding handle button height automatically
                        .background(Design.Color.lightGrayBackground)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .minimumScaleFactor(0.5)  // Ensures text scales down to fit if needed
                        .lineLimit(1)  // Prevents text wrapping
                }

                Button(action: {
                    viewModel.updateProfileIfNeeded() { success in
                        showSuccessPopup = true
                        self.viewModel.showAlertForDeniedPermission(success: success)
                        presentationMode.wrappedValue.dismiss()
                    }
                    dismiss()
                }) {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .padding()  // Let padding handle button height automatically
                        .background(Design.Color.appGradient)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .minimumScaleFactor(0.5)  // Ensures text scales down to fit if needed
                        .lineLimit(1)  // Prevents text wrapping
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Design.Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .ignoresSafeArea(.all)
    }

    // MARK: - Reusable Fields

    @ViewBuilder
    private func editTextField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Design.Font.regular(12))
                .foregroundColor(Design.Color.primaryText.opacity(0.6))
            TextField("", text: text)
                .padding()
                .foregroundColor(Design.Color.headingText.opacity(0.7))
                .font(Design.Font.regular(16))
                .background(Design.Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.Color.navy, lineWidth: 1))
        }
        .padding(.horizontal, 30)
    }

    @ViewBuilder
    private func genderPicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Design.Font.regular(12))
                .foregroundColor(Design.Color.primaryText.opacity(0.6))
            Menu {
                ForEach(genders, id: \.self) { gender in
                    Button(gender) { selection.wrappedValue = gender }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "Select Gender" : selection.wrappedValue)
                        .foregroundColor(Design.Color.headingText.opacity(0.7))
                        .font(Design.Font.regular(16))
                    
                    Spacer()
                    
                    Image("arrow-down")
                        .scaledToFit()
                }
                .padding()
                .background(Design.Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.Color.navy, lineWidth: 1))
            }
        }
        .padding(.horizontal, 30)
    }

    @ViewBuilder
    private func datePickerField(title: String, selectedDate: Binding<Date>, dateString: Binding<String>, showPicker: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Design.Font.regular(12))
                .foregroundColor(Design.Color.primaryText.opacity(0.6))

            Button {
                showPicker.wrappedValue = true
            } label: {
                HStack {
                    Text(dateString.wrappedValue.formattedDateFromISO())
                        .foregroundColor(Design.Color.headingText.opacity(0.7))
                        .font(Design.Font.regular(16))
                    Spacer()
                    Image("calendar")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Design.Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.Color.navy, lineWidth: 1))
            }
            .sheet(isPresented: showPicker) {
                VStack {
                    let today = Date()
                    let hundredYearsAgo = Calendar.current.date(byAdding: .year, value: -100, to: today)!
                    DatePicker("Select Date",
                               selection: selectedDate,
                               in: hundredYearsAgo...today,
                               displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()

                    Button("Done") {
                        // Format for showing nicely on UI
                        dateString.wrappedValue = dateString.wrappedValue.formattedDateFromISO()

                        // Format for saving to backend
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime] // = "yyyy-MM-dd'T'HH:mm:ssZ"

                        let isoDateString = isoFormatter.string(from: selectedDate.wrappedValue)
                        
                        viewModel.editableProfile?.dob = isoDateString // Send this to backend
                        
                        showPicker.wrappedValue = false
                    }
                    .padding()
                }
                .presentationDetents([.medium])
            }
        }
        .padding(.horizontal, 30)
    }

}



