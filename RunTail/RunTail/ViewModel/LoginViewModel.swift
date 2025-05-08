//
//  LoginViewModel.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

class LoginViewModel: ObservableObject {
    // 입력 필드
    @Published var email = ""
    @Published var password = ""
    
    // 상태 관리
    @Published var loginMessage = ""
    @Published var isLoginSuccessful = false
    @Published var isLoading = false
    @Published var isLoggedIn = false
    @Published var user: FirebaseAuth.User? = nil
    
    // 테스트 계정 이메일만 허용
    private let allowedEmail = "fltnadls1011@gmail.com"
    
    // 앱 테마 색상 및 그라데이션
    let themeColor = Color(red: 89/255, green: 86/255, blue: 214/255) // #5956D6 (퍼플)
    
    let themeGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 89/255, green: 86/255, blue: 214/255), // #5956D6 (퍼플)
            Color(red: 0/255, green: 122/255, blue: 255/255)  // #007AFF (블루)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Firebase 로그인 처리
    func login() {
        isLoading = true
        
        // 키보드 숨기기
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // 이메일이 테스트 계정과 일치하는지 확인
        if email == allowedEmail {
            Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
                withAnimation {
                    self.isLoading = false
                    
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
    private func saveUserToFirestore(completion: @escaping () -> Void) {
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
    
    // 앱 시작 시 로그인 상태 확인
    func checkExistingUser() {
        if let currentUser = Auth.auth().currentUser {
            self.user = currentUser
            self.isLoggedIn = true
        }
    }
}
