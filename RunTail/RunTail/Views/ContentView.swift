//
//  ContentView.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//
import SwiftUI
import MapKit
import Firebase  // 이 부분이 누락됨
import FirebaseAuth  // 이 부분도 추가
import FirebaseFirestore
import Combine



struct ContentView: View {
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoggedIn {
                    MapView()
                } else {
                    LoginView()
                }
            }
        }
        .onAppear {
            // 기존 로그인 확인
            isLoggedIn = Auth.auth().currentUser != nil
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
