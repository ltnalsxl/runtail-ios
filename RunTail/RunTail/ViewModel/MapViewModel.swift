//
//  MapViewModel.swift
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

class MapViewModel: ObservableObject {
    // 사용자 데이터
    @Published var userEmail: String = ""
    @Published var userId: String = ""
    
    
    // 데이터 상태
    @Published var recentRuns: [Run] = []
    @Published var myCourses: [Course] = []
    @Published var totalDistance: Double = 0
    @Published var weeklyDistance: Double = 0
    @Published var todayDistance: Double = 0
    
    // UI 상태
    @Published var isStartRunExpanded = false
    @Published var selectedTab = 0
    
    // 로그아웃 관련 상태
    @Published var showLogoutAlert = false
    @Published var isLoggedOut = false
    
    // 지도 관련 상태
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), // 서울
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // 탐색 카테고리
    let exploreCategories = [
        ExploreCategory(title: "인기 코스", icon: "star.fill", color: Color(red: 89/255, green: 86/255, blue: 214/255)),
        ExploreCategory(title: "내 근방", icon: "location.fill", color: Color(red: 45/255, green: 104/255, blue: 235/255)),
        ExploreCategory(title: "30분 코스", icon: "clock.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
    ]
    
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
    
    // 다크 그라데이션 - 더 진한 색상
    let darkGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 74/255, green: 55/255, blue: 126/255), // #4A377E (다크 퍼플)
            Color(red: 26/255, green: 86/255, blue: 155/255)  // #1A569B (다크 블루)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    init() {
        // 현재 로그인한 사용자 정보 가져오기
        if let user = Auth.auth().currentUser {
            userEmail = user.email ?? ""
            userId = user.uid
            
            // 데이터 로드 함수 호출
            loadUserData()
            loadRecentRuns()
            loadMyCourses()
        }
    }
    
    // 로그아웃 함수
    func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedOut = true
        } catch {
            print("로그아웃 오류: \(error.localizedDescription)")
        }
    }
    
    // 탭 관련 함수
    func tabIcon(_ index: Int) -> String {
        switch index {
        case 0: return "house.fill"
        case 1: return "map.fill"
        case 2: return "chart.bar.fill"
        case 3: return "person.fill"
        default: return ""
        }
    }
    
    func tabTitle(_ index: Int) -> String {
        switch index {
        case 0: return "홈"
        case 1: return "탐색"
        case 2: return "활동"
        case 3: return "프로필"
        default: return ""
        }
    }
    
    // 데이터 로드 함수
    func loadUserData() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Error getting user data: \(error)")
                return
            }
            
            guard let document = document, document.exists else {
                print("User document does not exist")
                return
            }
            
            // 사용자 데이터 처리
            // 필요한 경우 추가 필드 사용
        }
    }
    
    // 최근 러닝 데이터 로드
    func loadRecentRuns() {
        let db = Firestore.firestore()
        db.collection("runs")
            .whereField("userId", isEqualTo: userId)
            .order(by: "runAt", descending: true)
            .limit(to: 5)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error getting runs: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No runs found")
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
                
                // 상태 업데이트
                DispatchQueue.main.async {
                    self.recentRuns = runs
                    self.totalDistance = totalDist
                    self.weeklyDistance = weeklyDist
                    self.todayDistance = todayDist
                }
            }
    }
    
    // 내 코스 데이터 로드
    func loadMyCourses() {
        let db = Firestore.firestore()
        db.collection("courses")
            .whereField("createdBy", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error getting courses: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No courses found")
                    return
                }
                
                // 코스 데이터 파싱
                var courses: [Course] = []
                
                for document in documents {
                    let data = document.data()
                    
                    // 좌표 배열 파싱
                    var coordinates: [CLLocationCoordinate2D] = []
                    if let coordsData = data["coordinates"] as? [[String: Any]] {
                        for point in coordsData {
                            if let lat = point["lat"] as? Double, let lng = point["lng"] as? Double {
                                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            }
                        }
                    }
                    
                    // 날짜 파싱
                    let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // 코스 객체 생성
                    let course = Course(
                        id: document.documentID,
                        title: data["title"] as? String ?? "무제 코스",
                        distance: data["distance"] as? Double ?? 0,
                        coordinates: coordinates,
                        createdAt: timestamp,
                        createdBy: data["createdBy"] as? String ?? "",
                        isPublic: data["isPublic"] as? Bool ?? false
                    )
                    
                    courses.append(course)
                }
                
                // 상태 업데이트
                DispatchQueue.main.async {
                    self.myCourses = courses
                }
            }
    }
    
    // 코스 제목 가져오기
    func getCourseTitle(courseId: String) -> String {
        // 내 코스 중에서 찾기
        if let course = myCourses.first(where: { $0.id == courseId }) {
            return course.title
        }
        
        // 코스 ID가 없거나 찾을 수 없는 경우 기본값
        return "자유 러닝"
    }
}
