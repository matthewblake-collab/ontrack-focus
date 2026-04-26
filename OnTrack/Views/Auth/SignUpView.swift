import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @State private var viewModel = AuthViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            themeManager.currentTheme.gradient
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)

                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Join OnTrack and stay on top of your sessions")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("Display Name", text: $viewModel.displayName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await viewModel.signUp(appState: appState)
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(themeManager.currentTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundStyle(themeManager.currentTheme.primary)
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(viewModel.isLoading)

                    // "or" divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.white.opacity(0.2))
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.white.opacity(0.2))
                    }

                    // Sign up with Apple
                    SignInWithAppleButton(.signUp) { request in
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
                }
                .padding(.horizontal)

                Button("Already have an account? Sign In") {
                    dismiss()
                }
                .foregroundStyle(.white.opacity(0.9))
                .font(.subheadline)

                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }
}
