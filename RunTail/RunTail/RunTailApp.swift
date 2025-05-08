//
//  RunTailApp.swift
//  RunTail
//
//  Created by 이수민 on 5/5/25.
//

import SwiftUI
import Firebase

@main
struct RunTailApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
