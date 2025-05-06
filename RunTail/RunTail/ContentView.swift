import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var loginMessage = ""
    @State private var isLoginSuccessful = false
    @State private var user: FirebaseAuth.User? = nil
    @State private var isLoading = false
    @State private var isLoggedIn = false // 로그인 상태를 추적하는 변수
    @Environment(\.colorScheme) var colorScheme

    // 테스트 계정 이메일만 허용
    let allowedEmail = "fltnadls1011@gmail.com"
    
    // 앱 테마 색상 - 그라데이션 적용을 위한 수정
    let themeColor = Color(red: 89/255, green: 86/255, blue: 214/255) // #5956D6 (퍼플)
    
    // UI 요소에 적용할 그라데이션
    let themeGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 89/255, green: 86/255, blue: 214/255), // #5956D6 (퍼플)
            Color(red: 0/255, green: 122/255, blue: 255/255)  // #007AFF (블루)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
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
                            .foregroundStyle(themeGradient) // 그라데이션 적용
                        
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
                                
                                TextField("이메일 주소 입력", text: $email)
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
                                
                                SecureField("비밀번호 입력", text: $password)
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
                        Button(action: loginUser) {
                            ZStack {
                                Capsule()
                                    .fill(themeGradient)
                                    .frame(height: 56)
                                    .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                if isLoading {
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
                        .disabled(isLoading)
                        
                        // 로그인 메시지 - 스타일 개선
                        if !loginMessage.isEmpty {
                            HStack {
                                if isLoginSuccessful {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                
                                Text(loginMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(isLoginSuccessful ? .green : .red)
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
                .animation(.spring(response: 0.3), value: loginMessage)
                
                // NavigationLink를 사용하여 로그인 성공 시 MapView로 이동
                NavigationLink(
                    destination: MapView()
                        .navigationBarBackButtonHidden(true)
                        .navigationBarHidden(true),
                    isActive: $isLoggedIn,
                    label: { EmptyView() }
                )
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // 앱이 시작될 때 이미 로그인되어 있는지 확인
            if let currentUser = Auth.auth().currentUser {
                self.user = currentUser
                self.isLoggedIn = true
            }
        }
    }

    // Firebase 로그인 처리
    func loginUser() {
        isLoading = true
        
        // 키보드 숨기기
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // 이메일이 테스트 계정과 일치하는지 확인
        if email == allowedEmail {
            Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
                withAnimation {
                    isLoading = false
                    
                    if let error = error {
                        self.loginMessage = "로그인 실패: \(error.localizedDescription)"
                        self.isLoginSuccessful = false
                    } else {
                        self.loginMessage = "로그인 성공!"
                        self.isLoginSuccessful = true
                        self.user = result?.user
                        self.saveUserToFirestore {
                            // 로그인 성공 및 데이터 저장 후 MapView로 이동
                            // 약간의 지연을 주어 성공 메시지를 볼 수 있게 함
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation {
                                    self.isLoggedIn = true
                                }
                            }
                        }
                    }
                }
            }
        } else {
            withAnimation {
                isLoading = false
                self.loginMessage = "로그인 실패: 승인되지 않은 이메일"
                self.isLoginSuccessful = false
            }
        }
    }

    // Firestore에 사용자 데이터 저장
    func saveUserToFirestore(completion: @escaping () -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion()
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).setData([
            "email": user.email ?? "",
            "uid": user.uid,
            "lastLogin": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error adding document: \(error)")
            } else {
                print("User data saved to Firestore")
            }
            completion()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
