//
//  RunTailApp.swift
//  RunTail
//
//  Created by 이수민 on 5/5/25.
//

import SwiftUI
import Firebase // 꼭 추가해 주세요

@main
struct RunTailApp: App {
    // Firebase 초기화
    init() {
        FirebaseApp.configure()
        print("✅ Firebase 초기화 완료")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
