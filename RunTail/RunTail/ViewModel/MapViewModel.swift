//
//  MapViewModel.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//  Updated with running tracking features
//

import SwiftUI
import MapKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

class MapViewModel: ObservableObject {
    // MARK: - 사용자 데이터
    @Published var userEmail: String = ""
    @Published var userId: String = ""
    // 코스 따라 달리기 관련 상태
    @Published var isFollowingCourse = false
    @Published var currentFollowingCourse: Course?
    
    // MARK: - 데이터 상태
    @Published var recentRuns: [Run] = []
    @Published var myCourses: [Course] = []
    @Published var totalDistance: Double = 0
    @Published var weeklyDistance: Double = 0
    @Published var todayDistance: Double = 0
    
    // MARK: - UI 상태
    @Published var isStartRunExpanded = false
    @Published var selectedTab = 0
    
    // MARK: - 러닝 기록 관련 상태
    @Published var isRecording = false
    @Published var recordedCoordinates: [Coordinate] = []
    @Published var recordingStartTime: Date?
    @Published var recordingElapsedTime: TimeInterval = 0
    @Published var recordingDistance: Double = 0
    @Published var isPaused = false
    @Published var showSaveAlert = false
    @Published var tempCourseName = ""
    @Published var showCourseDetailView = false
    @Published var selectedCourseId: String?
    
    // MARK: - 로그아웃 관련 상태
    @Published var showLogoutAlert = false
    @Published var isLoggedOut = false
    
    // MARK: - 지도 관련 상태
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), // 서울
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // MARK: - 내부 변수
    private var recordingTimer: Timer?
    private var lastLocation: CLLocationCoordinate2D?
    private var pausedTime: TimeInterval = 0
    
    // MARK: - 탐색 카테고리
    let exploreCategories = [
        ExploreCategory(title: "인기 코스", icon: "star.fill", color: Color(red: 89/255, green: 86/255, blue: 214/255)),
        ExploreCategory(title: "내 근방", icon: "location.fill", color: Color(red: 45/255, green: 104/255, blue: 235/255)),
        ExploreCategory(title: "30분 코스", icon: "clock.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
    ]
    
    // MARK: - 앱 테마 색상
    let themeColor = Color(red: 89/255, green: 86/255, blue: 214/255) // #5956D6 (퍼플)
    
    // MARK: - UI 요소에 적용할 그라데이션
    let themeGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 89/255, green: 86/255, blue: 214/255), // #5956D6 (퍼플)
            Color(red: 0/255, green: 122/255, blue: 255/255)  // #007AFF (블루)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - 다크 그라데이션
    let darkGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 74/255, green: 55/255, blue: 126/255), // #4A377E (다크 퍼플)
            Color(red: 26/255, green: 86/255, blue: 155/255)  // #1A569B (다크 블루)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - 생성자
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
    
    // MARK: - 탭 관련 함수
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
    
    // MARK: - 러닝 기록 관련 함수
    
    /// 러닝 기록 시작
    func startRecording() {
        isRecording = true
        isPaused = false
        recordedCoordinates = []
        recordingStartTime = Date()
        recordingElapsedTime = 0
        recordingDistance = 0
        lastLocation = nil
        pausedTime = 0
        
        // 타이머 시작
        startTimer()
    }
    
    /// 타이머 시작
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime, !self.isPaused else { return }
            self.recordingElapsedTime = Date().timeIntervalSince(startTime) - self.pausedTime
        }
    }
    
    /// 러닝 일시 정지
    func pauseRecording() {
        isPaused = true
        // 현재까지의 일시정지 시간 저장
        if let startTime = recordingStartTime {
            pausedTime = Date().timeIntervalSince(startTime) - recordingElapsedTime
        }
    }
    
    /// 러닝 재개
    func resumeRecording() {
        isPaused = false
    }
    
    /// 현재 위치 추가 (최적화 적용)
    func addLocationToRecording(coordinate: CLLocationCoordinate2D) {
        guard isRecording, !isPaused else { return }
        
        // 필터링 기준: 최소 거리
        let minimumDistance: Double = 5.0 // 5미터
        
        // 이전 좌표가 있고, 거리가 최소 기준보다 작으면 무시
        if let last = lastLocation {
            let lastCLLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let newCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            let incrementalDistance = lastCLLocation.distance(from: newCLLocation)
            
            // 5미터 이상 이동했을 때만 새 좌표 추가
            if incrementalDistance < minimumDistance {
                return
            }
            
            recordingDistance += incrementalDistance
        }
        
        // 좌표 추가
        let newCoordinate = Coordinate(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            timestamp: Date().timeIntervalSince1970
        )
        
        recordedCoordinates.append(newCoordinate)
        lastLocation = coordinate
    }
    
    /// 러닝 기록 종료
    func stopRecording(completion: @escaping (Bool, String?) -> Void) {
        // 타이머 중지
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard isRecording, let startTime = recordingStartTime, !recordedCoordinates.isEmpty else {
            isRecording = false
            isPaused = false
            completion(false, "기록된 데이터가 없습니다.")
            return
        }
        
        // 기본 코스 제목 생성
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        tempCourseName = "\(formatter.string(from: startTime)) 러닝"
        
        // 알림창 표시 여부 설정
        showSaveAlert = true
        
        // UI 상태 초기화
        isRecording = false
        isPaused = false
        
        // 저장 프로세스는 알림창 응답 후 처리됨
        // 기본적으로 성공 콜백
        completion(true, nil)
    }
    
    /// 코스 저장
    func saveRecordingAsCourse(title: String, isPublic: Bool = false, completion: @escaping (Bool, String?) -> Void) {
        guard !recordedCoordinates.isEmpty else {
            completion(false, nil)
            return
        }
        
        let db = Firestore.firestore()
        let courseRef = db.collection("courses").document()
        
        // 코스 데이터 준비
        var courseData: [String: Any] = [
            "title": title,
            "distance": recordingDistance,
            "createdAt": FieldValue.serverTimestamp(),
            "createdBy": userId,
            "isPublic": isPublic
        ]
        
        // 좌표 배열 준비
        var coordinatesData: [[String: Any]] = []
        for coordinate in recordedCoordinates {
            coordinatesData.append([
                "lat": coordinate.lat,
                "lng": coordinate.lng,
                "timestamp": coordinate.timestamp
            ])
        }
        courseData["coordinates"] = coordinatesData
        
        // Firestore에 저장
        courseRef.setData(courseData) { error in
            if let error = error {
                print("Error saving course: \(error)")
                completion(false, nil)
            } else {
                // 러닝 기록도 함께 저장
                self.saveRunRecord(courseId: courseRef.documentID) { success in
                    if success {
                        self.selectedCourseId = courseRef.documentID
                        self.showCourseDetailView = true
                        completion(success, courseRef.documentID)
                    } else {
                        completion(false, nil)
                    }
                }
            }
        }
    }
    
    /// 러닝 기록 저장
    private func saveRunRecord(courseId: String, completion: @escaping (Bool) -> Void) {
        guard let startTime = recordingStartTime else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let runRef = db.collection("runs").document()
        
        // 페이스 계산 (초/km)
        let pace = recordingDistance > 0 ? Int(recordingElapsedTime / (recordingDistance / 1000)) : 0
        
        // 페이스 문자열 형식 (예: "6'20"")
        let minutes = pace / 60
        let seconds = pace % 60
        let paceStr = "\(minutes)'\(String(format: "%02d", seconds))\""
        
        // 좌표 배열 준비 (간소화된 버전으로)
        var trail: [[String: Any]] = []
        // 모든 좌표를 저장하면 데이터가 너무 커질 수 있으므로
        // 일정 간격으로 추출 (예: 10개 좌표마다 1개)
        for (index, coordinate) in recordedCoordinates.enumerated() {
            if index % 10 == 0 || index == recordedCoordinates.count - 1 {
                trail.append([
                    "lat": coordinate.lat,
                    "lng": coordinate.lng
                ])
            }
        }
        
        // 런 데이터 준비
        let runData: [String: Any] = [
            "courseId": courseId,
            "distance": recordingDistance,
            "duration": Int(recordingElapsedTime),
            "pace": pace,
            "paceStr": paceStr,
            "runAt": FieldValue.serverTimestamp(),
            "trail": trail,
            "userId": userId
        ]
        
        // Firestore에 저장
        runRef.setData(runData) { error in
            if let error = error {
                print("Error saving run: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // MARK: - 로그아웃 함수
    func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedOut = true
        } catch {
            print("로그아웃 오류: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 데이터 로드 함수
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
    
    // MARK: - 최근 러닝 데이터 로드
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
    
    // MARK: - 내 코스 데이터 로드
    // MapViewModel.swift의 loadMyCourses 함수를 수정
    func loadMyCourses() {
        let db = Firestore.firestore()
        
        // 공개된 모든 코스 + 내가 만든 비공개 코스 가져오기
        let publicQuery = db.collection("courses")
            .whereField("isPublic", isEqualTo: true)
        
        let myCoursesQuery = db.collection("courses")
            .whereField("createdBy", isEqualTo: userId)
        
        // 먼저 공개 코스 가져오기
        publicQuery.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("공개 코스 로드 오류: \(error)")
                return
            }
            
            var courses: [Course] = []
            
            if let publicDocuments = snapshot?.documents {
                print("공개 코스 수: \(publicDocuments.count)")
                
                // 공개 코스 파싱
                for document in publicDocuments {
                    if let course = self.parseCourseDocument(document) {
                        courses.append(course)
                    }
                }
            }
            
            // 이어서 내 비공개 코스 가져오기
            myCoursesQuery.getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("내 코스 로드 오류: \(error)")
                    return
                }
                
                if let myDocuments = snapshot?.documents {
                    print("내 코스 수: \(myDocuments.count)")
                    
                    // 내 코스 파싱하여 추가
                    for document in myDocuments {
                        if let course = self.parseCourseDocument(document) {
                            // 중복 방지 (이미 공개 코스에 포함된 경우)
                            if !courses.contains(where: { $0.id == course.id }) {
                                courses.append(course)
                            }
                        }
                    }
                }
                
                // 최신순으로 정렬
                courses.sort { $0.createdAt > $1.createdAt }
                
                // 상태 업데이트
                DispatchQueue.main.async {
                    self.myCourses = courses
                    print("최종 로드된 코스 수: \(courses.count)")
                }
            }
        }
    }

    // 코스 문서 파싱 헬퍼 함수
    private func parseCourseDocument(_ document: QueryDocumentSnapshot) -> Course? {
        let data = document.data()
        
        // 좌표 배열 파싱
        guard let coordsData = data["coordinates"] as? [[String: Any]] else {
            return nil
        }
        
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
        
        return course
    }
    // MARK: - 유틸리티 함수
    
    /// 코스 객체 가져오기
    func getCourse(by id: String) -> Course? {
        return myCourses.first { $0.id == id }
    }
    
    /// 코스 제목 가져오기
    func getCourseTitle(courseId: String) -> String {
        // 내 코스 중에서 찾기
        if let course = myCourses.first(where: { $0.id == courseId }) {
            return course.title
        }
        
        // 코스 ID가 없거나 찾을 수 없는 경우 기본값
        return "자유 러닝"
    }
    
    /// 가장 가까운 코스 찾기
    func findNearbyCoursesFor(coordinate: CLLocationCoordinate2D, radius: Double = 2000) -> [Course] {
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 사용자 위치에서 2km 이내의 코스 필터링
        return myCourses.filter { course in
            guard !course.coordinates.isEmpty else { return false }
            
            // 코스의 첫 좌표와 현재 위치 사이의 거리 확인
            let courseStartLocation = CLLocation(latitude: course.coordinates[0].lat, longitude: course.coordinates[0].lng)
            let distance = currentLocation.distance(from: courseStartLocation)
            
            return distance <= radius
        }.sorted { courseA, courseB in
            // 시작점 기준으로 가까운 순서대로 정렬
            let locA = CLLocation(latitude: courseA.coordinates[0].lat, longitude: courseA.coordinates[0].lng)
            let locB = CLLocation(latitude: courseB.coordinates[0].lat, longitude: courseB.coordinates[0].lng)
            
            return currentLocation.distance(from: locA) < currentLocation.distance(from: locB)
        }
    }
    
    // 사용자의 평균 페이스 계산
    func getUserAveragePace() -> Double {
        // 기본 페이스 (초/km)
        let defaultPace: Double = 6 * 60 // 6분/km
        
        // 최근 러닝 기록이 없으면 기본값 사용
        guard !recentRuns.isEmpty else {
            return defaultPace
        }
        
        // 유효한 페이스가 있는 러닝만 필터링
        let validRuns = recentRuns.filter { $0.pace > 0 }
        
        if validRuns.isEmpty {
            return defaultPace
        }
        
        // 최근 3개까지의 유효한 러닝 기록으로 평균 페이스 계산
        let recentValidRuns = Array(validRuns.prefix(3))
        let totalPace = recentValidRuns.reduce(0) { $0 + Double($1.pace) }
        
        return totalPace / Double(recentValidRuns.count)
    }
    
    // 코스 따라 달리기 모드로 러닝 시작
    func startRecordingFollowCourse(_ course: Course) {
        isRecording = true
        isPaused = false
        recordedCoordinates = []
        recordingStartTime = Date()
        recordingElapsedTime = 0
        recordingDistance = 0
        lastLocation = nil
        pausedTime = 0
        
        // 코스 따라가기 모드를 위한 추가 로직
        currentFollowingCourse = course
        isFollowingCourse = true
        
        // 타이머 시작
        startTimer()
    }
}
