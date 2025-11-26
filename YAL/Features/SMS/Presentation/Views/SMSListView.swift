//
//  SMSListView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI

enum SpamProtectionStatus: String {
    case initiated
    case configured
    case off
    
}

struct SMSListView: View {
    @EnvironmentObject var router: Router

    @State private var spamDetectionOn = false
    @State private var transactionAlertsOn = false
    @State private var smartInsightsOn = false
    @State private var showAlert = false  // To control showing the alert
    @State private var alertMessage = ""  // To set the message of the alert
    @State private var alertViewModel: AlertViewModel?
    @State private var showTutorial = false
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaInsets = geometry.safeAreaInsets
            ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer().frame(height: 61)
                            
                            Image("yal_chat_logo")
                                .resizable()
                                .frame(width: 120, height: 120)
                            
                            Spacer().frame(height: 32)
                            
                            Text("YAL.ai is synced with your messages app")
                                .font(Design.Font.bold(24))
                                .foregroundColor(Design.Color.primaryText)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer().frame(height: 12)
                            
                            Text("Helping you track inbox, notices, spams, and reports safely.")
                                .font(Design.Font.regular(16))
                                .foregroundColor(Design.Color.primaryText.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer().frame(height: 24)
                            
                            VStack(spacing: 12) {
                                featureToggleRow(title: "Spam Detection", isOn: $spamDetectionOn)
                                featureToggleRow(title: "Transaction Alerts", isOn: $transactionAlertsOn)
                                featureToggleRow(title: "Smart Insights", isOn: $smartInsightsOn)
                            }
                            
                            Spacer().frame(height: 32)
                            
                            Button(action: {
                                if isSettingEnabled() {
                                    if let url = URL(string: "messages://") {
                                        UIApplication.shared.open(url)
                                    }
                                } else {
                                    showTutorial.toggle()
                                }
                            }) {
                                Text(isSettingEnabled() ? "Open Messages" : "Enable Setting")
                                    .font(Design.Font.bold(16))
                                    .foregroundColor(Design.Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(Design.Color.appGradient)
                                    .cornerRadius(20)
                                    .shadow(radius: 6)
                                    .padding(.horizontal, 12.5)
                            }
                            
                            Spacer().frame(height: 76 + safeAreaInsets.bottom) // For bottom tab bar
                        }
                    }
                    .background(Design.Color.white)
                    .padding(.horizontal, 30)
                    .scrollIndicators(.hidden)
                }
                .background(Design.Color.white)
                .ignoresSafeArea(edges: .bottom)
                
                if showAlert {
                    let alertViewModel = AlertViewModel(title: "Important", subTitle: alertMessage, actions: [
                        AlertActionModel(title: "Enable Setting", style: .destructive, action: {
                            showTutorial.toggle()
                        }),
                        AlertActionModel(title: "Yes", style: .primary, action: {
                            enableFilters()
                        })
                    ])
                    AlertView(model: alertViewModel, onDismiss: {
                        showAlert = false
                    })
                }
            }
            .onAppear {
                checkAndShowAlert()
                NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                    // App has come to the foreground
                    print("App is now active!")
                    checkAndShowAlert()
                }
            }
            .onChange(of: UIApplication.shared.applicationState) { _ in
                if UIApplication.shared.applicationState == .active {
                    checkAndShowAlert()
                }
            }
            .sheet(isPresented: $showTutorial) {
                TutorialView(onDismiss: { shouldOpenSettings in
                    if shouldOpenSettings {
                        showTutorial.toggle()
                        openSettings()
                    }
                })
            }
        }
    }

    // Helper function to check status and show the alert
    private func checkAndShowAlert() {
        if let statusValue = Storage.get(for: .spamProtectionStatus, type: .userDefaults, as: String.self),
           let status = SpamProtectionStatus(rawValue: statusValue) {
            if status == .initiated {
                // show alert
                alertMessage = "Did you successfully enable YAL.ai for SMS filtering?"
                showAlert.toggle()
            } else if status == .configured {
                enableFilters()
            }
        }
    }
    
    private func featureToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Spacer().frame(width: 16)

            Text(title)
                .font(Design.Font.bold(16))
                .foregroundColor(Design.Color.primaryText)

            Spacer()

            // Image dynamically changing based on the toggle state
            Image(isOn.wrappedValue ? "checkbox-selected" : "checkbox")
                .resizable()
                .frame(width: 20, height: 20)
                
            Spacer().frame(width: 10)
            
            // Text dynamically changing based on the toggle state
            Text(isOn.wrappedValue ? "On" : "Off")
                .font(Design.Font.body)
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
            
            Spacer().frame(width: 16)
        }
        .padding()
        .background(Design.Color.appGradient.opacity(0.12))
        .cornerRadius(8)
    }

    // Helper function to check if all settings are enabled
    private func isSettingEnabled() -> Bool {
        return spamDetectionOn && transactionAlertsOn && smartInsightsOn
    }
    
    // Enable filters (called when user clicks "Yes" in alert)
    private func enableFilters() {
        spamDetectionOn = true
        transactionAlertsOn = true
        smartInsightsOn = true
        Storage.save(SpamProtectionStatus.configured.rawValue, for: .spamProtectionStatus, type: .userDefaults)
        print("Filters enabled successfully")
    }
    
    // Function to open the settings if the user clicks "No"
    private func openSettings() {
        Storage.save(SpamProtectionStatus.initiated.rawValue, for: .spamProtectionStatus, type: .userDefaults)

        if let settingsUrl = URL(string: "App-prefs:root") {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    SMSListView()
}
