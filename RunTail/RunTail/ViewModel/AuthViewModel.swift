//
//  AuthViewModel.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoggingOut: Bool = false
    @Published var showLogoutAlert: Bool = false
    
    private let firebaseService = FirebaseService.shared
    
    init() {
        // 현재 로그인 상태 확인
        isLoggedIn = Auth.auth().currentUser != nil
    }
    
    func logout() {
        isLoggingOut = true
        
        if firebaseService.logoutUser() {
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.isLoggingOut = false
            }
        } else {
            DispatchQueue.main.async {
                self.isLoggingOut = false
                // 에러 처리
            }
        }
    }
    
    func checkAuthState() {
        isLoggedIn = Auth.auth().currentUser != nil
    }
}
