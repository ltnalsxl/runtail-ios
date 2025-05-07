//
//  LoginViewModel.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var loginMessage = ""
    @Published var isLoginSuccessful = false
    @Published var isLoggedIn = false

    private let allowedEmail = "fltnadls1011@gmail.com"

    func login() {
        guard email == allowedEmail else {
            loginMessage = "허용되지 않은 이메일입니다."
            isLoginSuccessful = false
            return
        }

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.loginMessage = "로그인 실패: \(error.localizedDescription)"
                    self.isLoginSuccessful = false
                } else {
                    self.loginMessage = "로그인 성공!"
                    self.isLoginSuccessful = true
                    self.isLoggedIn = true
                    self.saveUserToFirestore()
                }
            }
        }
    }

    private func saveUserToFirestore() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).setData([
            "email": user.email ?? "",
            "uid": user.uid,
            "lastLogin": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Firestore 저장 실패: \(error.localizedDescription)")
            }
        }
    }
}
