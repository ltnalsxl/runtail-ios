//
//  MapViewModel.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//  Updated with running tracking features and voice guidance
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
    
    // MARK: - 따라 달리기 관련 상태
    @Published var isFollowingCourse = false
    @Published var currentFollowingCourse: Course?
    @Published var courseProgress: Double = 0.0
    @Published var distanceFromCourse: Double = 0.0
    @Published var currentCoursePoint: Int = 0
    @Published var isOffCourse = false
    @Published var nextWaypoint: Coordinate?
    @Published var remainingDistance: Double = 0.0
    
    // MARK: - 음성 안내 서비스
    @Published var voiceGuidanceService = VoiceGuidanceService()
    @Published var isVoiceGuidanceEnabled = true
    
    // MARK: - 로그아웃 관련 상태
    @Published var showLogoutAlert = false
    @Published var isLoggedOut = false
    
    // MARK: - 지도 관련 상태
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // MARK: - 내부 변수
    private var recordingTimer: Timer?
    private var lastLocation: CLLocationCoordinate2D?
    private var pausedTime: TimeInterval = 0
    private var lastAnnouncedKilometer: Int = 0
    private var wasOffCourse = false
    
    // 코스 따라가기 허용 거리 (미터)
    private let maxDistanceFromCourse: Double = 50.0
    
    // MARK: - 탐색 카테고리
    let exploreCategories = [
        ExploreCategory(title: "인기 코스", icon: "star.fill", color: Color(red: 89/255, green: 86/255, blue: 214/255)),
        ExploreCategory(title: "내 근방", icon: "location.fill", color: Color(red: 45/255, green: 104/255, blue: 235/255)),
        ExploreCategory(title: "30분 코스", icon: "clock.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
    ]
    
    // MARK: - 앱 테마 색상
    let themeColor = Color(red: 89/255, green: 86/255, blue: 214/255)
    
    let themeGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 89/255, green: 86/255, blue: 214/255),
            Color(red: 0/255, green: 122/255, blue: 255/255)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    let darkGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 74/255, green: 55/255, blue: 126/255),
            Color(red: 26/255, green: 86/255, blue: 155/255)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - 생성자
    init(authProvider: FirebaseAuthProtocol? = nil, loadData: Bool = true) {
        if let provider = authProvider {
            userEmail = provider.currentUserEmail ?? ""
            userId = provider.currentUserId ?? ""
        } else if let user = Auth.auth().currentUser {
            userEmail = user.email ?? ""
            userId = user.uid
        }

        if loadData && !userId.isEmpty {
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
    
    func startRecording() {
        isRecording = true
        isPaused = false
        recordedCoordinates = []
        recordingStartTime = Date()
        recordingElapsedTime = 0
        recordingDistance = 0
        lastLocation = nil
        pausedTime = 0
        lastAnnouncedKilometer = 0
        
        // 음성 안내
        voiceGuidanceService.announceRunStart()
        
        startTimer()
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime, !self.isPaused else { return }
            self.recordingElapsedTime = Date().timeIntervalSince(startTime) - self.pausedTime
        }
    }
    
    func pauseRecording() {
        isPaused = true
        if let startTime = recordingStartTime {
            pausedTime = Date().timeIntervalSince(startTime) - recordingElapsedTime
        }
        
        // 음성 안내
        voiceGuidanceService.announcePause()
    }
    
    func resumeRecording() {
        isPaused = false
        
        // 음성 안내
        voiceGuidanceService.announceResume()
    }
    
    func addLocationToRecording(coordinate: CLLocationCoordinate2D) {
        guard isRecording, !isPaused else { return }
        
        let minimumDistance: Double = 5.0
        
        if let last = lastLocation {
            let lastCLLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let newCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            let incrementalDistance = lastCLLocation.distance(from: newCLLocation)
            
            if incrementalDistance < minimumDistance {
                return
            }
            
            recordingDistance += incrementalDistance
            
            // 1km마다 음성 안내
            let currentKilometer = Int(recordingDistance / 1000)
            if currentKilometer > lastAnnouncedKilometer && currentKilometer > 0 {
                voiceGuidanceService.announceDistance(recordingDistance, elapsedTime: recordingElapsedTime)
                lastAnnouncedKilometer = currentKilometer
            }
        }
        
        let newCoordinate = Coordinate(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            timestamp: Date().timeIntervalSince1970
        )
        
        recordedCoordinates.append(newCoordinate)
        lastLocation = coordinate
    }
    
    func addLocationToRecordingWithCourseTracking(coordinate: CLLocationCoordinate2D) {
        addLocationToRecording(coordinate: coordinate)
        
        if isFollowingCourse {
            updateCourseTracking(userLocation: coordinate)
        }
    }
    
    func stopRecording(completion: @escaping (Bool, String?) -> Void) {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard isRecording, let startTime = recordingStartTime, !recordedCoordinates.isEmpty else {
            isRecording = false
            isPaused = false
            stopFollowingCourse()
            completion(false, "기록된 데이터가 없습니다.")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        tempCourseName = "\(formatter.string(from: startTime)) 러닝"
        
        showSaveAlert = true
        isRecording = false
        isPaused = false
        
        if isFollowingCourse {
            stopFollowingCourse()
        }
        
        completion(true, nil)
    }
    
    // MARK: - 따라 달리기 기능
    
    func startFollowingCourse(_ course: Course) {
        startRecording()
        
        isFollowingCourse = true
        currentFollowingCourse = course
        courseProgress = 0.0
        currentCoursePoint = 0
        isOffCourse = false
        distanceFromCourse = 0.0
        remainingDistance = course.distance
        wasOffCourse = false
        
        if !course.coordinates.isEmpty {
            nextWaypoint = course.coordinates.first
        }
        
        // 음성 안내
        voiceGuidanceService.announceCourseFollowStart(courseName: course.title)
        
        print("따라 달리기 시작: \(course.title)")
    }
    
    func updateCourseTracking(userLocation: CLLocationCoordinate2D) {
        guard isFollowingCourse,
              let course = currentFollowingCourse,
              !course.coordinates.isEmpty else { return }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        let (closestPoint, closestDistance) = findClosestPointOnCourse(userLocation: userCLLocation, course: course)
        
        distanceFromCourse = closestDistance
        
        // 코스 이탈 여부 확인 및 음성 안내
        let currentlyOffCourse = closestDistance > maxDistanceFromCourse
        
        if currentlyOffCourse && !wasOffCourse {
            isOffCourse = true
            wasOffCourse = true
            voiceGuidanceService.announceOffCourse()
        } else if !currentlyOffCourse && wasOffCourse {
            isOffCourse = false
            wasOffCourse = false
            voiceGuidanceService.announceBackOnCourse()
        }
        
        isOffCourse = currentlyOffCourse
        
        let progressIndex = max(closestPoint, currentCoursePoint)
        let newProgress = Double(progressIndex) / Double(course.coordinates.count - 1)
        
        // 25%, 50%, 75% 지점에서 진행률 안내
        let oldProgressPercent = Int(courseProgress * 100 / 25) * 25
        let newProgressPercent = Int(newProgress * 100 / 25) * 25
        
        if newProgressPercent > oldProgressPercent && newProgressPercent > 0 && newProgressPercent < 100 {
            voiceGuidanceService.announceProgress(Double(newProgressPercent) / 100.0)
        }
        
        courseProgress = newProgress
        
        if progressIndex > currentCoursePoint {
            currentCoursePoint = progressIndex
            updateNextWaypoint(course: course)
        }
        
        updateRemainingDistance(course: course, currentIndex: progressIndex)
        checkCourseCompletion(course: course)
    }
    
    private func findClosestPointOnCourse(userLocation: CLLocation, course: Course) -> (Int, Double) {
        var closestIndex = 0
        var minDistance = Double.greatestFiniteMagnitude
        
        for (index, coordinate) in course.coordinates.enumerated() {
            let courseLocation = CLLocation(latitude: coordinate.lat, longitude: coordinate.lng)
            let distance = userLocation.distance(from: courseLocation)
            
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }
        
        return (closestIndex, minDistance)
    }
    
    private func updateNextWaypoint(course: Course) {
        let lookAheadDistance: Double = 200.0
        var accumulatedDistance: Double = 0.0
        
        for i in currentCoursePoint..<(course.coordinates.count - 1) {
            let currentPoint = CLLocation(latitude: course.coordinates[i].lat, longitude: course.coordinates[i].lng)
            let nextPoint = CLLocation(latitude: course.coordinates[i + 1].lat, longitude: course.coordinates[i + 1].lng)
            
            accumulatedDistance += currentPoint.distance(from: nextPoint)
            
            if accumulatedDistance >= lookAheadDistance {
                nextWaypoint = course.coordinates[i + 1]
                break
            }
        }
        
        if currentCoursePoint >= course.coordinates.count - 10 {
            nextWaypoint = course.coordinates.last
        }
    }
    
    private func updateRemainingDistance(course: Course, currentIndex: Int) {
        var remaining: Double = 0.0
        
        for i in currentIndex..<(course.coordinates.count - 1) {
            let currentPoint = CLLocation(latitude: course.coordinates[i].lat, longitude: course.coordinates[i].lng)
            let nextPoint = CLLocation(latitude: course.coordinates[i + 1].lat, longitude: course.coordinates[i + 1].lng)
            remaining += currentPoint.distance(from: nextPoint)
        }
        
        remainingDistance = remaining
    }
    
    private func checkCourseCompletion(course: Course) {
        let finishLineDistance: Double = 50.0
        
        if let lastCoordinate = course.coordinates.last {
            let finishLine = CLLocation(latitude: lastCoordinate.lat, longitude: lastCoordinate.lng)
            
            if let userLocation = recordedCoordinates.last {
                let userCLLocation = CLLocation(latitude: userLocation.lat, longitude: userLocation.lng)
                let distanceToFinish = userCLLocation.distance(from: finishLine)
                
                if distanceToFinish <= finishLineDistance && courseProgress > 0.8 {
                    completeCourseFollow()
                }
            }
        }
    }
    
    private func completeCourseFollow() {
        isFollowingCourse = false
        courseProgress = 1.0
        
        // 완주 축하 음성 안내
        voiceGuidanceService.announceCompletion(distance: recordingDistance, time: recordingElapsedTime)
        
        DispatchQueue.main.async {
            print("🎉 코스 완주! 축하합니다!")
        }
    }
    
    func getNavigationInstruction() -> String {
        guard isFollowingCourse,
              let nextWaypoint = nextWaypoint,
              let userLocation = recordedCoordinates.last else {
            return ""
        }
        
        let userCLLocation = CLLocation(latitude: userLocation.lat, longitude: userLocation.lng)
        let waypointLocation = CLLocation(latitude: nextWaypoint.lat, longitude: nextWaypoint.lng)
        let distance = userCLLocation.distance(from: waypointLocation)
        
        if isOffCourse {
            return "⚠️ 코스에서 벗어났습니다. 코스로 돌아가세요."
        }
        
        if distance < 10 {
            return "✅ 목표 지점에 도착했습니다."
        } else if distance < 50 {
            return "🎯 목표 지점까지 \(Int(distance))m"
        } else {
            return "➡️ 코스를 따라 계속 진행하세요."
        }
    }
    
    func stopFollowingCourse() {
        isFollowingCourse = false
        currentFollowingCourse = nil
        courseProgress = 0.0
        currentCoursePoint = 0
        isOffCourse = false
        distanceFromCourse = 0.0
        nextWaypoint = nil
        remainingDistance = 0.0
        wasOffCourse = false
    }
    
    // MARK: - 음성 안내 설정
    func toggleVoiceGuidance() {
        isVoiceGuidanceEnabled.toggle()
        voiceGuidanceService.setEnabled(isVoiceGuidanceEnabled)
    }
    
    // MARK: - 코스 저장 및 관리
    
    func incrementCourseRunCount(courseId: String) {
        guard !courseId.isEmpty else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let courseRef = db.collection("courses").document(courseId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let courseDocument: DocumentSnapshot
            do {
                try courseDocument = transaction.getDocument(courseRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let currentCount = courseDocument.data()?["runCount"] as? Int ?? 0
            transaction.updateData(["runCount": currentCount + 1], forDocument: courseRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("코스 실행 횟수 증가 오류: \(error)")
            } else {
                print("코스 실행 횟수 증가 성공")
            }
        }
    }
    
    func saveRecordingAsCourse(title: String, isPublic: Bool = false, completion: @escaping (Bool, String?) -> Void) {
        guard !recordedCoordinates.isEmpty else {
            completion(false, nil)
            return
        }
        
        let db = Firestore.firestore()
        let courseRef = db.collection("courses").document()
        
        var courseData: [String: Any] = [
            "title": title,
            "distance": recordingDistance,
            "createdAt": FieldValue.serverTimestamp(),
            "createdBy": userId,
            "isPublic": isPublic,
            "runCount": 0
        ]
        
        var coordinatesData: [[String: Any]] = []
        for coordinate in recordedCoordinates {
            coordinatesData.append([
                "lat": coordinate.lat,
                "lng": coordinate.lng,
                "timestamp": coordinate.timestamp
            ])
        }
        courseData["coordinates"] = coordinatesData
        
        courseRef.setData(courseData) { error in
            if let error = error {
                print("Error saving course: \(error)")
                completion(false, nil)
            } else {
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
    
    private func saveRunRecord(courseId: String, completion: @escaping (Bool) -> Void) {
        guard let startTime = recordingStartTime else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let runRef = db.collection("runs").document()
        
        let pace = recordingDistance > 0 ? Int(recordingElapsedTime / (recordingDistance / 1000)) : 0
        
        let minutes = pace / 60
        let seconds = pace % 60
        let paceStr = "\(minutes)'\(String(format: "%02d", seconds))\""
        
        var trail: [[String: Any]] = []
        for (index, coordinate) in recordedCoordinates.enumerated() {
            if index % 10 == 0 || index == recordedCoordinates.count - 1 {
                trail.append([
                    "lat": coordinate.lat,
                    "lng": coordinate.lng
                ])
            }
        }
        
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
        
        runRef.setData(runData) { error in
            if let error = error {
                print("Error saving run: \(error)")
                completion(false)
            } else {
                if !courseId.isEmpty {
                    self.incrementCourseRunCount(courseId: courseId)
                }
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
        }
    }
    
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
                
                var runs: [Run] = []
                var totalDist: Double = 0
                var weeklyDist: Double = 0
                var todayDist: Double = 0
                
                let calendar = Calendar.current
                let now = Date()
                let startOfWeek = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!)
                let startOfDay = calendar.startOfDay(for: now)
                
                for document in documents {
                    let data = document.data()
                    
                    var coordinates: [CLLocationCoordinate2D] = []
                    if let trail = data["trail"] as? [[String: Any]] {
                        for point in trail {
                            if let lat = point["lat"] as? Double, let lng = point["lng"] as? Double {
                                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            }
                        }
                    }
                    
                    let timestamp = (data["runAt"] as? Timestamp)?.dateValue() ?? Date()
                    let distance = data["distance"] as? Double ?? 0
                    
                    totalDist += distance
                    
                    if timestamp >= startOfWeek {
                        weeklyDist += distance
                    }
                    
                    if timestamp >= startOfDay {
                        todayDist += distance
                    }
                    
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
                
                DispatchQueue.main.async {
                    self.recentRuns = runs
                    self.totalDistance = totalDist
                    self.weeklyDistance = weeklyDist
                    self.todayDistance = todayDist
                }
            }
    }
    
    func loadMyCourses() {
        let db = Firestore.firestore()
        
        let publicQuery = db.collection("courses")
            .whereField("isPublic", isEqualTo: true)
        
        let myCoursesQuery = db.collection("courses")
            .whereField("createdBy", isEqualTo: userId)
        
        publicQuery.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("공개 코스 로드 오류: \(error)")
                return
            }
            
            var courses: [Course] = []
            
            if let publicDocuments = snapshot?.documents {
                print("공개 코스 수: \(publicDocuments.count)")
                
                for document in publicDocuments {
                    if let course = self.parseCourseDocument(document) {
                        courses.append(course)
                    }
                }
            }
            
            myCoursesQuery.getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("내 코스 로드 오류: \(error)")
                    return
                }
                
                if let myDocuments = snapshot?.documents {
                    print("내 코스 수: \(myDocuments.count)")
                    
                    for document in myDocuments {
                        if let course = self.parseCourseDocument(document) {
                            if !courses.contains(where: { $0.id == course.id }) {
                                courses.append(course)
                            }
                        }
                    }
                }
                
                courses.sort { $0.createdAt > $1.createdAt }
                
                DispatchQueue.main.async {
                    self.myCourses = courses
                    print("최종 로드된 코스 수: \(courses.count)")
                }
            }
        }
    }
    
    private func parseCourseDocument(_ document: QueryDocumentSnapshot) -> Course? {
        let data = document.data()
        
        guard let coordsData = data["coordinates"] as? [[String: Any]] else {
            return nil
        }
        
        let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
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
            isPublic: data["isPublic"] as? Bool ?? false,
            runCount: data["runCount"] as? Int ?? 0
        )
        
        return course
    }
    
    // MARK: - 유틸리티 함수
    
    func getCourse(by id: String) -> Course? {
        return myCourses.first { $0.id == id }
    }
    
    func getCourseTitle(courseId: String) -> String {
        if let course = myCourses.first(where: { $0.id == courseId }) {
            return course.title
        }
        return "자유 러닝"
    }
    
    func findNearbyCoursesFor(coordinate: CLLocationCoordinate2D, radius: Double = 2000) -> [Course] {
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return myCourses.filter { course in
            guard !course.coordinates.isEmpty else { return false }
            
            let courseStartLocation = CLLocation(latitude: course.coordinates[0].lat, longitude: course.coordinates[0].lng)
            let distance = currentLocation.distance(from: courseStartLocation)
            
            return distance <= radius
        }.sorted { courseA, courseB in
            let locA = CLLocation(latitude: courseA.coordinates[0].lat, longitude: courseA.coordinates[0].lng)
            let locB = CLLocation(latitude: courseB.coordinates[0].lat, longitude: courseB.coordinates[0].lng)
            
            return currentLocation.distance(from: locA) < currentLocation.distance(from: locB)
        }
    }
    
    func getUserAveragePace() -> Double {
        let defaultPace: Double = 6 * 60
        
        guard !recentRuns.isEmpty else {
            return defaultPace
        }
        
        let validRuns = recentRuns.filter { $0.pace > 0 }
        
        if validRuns.isEmpty {
            return defaultPace
        }
        
        let recentValidRuns = Array(validRuns.prefix(3))
        let totalPace = recentValidRuns.reduce(0) { $0 + Double($1.pace) }
        
        return totalPace / Double(recentValidRuns.count)
    }
}
