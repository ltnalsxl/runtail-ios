//
//  FirebaseService.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import MapKit

protocol FirebaseAuthProtocol {
    var currentUserEmail: String? { get }
    var currentUserId: String? { get }
    func signOut() throws
}

extension Auth: FirebaseAuthProtocol {
    var currentUserEmail: String? { currentUser?.email }
    var currentUserId: String? { currentUser?.uid }
}

class FirebaseService {
    static let shared = FirebaseService()

    private let auth: FirebaseAuthProtocol

    init(auth: FirebaseAuthProtocol = Auth.auth()) {
        self.auth = auth
    }
    
    // MARK: - 인증 관련
    
    func logoutUser() -> Bool {
        do {
            try auth.signOut()
            return true
        } catch {
            print("로그아웃 오류: \(error.localizedDescription)")
            return false
        }
    }

    func getCurrentUser() -> (id: String, email: String)? {
        if let id = auth.currentUserId, let email = auth.currentUserEmail {
            return (id: id, email: email)
        }
        return nil
    }
    
    // MARK: - 데이터 로드
    
    func loadUserData(userId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Error getting user data: \(error)")
                completion(false)
                return
            }
            
            guard let document = document, document.exists else {
                print("User document does not exist")
                completion(false)
                return
            }
            
            // 사용자 데이터 처리
            completion(true)
        }
    }
    
    func loadRecentRuns(userId: String, limit: Int = 5, completion: @escaping ([Run], Double, Double, Double) -> Void) {
        let db = Firestore.firestore()
        db.collection("runs")
            .whereField("userId", isEqualTo: userId)
            .order(by: "runAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting runs: \(error)")
                    completion([], 0, 0, 0)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No runs found")
                    completion([], 0, 0, 0)
                    return
                }
                
                // 러닝 데이터 파싱
                var runs: [Run] = []
                var totalDist: Double = 0
                var weeklyDist: Double = 0
                var todayDist: Double = 0
                
                // 현재 날짜 계산
                let calendar = Calendar.current
                let now = Date()
                let startOfWeek = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!)
                let startOfDay = calendar.startOfDay(for: now)
                
                for document in documents {
                    let data = document.data()
                    
                    // 좌표 배열 파싱
                    var coordinates: [CLLocationCoordinate2D] = []
                    if let trail = data["trail"] as? [[String: Any]] {
                        for point in trail {
                            if let lat = point["lat"] as? Double, let lng = point["lng"] as? Double {
                                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            }
                        }
                    }
                    
                    // 날짜 파싱
                    let timestamp = (data["runAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // 거리 계산 (데이터에 있으면 사용하고, 없으면 trail에서 계산)
                    let distance = data["distance"] as? Double ?? 0
                    
                    // 통계 계산
                    totalDist += distance
                    
                    // 이번 주 거리
                    if timestamp >= startOfWeek {
                        weeklyDist += distance
                    }
                    
                    // 오늘 거리
                    if timestamp >= startOfDay {
                        todayDist += distance
                    }
                    
                    // 러닝 객체 생성
                    let run = Run(
                        id: document.documentID,
                        courseId: data["courseId"] as? String ?? "",
                        duration: data["duration"] as? Int ?? 0,
                        pace: data["pace"] as? Int ?? 0,
                        paceStr: data["paceStr"] as? String ?? "",
                        runAt: timestamp,
                        trail: coordinates,
                        userId: data["userId"] as? String ?? ""
                    )
                    
                    runs.append(run)
                }
                
                completion(runs, totalDist, weeklyDist, todayDist)
            }
    }
    
    func loadMyCourses(userId: String, limit: Int = 10, completion: @escaping ([Course]) -> Void) {
        let db = Firestore.firestore()
        db.collection("courses")
            .whereField("createdBy", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting courses: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No courses found")
                    completion([])
                    return
                }
                
                // 코스 데이터 파싱
                var courses: [Course] = []
                
                for document in documents {
                    let data = document.data()
                    
                    // 좌표 배열 파싱
                    if let coordsData = data["coordinates"] as? [[String: Any]] {
                        // 날짜 파싱
                        let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        
                        // 코스 객체 생성
                        let course = Course(
                            id: document.documentID,
                            title: data["title"] as? String ?? "무제 코스",
                            distance: data["distance"] as? Double ?? 0,
                            coordinates: coordsData.map { point in
                                Coordinate(
                                    lat: point["lat"] as? Double ?? 0.0,
                                    lng: point["lng"] as? Double ?? 0.0,
                                    timestamp: point["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
                                )
                            },
                            createdAt: timestamp,
                            createdBy: data["createdBy"] as? String ?? "",
                            isPublic: data["isPublic"] as? Bool ?? false
                        )
                        
                        courses.append(course)
                    }
                }
                
                completion(courses)
            }
    }
}
