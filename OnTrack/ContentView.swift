//
//  ContentView.swift
//  OnTrack
//
//  Created by Matthew blake on 16/3/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var authViewModel = AuthViewModel()
    @State private var isLaunching = true
    @State private var isAttemptingBiometric = false
    @State private var showBiometricEnrollment = false
    @State private var pendingEmail = ""
    @State private var pendingPassword = ""

    var body: some View {
        Group {
            if isLaunching {
                LaunchScreenView(onComplete: {
                    isLaunching = false
                    tryBiometricIfEnabled()
                })
            } else if isAttemptingBiometric {
                // Dark holding screen — prevents SignInView from flashing before Face ID resolves
                Color(red: 0.06, green: 0.12, blue: 0.15)
                    .ignoresSafeArea()
            } else if appState.currentUser != nil {
                if appState.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                SignInView()
            }
        }
        .sheet(isPresented: $showBiometricEnrollment) {
            BiometricEnrollmentSheet(
                biometricType: BiometricAuthManager.shared.biometricType,
                onEnable: {
                    authViewModel.enableBiometric(email: pendingEmail, password: pendingPassword)
                    showBiometricEnrollment = false
                },
                onSkip: {
                    showBiometricEnrollment = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .biometricEnrollmentNeeded)) { notification in
            let alreadyShown = UserDefaults.standard.bool(forKey: "biometric_prompt_shown")
            let bio = BiometricAuthManager.shared
            guard bio.isBiometricAvailable, !bio.isEnabled, !alreadyShown else { return }
            guard
                let email = notification.userInfo?["email"] as? String,
                let password = notification.userInfo?["password"] as? String
            else { return }
            pendingEmail = email
            pendingPassword = password
            UserDefaults.standard.set(true, forKey: "biometric_prompt_shown")
            showBiometricEnrollment = true
        }
    }

    private func tryBiometricIfEnabled() {
        let bio = BiometricAuthManager.shared
        guard bio.isEnabled, bio.loadCredentials() != nil else { return }
        isAttemptingBiometric = true
        Task {
            await authViewModel.signInWithBiometric(appState: appState)
            isAttemptingBiometric = false
        }
    }
}

// MARK: - Biometric Enrollment Sheet

struct BiometricEnrollmentSheet: View {
    let biometricType: String
    let onEnable: () -> Void
    let onSkip: () -> Void

    private let background    = Color(red: 0.06, green: 0.12, blue: 0.15)
    private let gradientStart = Color(red: 0.08, green: 0.35, blue: 0.45)
    private let gradientEnd   = Color(red: 0.15, green: 0.55, blue: 0.38)

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: biometricType == "Face ID" ? "faceid" : "touchid")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(colors: [gradientStart, gradientEnd],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text("Enable \(biometricType)?")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("Sign in faster next time using \(biometricType).")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(action: onEnable) {
                    Text("Enable \(biometricType)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(
                            LinearGradient(colors: [gradientStart, gradientEnd],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Not Now", action: onSkip)
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.subheadline)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
    }
}
