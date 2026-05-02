//
//  EditProfileView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var showDatePicker = false
    @State private var selectedDate: Date = ISO8601DateFormatter().date(from: "1992-03-10T00:00:00Z") ?? Date()
    
    private let genders = [Constants.male.localized, Constants.female.localized, Constants.other.localized]
    @ObservedObject var viewModel: ProfileViewModel

    @Binding var showSuccessPopup: Bool
    @Environment(\.presentationMode) var presentationMode

    init(viewModel: ProfileViewModel, showSuccessPopup: Binding<Bool>) {
        self.viewModel = viewModel
        self._showSuccessPopup = showSuccessPopup
    }
    
    var body: some View {
        VStack(spacing: UIConstants.NavBar.zeroSpacing) {
            // Drag Handle
            Capsule()
                .fill(Color.white.opacity(UIConstants.Opacity.medium))
                .frame(width: UIConstants.Layout.EditProfile.DragHandle.width, height: UIConstants.Layout.EditProfile.DragHandle.height)
                .padding(.top, UIConstants.Layout.EditProfile.DragHandle.topPadding)
            
            Spacer().frame(height: UIConstants.Layout.EditProfile.Spacing.headerTopPadding)
            
            // Header with close button
            HStack {
                Spacer()
                
                Text(Constants.editProfileTitle.localized)
                    .font(Design.TextStyle.editProfileTitle)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(.close)
                        .font(Design.TextStyle.editProfileCloseIcon)
                        .foregroundColor(.white)
                        .frame(
                            width: UIConstants.Layout.EditProfile.CloseIcon.size,
                            height: UIConstants.Layout.EditProfile.CloseIcon.size
                        )
                }
                .padding(.trailing, UIConstants.NavBar.zeroSpacing)
            }
            .padding(.horizontal, UIConstants.Layout.EditProfile.Spacing.headerHPadding)
            
            Spacer().frame(height: UIConstants.Layout.EditProfile.Spacing.belowHeader)
            
            // Scrollable form content
            ScrollView(showsIndicators: false) {
                VStack(spacing:  UIConstants.Layout.EditProfile.Spacing.sectionGap) {
                    editTextField(
                        title: Constants.about.localized,
                        text: Binding(
                            get: { viewModel.editableProfile?.about ?? "" },
                            set: { viewModel.editableProfile?.about = $0 }
                        )
                    )
                    
                    editTextField(
                        title: Constants.name.localized,
                        text: Binding(
                            get: { viewModel.editableProfile?.name ?? "" },
                            set: { viewModel.editableProfile?.name = $0 }
                        )
                    )
                    
                    genderPicker(
                        title: Constants.gender.localized,
                        selection: Binding(
                            get: { viewModel.editableProfile?.gender ?? "" },
                            set: { viewModel.editableProfile?.gender = $0 }
                        )
                    )
                    
                    editTextField(
                        title: Constants.email.localized,
                        text: Binding(
                            get: { viewModel.editableProfile?.email ?? "" },
                            set: { viewModel.editableProfile?.email = $0 }
                        )
                    )
                    
                    datePickerField(
                        title: Constants.dateOfBirth.localized,
                        selectedDate: $selectedDate,
                        dateString: Binding(
                            get: { viewModel.editableProfile?.dob ?? "" },
                            set: { viewModel.editableProfile?.dob = $0 }
                        ),
                        showPicker: $showDatePicker
                    )
                    
                    editTextField(
                        title: Constants.profession.localized,
                        text: Binding(
                            get: { viewModel.editableProfile?.profession ?? "" },
                            set: { viewModel.editableProfile?.profession = $0 }
                        )
                    )
                }
                .padding(.horizontal, UIConstants.Layout.screenPadding)
                .padding(.bottom, UIConstants.Layout.screenPadding)
            }
            
            Spacer().frame(height: UIConstants.Layout.EditProfile.Spacing.belowHeader)
            
            // Action Buttons
            HStack(spacing: UIConstants.Layout.EditProfile.Button.horizontalGap) {
                Button(action: {
                    dismiss()
                }) {
                    Text(Constants.editProfileCancelButton.localized)
                        .font(Design.TextStyle.editProfileButton)
                        .foregroundColor(Design.Color.mediumGray)
                        .frame(
                            width: UIConstants.Layout.EditProfile.Button.width,
                            height: UIConstants.Layout.EditProfile.Button.height
                        )
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: UIConstants.Layout.EditProfile.Button.cornerRadius)
                                .stroke(Design.Color.medium_gray, lineWidth: UIConstants.Layout.EditProfile.Button.borderWidth)
                        )
                }
                
                Button(action: {
                    viewModel.updateProfileIfNeeded() { success in
                        showSuccessPopup = true
                        self.viewModel.showAlertForDeniedPermission(success: success)
                        presentationMode.wrappedValue.dismiss()
                    }
                    dismiss()
                }) {
                    Text(Constants.editProfileSaveButton.localized)
                        .font(Design.TextStyle.editProfileButton)
                        .foregroundColor(.white)
                        .frame(
                            width: UIConstants.Layout.EditProfile.Button.width,
                            height: UIConstants.Layout.EditProfile.Button.height
                        )
                        .background(Design.Color.appGradient)
                        .cornerRadius(UIConstants.Layout.EditProfile.Button.cornerRadius)
                }
            }
            Spacer().frame(height: UIConstants.Layout.EditProfile.Spacing.sheetBottomPadding)
                .padding(.horizontal, UIConstants.Layout.EditProfile.Spacing.headerHPadding)
                .padding(.bottom, -UIConstants.Layout.EditProfile.Button.height / 2)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: UIConstants.Layout.EditProfile.backgroundColor))
        .shadow(color: Color.black.opacity(UIConstants.Opacity.medium / 2), radius: 20, x: 0, y: -5)
        .ignoresSafeArea(.keyboard)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Reusable Fields
    
    @ViewBuilder
    private func editTextField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Layout.EditProfile.Field.labelSpacing) {
            Text(title)
                .font(Design.TextStyle.editProfileFieldLabel)
                .foregroundColor(Design.Color.primaryTextColor)
            
            TextField(Constants.editProfileInputPlaceholder.localized, text: text)
                .font(Design.TextStyle.editProfileFieldText)
                .foregroundColor(Design.Color.secondryTextColor)
                .frame(width: UIConstants.Layout.EditProfile.Field.width,
                       height: UIConstants.Layout.EditProfile.Field.height)
                .padding(.horizontal, UIConstants.Layout.EditProfile.Field.horizontalPadding)
                .background(Design.Color.backgroundColor)
                .cornerRadius(UIConstants.Layout.Radius.small)
        }
    }
    
    @ViewBuilder
    private func genderPicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Layout.EditProfile.Field.labelSpacing) {
            Text(title)
                .font(Design.Font.regular(12))
                .foregroundColor(Design.Color.primaryTextColor)
            
            Menu {
                ForEach(genders, id: \.self) { gender in
                    Button(gender) { selection.wrappedValue = gender }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? Constants.selectGender.localized : selection.wrappedValue)
                        .font(Design.TextStyle.editProfileChevronIcon)
                        .foregroundColor(Design.Color.secondryTextColor)
                    
                    Spacer()
                    
                    Image(systemName: UIConstants.Symbols.chevronDown)
                        .font(Design.TextStyle.editProfileChevronIcon)
                        .foregroundColor(.white.opacity(UIConstants.Opacity.medium))
                }
                .frame(
                    width: UIConstants.Layout.EditProfile.Field.width,
                    height: UIConstants.Layout.EditProfile.Field.height
                )
                .padding(.horizontal, UIConstants.Layout.EditProfile.Field.horizontalPadding)
                .background(Color(hex: UIConstants.Layout.EditProfile.genderBackgroundColor))
                .cornerRadius(UIConstants.Layout.Radius.small)
            }
        }
    }

    @ViewBuilder
    private func datePickerField(title: String, selectedDate: Binding<Date>, dateString: Binding<String>, showPicker: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Layout.EditProfile.Field.labelSpacing) {
            Text(title)
                .font(Design.TextStyle.editProfileFieldLabel)
                .foregroundColor(Design.Color.primaryTextColor)

            Button {
                showPicker.wrappedValue = true
            } label: {
                HStack {
                    Text(dateString.wrappedValue.formattedDateFromISO())
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.secondryTextColor)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(Design.TextStyle.editProfileCalendarIcon)
                        .foregroundColor(.white.opacity(UIConstants.Opacity.medium))
                }
                .frame(
                    width: UIConstants.Layout.EditProfile.Field.width,
                    height: UIConstants.Layout.EditProfile.Field.height
                )
                .padding(.horizontal, UIConstants.Layout.EditProfile.Field.horizontalPadding)
                .background(Design.Color.backgroundColor)
                .cornerRadius(UIConstants.Layout.Radius.small)
            }
            .sheet(isPresented: showPicker) {
                VStack {
                    let today = Date()
                    let hundredYearsAgo = Calendar.current.date(byAdding: .year, value: -100, to: today)!
                    DatePicker(Constants.editProfileDatePlaceholder.localized,
                               selection: selectedDate,
                               in: hundredYearsAgo...today,
                               displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()

                    Button(Constants.editProfileDoneButton.localized) {
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
    }
}
