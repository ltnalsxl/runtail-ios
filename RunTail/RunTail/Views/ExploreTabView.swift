//
//  ExploreTabView.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

import SwiftUI
import MapKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ExploreTabView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var searchText = ""
    @State private var myCourses: [Course] = []
    @State private var publicCourses: [Course] = []
    @State private var favoriteCourses: Set<String> = [] // 즐겨찾기한 코스 ID
    @State private var isLoading = true
    @State private var selectedTab = 0 // 0: 내 코스, 1: 발견
    @State private var sortOption = 0 // 0: 거리순, 1: 인기순, 2: 최신순
    @State private var showSortOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 내용
            ScrollView {
                VStack(spacing: 16) {
                    // 검색 바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("코스나 지역 검색", text: $searchText)
                            .font(.system(size: 16))
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(28)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 탭 선택 (내 코스 / 발견)
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation {
                                selectedTab = 0
                            }
                        }) {
                            Text("내 코스")
                                .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .medium))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(selectedTab == 0 ? .rtPrimary : .gray)
                                .background(
                                    selectedTab == 0 ?
                                        Color.rtPrimary.opacity(0.1) :
                                        Color.clear
                                )
                                .cornerRadius(16)
                        }
                        
                        Button(action: {
                            withAnimation {
                                selectedTab = 1
                                // 공개 코스 로드
                                if publicCourses.isEmpty {
                                    loadPublicCourses()
                                }
                            }
                        }) {
                            Text("발견")
                                .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .medium))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(selectedTab == 1 ? .rtPrimary : .gray)
                                .background(
                                    selectedTab == 1 ?
                                        Color.rtPrimary.opacity(0.1) :
                                        Color.clear
                                )
                                .cornerRadius(16)
                        }
                    }
                    .padding(4)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // 정렬 옵션
                    HStack {
                        Text(selectedTab == 0 ? "내 코스" : "공개 코스")
                            .font(.system(size: 18, weight: .bold))
                        
                        Spacer()
                        
                        // 정렬 드롭다운 버튼
                        Button(action: {
                            showSortOptions.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Text(getSortOptionText())
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 정렬 옵션 목록 (드롭다운)
                    if showSortOptions {
                        VStack(spacing: 0) {
                            Button(action: {
                                sortOption = 0
                                showSortOptions = false
                                sortCourses()
                            }) {
                                HStack {
                                    Text("거리순")
                                        .font(.system(size: 14))
                                    Spacer()
                                    if sortOption == 0 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(.rtPrimary)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            }
                            .foregroundColor(sortOption == 0 ? .rtPrimary : .primary)
                            
                            Divider()
                            
                            Button(action: {
                                sortOption = 1
                                showSortOptions = false
                                sortCourses()
                            }) {
                                HStack {
                                    Text("인기순")
                                        .font(.system(size: 14))
                                    Spacer()
                                    if sortOption == 1 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(.rtPrimary)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            }
                            .foregroundColor(sortOption == 1 ? .rtPrimary : .primary)
                            
                            Divider()
                            
                            Button(action: {
                                sortOption = 2
                                showSortOptions = false
                                sortCourses()
                            }) {
                                HStack {
                                    Text("최신순")
                                        .font(.system(size: 14))
                                    Spacer()
                                    if sortOption == 2 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(.rtPrimary)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            }
                            .foregroundColor(sortOption == 2 ? .rtPrimary : .primary)
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                    
                    // 코스 목록 표시
                    if isLoading {
                        // 로딩 중 표시
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                            .padding(.vertical, 30)
                    } else {
                        // 내 코스 또는 공개 코스 표시
                        let displayCourses = selectedTab == 0 ?
                            myCourses.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) } :
                            publicCourses.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
                        
                        if displayCourses.isEmpty {
                            // 코스가 없을 때 표시
                            VStack(spacing: 12) {
                                Image(systemName: "map")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text(selectedTab == 0 ? "내 코스가 없습니다" : "공개 코스가 없습니다")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text(selectedTab == 0 ? "첫 러닝 코스를 만들어보세요!" : "다른 검색어로 시도해보세요!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .padding(.vertical, 40)
                        } else {
                            // 코스 목록
                            VStack(spacing: 16) {
                                ForEach(displayCourses) { course in
                                    ExploreCourseCard(
                                        course: course,
                                        viewModel: viewModel,
                                        isFavorite: favoriteCourses.contains(course.id),
                                        toggleFavorite: { toggleFavorite(courseId: course.id) }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            loadMyCourses()
            loadFavoriteCourses()
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == 0 {
                loadMyCourses()
            } else {
                loadPublicCourses()
            }
        }
    }
    
    // MARK: - 헬퍼 함수들
    
    // 내 코스 로드
    private func loadMyCourses() {
        isLoading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("courses")
            .whereField("createdBy", isEqualTo: userId)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                }
                
                if let error = error {
                    print("내 코스 로드 오류: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("내 코스를 찾을 수 없음")
                    self.myCourses = []
                    return
                }
                
                // 코스 파싱 수정
                var courses: [Course] = []
                for document in documents {
                    let data = document.data()
                    
                    if let coordsData = data["coordinates"] as? [[String: Any]] {
                        let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let runCount = data["runCount"] as? Int ?? 0 // runCount 추가
                        
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
                            runCount: runCount // 추가된 필드
                        )
                        
                        courses.append(course)
                    }
                }
                
                DispatchQueue.main.async {
                    self.myCourses = courses
                    self.sortCourses()
                }
            }
    }
    
    // 공개 코스 로드
    private func loadPublicCourses() {
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("courses")
            .whereField("isPublic", isEqualTo: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                }
                
                if let error = error {
                    print("공개 코스 로드 오류: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("공개 코스를 찾을 수 없음")
                    self.publicCourses = []
                    return
                }
                
                print("공개 코스 로드: \(documents.count)개")
                
                // 코스 파싱
                var courses: [Course] = []
                for document in documents {
                    let data = document.data()
                    
                    if let coordsData = data["coordinates"] as? [[String: Any]] {
                        let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let runCount = data["runCount"] as? Int ?? 0 // runCount 추가

                        
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
                            runCount: runCount // 추가된 필드

                        )
                        
                        courses.append(course)
                    }
                }
                
                DispatchQueue.main.async {
                    self.publicCourses = courses
                    self.sortCourses()
                }
            }
    }
    
    // 즐겨찾기 코스 로드
    private func loadFavoriteCourses() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .collection("favorites")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("즐겨찾기 로드 오류: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                var favoriteIds: Set<String> = []
                for document in documents {
                    favoriteIds.insert(document.documentID)
                }
                
                DispatchQueue.main.async {
                    self.favoriteCourses = favoriteIds
                }
            }
    }
    
    // 즐겨찾기 토글
    private func toggleFavorite(courseId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let db = Firestore.firestore()
        let favoriteRef = db.collection("users")
            .document(userId)
            .collection("favorites")
            .document(courseId)
        
        // 상태 UI 먼저 업데이트
        if favoriteCourses.contains(courseId) {
            favoriteCourses.remove(courseId)
            
            // Firebase에서 삭제
            favoriteRef.delete { error in
                if let error = error {
                    print("즐겨찾기 삭제 오류: \(error)")
                    // 실패시 상태 복원
                    DispatchQueue.main.async {
                        self.favoriteCourses.insert(courseId)
                    }
                }
            }
        } else {
            favoriteCourses.insert(courseId)
            
            // Firebase에 추가
            favoriteRef.setData([
                "addedAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("즐겨찾기 추가 오류: \(error)")
                    // 실패시 상태 복원
                    DispatchQueue.main.async {
                        self.favoriteCourses.remove(courseId)
                    }
                }
            }
        }
    }
    
    // 코스 실행 횟수 가져오기 (샘플 - 실제로는 Firebase에서 가져와야 함)
    private func getRunCount(courseId: String) -> Int {
        // 실제로는 Firebase에서 해당 코스 ID로 실행된 런 수를 카운트해야 함
        // 여기서는 ID 마지막 두 자리를 사용한 샘플 값 반환
        let lastTwo = courseId.suffix(2)
        if let value = Int(lastTwo, radix: 16) {
            return value % 50 // 0-49 사이 값 반환
        }
        return Int.random(in: 0...30) // 랜덤 값
    }
    
    // 정렬 옵션 텍스트 가져오기
    private func getSortOptionText() -> String {
        switch sortOption {
        case 0:
            return "거리순"
        case 1:
            return "인기순"
        case 2:
            return "최신순"
        default:
            return "거리순"
        }
    }
    
    // 코스 정렬하기
    private func sortCourses() {
        switch sortOption {
        case 0: // 거리순
            myCourses.sort { $0.distance < $1.distance }
            publicCourses.sort { $0.distance < $1.distance }
        case 1: // 인기순 - 샘플 데이터 대신 실제 runCount 사용
            myCourses.sort { $0.runCount > $1.runCount }
            publicCourses.sort { $0.runCount > $1.runCount }
        case 2: // 최신순
            myCourses.sort { $0.createdAt > $1.createdAt }
            publicCourses.sort { $0.createdAt > $1.createdAt }
        default:
            break
        }
    }
    
    // 예상 시간 계산 - 범용적으로 처리
    private func calculateEstimatedTime(distance: Double) -> String {
        // 사용자의 평균 페이스 또는 기본값 사용
        var pace = viewModel.getUserAveragePace()
        
        // 페이스가 비정상적인 경우(0이거나 너무 큰 경우) 기본값 사용
        if pace <= 0 || pace > 15 * 60 { // 15분/km보다 느린 경우 기본값 사용
            pace = 6 * 60 // 기본 페이스: 6분/km
        }
        
        let estimatedSeconds = (distance / 1000) * pace
        return Formatters.formatDuration(Int(estimatedSeconds))
    }
    
    // 코스 태그 설정
    private func getCourseTag(course: Course) -> String {
        // 코스 거리에 따라 태그 설정
        let distanceKm = course.distance / 1000
        
        if distanceKm < 3 {
            return "3km 미만"
        } else if distanceKm < 5 {
            return "5km 미만"
        } else if distanceKm < 10 {
            return "10km 미만"
        } else {
            return "장거리"
        }
    }
}
