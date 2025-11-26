//
//  CountryPickerView.swift
//  YAL
//
//  Created by Vishal Bhadade on 28/04/25.
//


import SwiftUI

struct CountryPickerView: View {
    @Binding var selectedCountry: Country?

    private let countries: [Country] = Country.allCountries.sorted { $0.name < $1.name }

    var body: some View {
        NavigationView {
            List(countries) { country in
                Button(action: {
                    selectedCountry = country
                }) {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                        Spacer()
                        Text(country.dialCode)
                            .foregroundColor(Design.Color.secondaryText)
                    }
                    .padding(.vertical, 10)
                }
                .listRowBackground(Design.Color.white) // Optional: custom row background
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.plain) // 👈 Very important for simple, clean scrolling List
            .background(Design.Color.white)
        }
    }
}
