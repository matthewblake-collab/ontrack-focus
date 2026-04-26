import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var viewModel = AuthViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSignUp = false

    private let gradientStart = Color(red: 0.08, green: 0.35, blue: 0.45)
    private let gradientEnd   = Color(red: 0.15, green: 0.55, blue: 0.38)
    private let background    = Color(red: 0.06, green: 0.12, blue: 0.15)
    private let fieldFill     = Color(red: 0.1, green: 0.18, blue: 0.22)

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top 40% — logo
                    VStack(spacing: 0) {
                        Spacer()

                        ZStack {
                            Ellipse()
                                .fill(Color(red: 0.15, green: 0.55, blue: 0.38).opacity(0.15))
                                .frame(width: 220, height: 220)
                                .blur(radius: 60)

                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [gradientStart, gradientEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 55, height: 70)
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                                .rotationEffect(.degrees(-12))
                                .opacity(0.95)

                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [gradientStart, gradientEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 55, height: 70)
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                                .rotationEffect(.degrees(0))
                                .opacity(1.0)

                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [gradientStart, gradientEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 55, height: 70)
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                                .rotationEffect(.degrees(12))
                                .opacity(0.85)
                        }
                        .frame(width: 90, height: 90)

                        Spacer().frame(height: 24)

                        Text("OnTrack")
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(.white)

                        Spacer().frame(height: 10)

                        LinearGradient(
                            colors: [gradientStart, gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 80, height: 2)
                        .clipShape(Capsule())

                        Spacer().frame(height: 10)

                        Text("Consistency starts with OnTrack")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()
                    }
                    .frame(maxHeight: .infinity)

                    // Bottom 60% — form
                    VStack(spacing: 16) {
                        // Email field
                        ZStack(alignment: .leading) {
                            if viewModel.email.isEmpty {
                                Text("Email")
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.horizontal, 14)
                            }
                            TextField("", text: $viewModel.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .foregroundStyle(.white)
                                .tint(.white)
                                .padding(14)
                        }
                        .background(fieldFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Password field
                        ZStack(alignment: .leading) {
                            if viewModel.password.isEmpty {
                                Text("Password")
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.horizontal, 14)
                            }
                            SecureField("", text: $viewModel.password)
                                .foregroundStyle(.white)
                                .tint(.white)
                                .padding(14)
                        }
                        .background(fieldFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Error message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundStyle(.yellow)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        // Sign In button
                        Button {
                            Task {
                                await viewModel.signIn(appState: appState)
                            }
                        } label: {
                            ZStack {
                                if viewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [gradientStart, gradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(viewModel.isLoading)

                        // Face ID / Touch ID fallback (shown only when biometric is enrolled)
                        if BiometricAuthManager.shared.isEnabled {
                            Button {
                                Task {
                                    await viewModel.signInWithBiometric(appState: appState)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: BiometricAuthManager.shared.biometricType == "Face ID" ? "faceid" : "touchid")
                                    Text("Use \(BiometricAuthManager.shared.biometricType)")
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.white.opacity(0.8))
                                .font(.subheadline)
                            }
                            .disabled(viewModel.isLoading)
                        }

                        // "or" divider
                        HStack(spacing: 12) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(.white.opacity(0.2))
                            Text("or")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(.white.opacity(0.2))
                        }

                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = viewModel.prepareAppleSignIn()
                        } onCompletion: { result in
                            Task {
                                await viewModel.signInWithApple(result: result, appState: appState)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(10)
                        .disabled(viewModel.isLoading)

                        // Sign Up link
                        Button("Don't have an account? Sign Up") {
                            showSignUp = true
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.subheadline)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}
