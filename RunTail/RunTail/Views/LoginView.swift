//
//  LoginView.swift
//  RunTail
//
//  Updated on 5/10/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // 배경 색상
                Color.rtBackground
                    .ignoresSafeArea()
                
                // 상단 장식
                VStack {
                    Image("runningBackground") // 러닝 배경 이미지가 있으면 사용, 없으면 아래 그라데이션으로 대체
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 240)
                        .overlay(
                            LinearGradient.rtPrimaryGradient
                                .opacity(0.85)
                        )
                        .clipShape(RoundedShape(corners: [.bottomRight], radius: 80))
                    
                    Spacer()
                }
                .ignoresSafeArea()
                
                // 메인 콘텐츠
                VStack(spacing: 0) {
                    // 로고 영역
                    VStack(spacing: 8) {
                        // 앱 아이콘 (러닝 아이콘)
                        Image(systemName: "figure.run")
                            .font(.system(size: 56))
                            .foregroundStyle(LinearGradient.rtPrimaryGradient)
                            .padding(24)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: Color.rtPrimary.opacity(0.2), radius: 15, x: 0, y: 5)
                            )
                            .padding(.bottom, 16)
                        
                        // 앱 이름과 태그라인
                        Text("RunTail")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(LinearGradient.rtPrimaryGradient)
                        
                        Text("나만의 러닝 여정을 기록하세요")
                            .rtBodyLarge()
                            .foregroundColor(.gray)
                            .padding(.bottom, 40)
                    }
                    .padding(.top, 100)
                    
                    // 로그인 폼
                    VStack(spacing: 24) {
                        // 이메일 필드
                        TextFieldWithIcon(
                            text: $viewModel.email,
                            placeholder: "이메일 주소",
                            icon: "envelope.fill",
                            keyboardType: .emailAddress
                        )
                        
                        // 비밀번호 필드
                        SecureFieldWithIcon(
                            text: $viewModel.password,
                            placeholder: "비밀번호",
                            icon: "lock.fill"
                        )
                        
                        // 로그인 버튼
                        Button(action: viewModel.login) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.0)
                                } else {
                                    Text("로그인")
                                        .rtBodyLarge()
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                        }
                        .buttonStyle(RTPrimaryButtonStyle())
                        .disabled(viewModel.isLoading)
                        .padding(.top, 16)
                        
                        // 로그인 메시지
                        if !viewModel.loginMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.isLoginSuccessful ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(viewModel.isLoginSuccessful ? .rtSuccess : .rtError)
                                
                                Text(viewModel.loginMessage)
                                    .rtBody()
                                    .foregroundColor(viewModel.isLoginSuccessful ? .rtSuccess : .rtError)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                    .background(Color.rtCard)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // 앱 버전
                    Text("버전 1.0.0")
                        .rtBodySmall()
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.bottom, 20)
                }
                
                // 메인 화면으로 이동
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
            viewModel.checkExistingUser()
        }
    }
}

// MARK: - 커스텀 텍스트필드
struct TextFieldWithIcon: View {
    @Binding var text: String
    var placeholder: String
    var icon: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.rtPrimary)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .rtBodyLarge()
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.vertical, 14)
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .background(Color.white)
        )
    }
}

struct SecureFieldWithIcon: View {
    @Binding var text: String
    var placeholder: String
    var icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.rtPrimary)
                .frame(width: 24)
            
            SecureField(placeholder, text: $text)
                .rtBodyLarge()
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.vertical, 14)
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .background(Color.white)
        )
    }
}

// 커스텀 라운드 쉐이프 (하단 모서리만 둥글게)
struct RoundedShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
