import SwiftUI
import Firebase
import FirebaseAuth

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 로고 또는 앱 이름
                    VStack(spacing: 8) {
                        Text("RunTail")
                            .font(.system(size: 45, weight: .bold))
                            .foregroundStyle(viewModel.themeGradient) // 그라데이션 적용
                        
                        Text("달리기를 더 즐겁게")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                    
                    // 로그인 폼 - Material 스타일로 개선
                    VStack(spacing: 24) {
                        // 이메일 입력 필드
                        VStack(alignment: .leading, spacing: 8) {
                            Text("이메일")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                                
                                TextField("이메일 주소 입력", text: $viewModel.email)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .padding(.vertical, 14)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // 비밀번호 입력 필드
                        VStack(alignment: .leading, spacing: 8) {
                            Text("비밀번호")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                                
                                SecureField("비밀번호 입력", text: $viewModel.password)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 14)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // 로그인 버튼 - 그라데이션 적용 및 스타일 개선
                        Button(action: viewModel.login) {
                            ZStack {
                                Capsule()
                                    .fill(viewModel.themeGradient)
                                    .frame(height: 56)
                                    .shadow(color: viewModel.themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .foregroundColor(.white)
                                        .scaleEffect(1.2)
                                } else {
                                    Text("로그인")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .disabled(viewModel.isLoading)
                        
                        // 로그인 메시지 - 스타일 개선
                        if !viewModel.loginMessage.isEmpty {
                            HStack {
                                if viewModel.isLoginSuccessful {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                
                                Text(viewModel.loginMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(viewModel.isLoginSuccessful ? .green : .red)
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .transition(.opacity)
                        }
                    }
                    .padding(24)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // 앱 버전 정보
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        Text("버전 1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding(.bottom, 16)
                }
                .animation(.spring(response: 0.3), value: viewModel.loginMessage)
                
                // NavigationLink를 사용하여 로그인 성공 시 MapView로 이동
                NavigationLink(
                    destination: MapView()
                        .navigationBarBackButtonHidden(true)
                        .navigationBarHidden(true),
                    isActive: $viewModel.isLoggedIn,
                    label: { EmptyView() }
                )
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // 앱이 시작될 때 이미 로그인되어 있는지 확인
            viewModel.checkExistingUser()
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
