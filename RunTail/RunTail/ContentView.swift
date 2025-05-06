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

    // 테스트 계정 이메일만 허용
    let allowedEmail = "fltnadls1011@gmail.com"
    
    // 앱 테마 색상
    let themeColor = Color(red: 0/255, green: 179/255, blue: 149/255)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 로고 또는 앱 이름
                    Text("RunTail")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeColor)
                        .padding(.bottom, 20)
                    
                    // 로그인 폼
                    VStack(spacing: 15) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.gray)
                            TextField("Email", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.gray)
                            SecureField("Password", text: $password)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        // 로그인 버튼
                        Button(action: loginUser) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .foregroundColor(.white)
                            } else {
                                Text("Login")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(themeColor)
                        .cornerRadius(10)
                        .disabled(isLoading)
                        
                        // 로그인 메시지
                        if !loginMessage.isEmpty {
                            Text(loginMessage)
                                .foregroundColor(isLoginSuccessful ? .green : .red)
                                .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                
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
        
        // 이메일이 테스트 계정과 일치하는지 확인
        if email == allowedEmail {
            Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
                isLoading = false
                
                if let error = error {
                    self.loginMessage = "Login Failed: \(error.localizedDescription)"
                    self.isLoginSuccessful = false
                } else {
                    self.loginMessage = "Login Successful"
                    self.isLoginSuccessful = true
                    self.user = result?.user
                    self.saveUserToFirestore {
                        // 로그인 성공 및 데이터 저장 후 MapView로 이동
                        self.isLoggedIn = true
                    }
                }
            }
        } else {
            isLoading = false
            self.loginMessage = "Login Failed: Unauthorized email"
            self.isLoginSuccessful = false
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
            "uid": user.uid
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
