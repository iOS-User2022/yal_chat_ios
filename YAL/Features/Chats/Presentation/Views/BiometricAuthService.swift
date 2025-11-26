//
//  BiometricAuthService.swift
//  YAL
//
//  Created by Priyanka Singhnath on 24/10/25.
//

import LocalAuthentication
import Foundation

final class BiometricAuthService {
    static let shared = BiometricAuthService()
    private init() {}

    /// Checks and performs biometric authentication (or fallback passcode) and returns true on success
    func authenticate(reason: String = "Authenticate to proceed") async -> Result<Bool, Error> {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var authError: NSError?
        // Use deviceOwnerAuthentication to allow passcode fallback, or deviceOwnerAuthenticationWithBiometrics for biometrics only
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                return .success(success)
            } catch {
                return .failure(error)
            }
        } else {
            // Biometrics not available or not set up
            return .failure(authError ?? NSError(domain: "BiometricAuth", code: -1, userInfo: nil))
        }
    }
}
