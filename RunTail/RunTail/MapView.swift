import SwiftUI
import MapKit
import Firebase
import FirebaseAuth
import FirebaseFirestore

// 코스 모델
struct Course: Identifiable {
    let id: String
    let title: String
    let distance: Double  // 미터 단위
    let coordinates: [CLLocationCoordinate2D]
    let createdAt: Date
    let createdBy: String
    let isPublic: Bool
}

// 러닝 기록 모델
struct Run: Identifiable {
    let id: String
    let courseId: String
    let duration: Int      // 초 단위
    let pace: Int          // 초/km 단위
    let paceStr: String    // 문자열 표시 (e.g. "6'20"")
    let runAt: Date
    let trail: [CLLocationCoordinate2D]
    let userId: String
}

// 탐색 카테고리
struct ExploreCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

// 홈 화면 뷰
struct MapView: View {
    // 사용자 데이터
    @State private var userEmail: String = ""
    @State private var userId: String = ""
    
    // 지도 관련 상태
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), // 서울
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // 달리기 시작 드롭다운 상태
    @State private var isStartRunExpanded = false
    
    // 탭 상태
    @State private var selectedTab = 0
    
    // 데이터 상태
    @State private var recentRuns: [Run] = []
    @State private var myCourses: [Course] = []
    @State private var totalDistance: Double = 0
    @State private var weeklyDistance: Double = 0
    @State private var todayDistance: Double = 0
    
    // 로그아웃 관련 상태 추가
    @State private var showLogoutAlert = false
    @State private var isLoggedOut = false
    
    // 내비게이션을 위한 환경 객체 추가
    @Environment(\.presentationMode) var presentationMode
    
    // 탐색 카테고리 - 색상을 테마와 맞게 업데이트
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
    
    // 초기화 및 데이터 로드
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // 메인 콘텐츠
                TabView(selection: $selectedTab) {
                    // 홈 탭
                    homeTab
                        .tag(0)
                    
                    // 탐색 탭
                    Text("탐색 화면")
                        .tag(1)
                    
                    // 활동 탭
                    Text("활동 화면")
                        .tag(2)
                    
                    // 프로필 탭 - 로그아웃 기능 추가
                    profileTab
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 하단 탭 바
                bottomTabBar
                
                // 로그인 화면으로 돌아가기 위한 NavigationLink
                NavigationLink(destination: ContentView().navigationBarHidden(true),
                              isActive: $isLoggedOut) {
                    EmptyView()
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarHidden(true)
            .onAppear {
                // 현재 로그인한 사용자 정보 가져오기
                if let user = Auth.auth().currentUser {
                    userEmail = user.email ?? ""
                    userId = user.uid
                    
                    // 사용자 데이터 로드
                    loadUserData()
                    
                    // 최근 러닝 데이터 로드
                    loadRecentRuns()
                    
                    // 내 코스 데이터 로드
                    loadMyCourses()
                }
            }
            // 로그아웃 확인 알림
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("로그아웃"),
                    message: Text("정말 로그아웃 하시겠습니까?"),
                    primaryButton: .destructive(Text("로그아웃")) {
                        logout()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
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
    
    // 홈 탭 뷰
    var homeTab: some View {
        VStack(spacing: 0) {
            // 상단 상태 바
            statusBar
            
            // 지도 영역 - 상단 절반
            mapSection
            
            // 통계 바
            statsBar
            
            // 스크롤 가능한 컨텐츠 영역
            ScrollView {
                VStack(spacing: 16) {
                    // 최근 활동 섹션
                    recentActivitiesSection
                    
                    // 탐색 섹션
                    exploreSection
                }
                .padding(.bottom, 60) // 하단 탭바 공간 확보
            }
        }
    }
    
    // 프로필 탭 뷰 - 로그아웃 기능 포함
    var profileTab: some View {
        VStack(spacing: 20) {
            // 상단 상태 바
            statusBar
            
            // 프로필 헤더
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(themeColor)
                    .padding(.top, 20)
                
                Text(userEmail)
                    .font(.headline)
                
                Text("RunTail 러너")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Divider()
                .padding(.horizontal)
            
            // 설정 섹션
            VStack(spacing: 5) {
                Text("설정")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // 설정 옵션들
                Button(action: {
                    // 프로필 설정 액션
                }) {
                    HStack {
                        Image(systemName: "person.fill")
                            .frame(width: 24, height: 24)
                        Text("프로필 수정")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    // 알림 설정 액션
                }) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .frame(width: 24, height: 24)
                        Text("알림 설정")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    // 개인정보 설정 액션
                }) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .frame(width: 24, height: 24)
                        Text("개인정보 설정")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                
                // 로그아웃 버튼
                Button(action: {
                    showLogoutAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.red)
                        Text("로그아웃")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - 데이터 로드 함수
    
    // 사용자 데이터 로드
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
            .getDocuments { snapshot, error in
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
                self.recentRuns = runs
                self.totalDistance = totalDist
                self.weeklyDistance = weeklyDist
                self.todayDistance = todayDist
            }
    }
    
    // 내 코스 데이터 로드
    func loadMyCourses() {
        let db = Firestore.firestore()
        db.collection("courses")
            .whereField("createdBy", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
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
                self.myCourses = courses
            }
    }
    
    // MARK: - UI 컴포넌트
    
    // 상단 상태 바
    var statusBar: some View {
        HStack {
            Text("RunTail")
                .font(.system(size: 18, weight: .bold))
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("GPS")
                    .font(.system(size: 12, weight: .medium))
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeGradient) // 그라데이션 적용
        .foregroundColor(.white)
    }
    
    // 지도 섹션
    var mapSection: some View {
        ZStack(alignment: .bottom) {
            // 지도
            Map(coordinateRegion: $region, showsUserLocation: true)
                .frame(height: UIScreen.main.bounds.height * 0.5)
            
            // 검색 바
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .top)
            
            // 지도 컨트롤
            mapControls
            
            // 달리기 시작 버튼 및 드롭다운
            startRunningButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }
    
    // 검색 바
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            Text("장소 또는 코스 검색")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            Spacer()
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 0)
        .frame(height: 36)
    }
    
    // 지도 컨트롤
    var mapControls: some View {
        VStack(spacing: 8) {
            Button(action: {
                // 확대
                withAnimation {
                    region.span = MKCoordinateSpan(
                        latitudeDelta: max(region.span.latitudeDelta * 0.5, 0.001),
                        longitudeDelta: max(region.span.longitudeDelta * 0.5, 0.001)
                    )
                }
            }) {
                Text("+")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            
            Button(action: {
                // 축소
                withAnimation {
                    region.span = MKCoordinateSpan(
                        latitudeDelta: min(region.span.latitudeDelta * 2, 1),
                        longitudeDelta: min(region.span.longitudeDelta * 2, 1)
                    )
                }
            }) {
                Text("-")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    // 달리기 시작 버튼
    var startRunningButton: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation {
                    isStartRunExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                    Text("달리기 시작하기")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Image(systemName: isStartRunExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(themeGradient) // 그라데이션 적용
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: themeColor.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            
            if isStartRunExpanded {
                VStack(spacing: 0) {
                    // 자유 달리기 옵션
                    Button(action: {
                        // 자유 달리기 시작 로직 구현
                        print("자유 달리기 시작")
                        withAnimation {
                            isStartRunExpanded = false
                        }
                        // 자유 달리기 화면으로 이동
                        // 여기에 네비게이션 코드 추가
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "play.fill")
                                    .foregroundColor(themeColor)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("자유 달리기")
                                    .font(.system(size: 16, weight: .medium))
                                Text("달리면서 새 코스 만들기")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // 코스 따라 달리기 옵션
                    Button(action: {
                        // 코스 따라 달리기 로직 구현
                        print("코스 따라 달리기")
                        withAnimation {
                            isStartRunExpanded = false
                        }
                        // 코스 선택 화면으로 이동
                        // 여기에 네비게이션 코드 추가
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "map.fill")
                                    .foregroundColor(themeColor)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("코스 따라 달리기")
                                    .font(.system(size: 16, weight: .medium))
                                Text("기존 코스 선택하기")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            }
        }
    }
    
    // 통계 바
    var statsBar: some View {
        HStack {
            Spacer()
            
            VStack {
                Text("총 달린 거리")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(formatDistance(totalDistance))
                    .font(.system(size: 16, weight: .bold))
            }
            
            Spacer()
            
            VStack {
                Text("이번 주")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(formatDistance(weeklyDistance))
                    .font(.system(size: 16, weight: .bold))
            }
            
            Spacer()
            
            VStack {
                Text("오늘")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(formatDistance(todayDistance))
                    .font(.system(size: 16, weight: .bold))
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
    
    // 최근 활동 섹션
    var recentActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 활동")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    // 모두 보기 기능 구현
                    // 여기에 네비게이션 코드 추가
                }) {
                    Text("모두 보기")
                        .font(.system(size: 14))
                        .foregroundColor(themeColor)
                }
            }
            
            if recentRuns.isEmpty {
                Text("최근 러닝 기록이 없습니다.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(recentRuns) { run in
                    runCard(run)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // 달리기 기록 카드
    func runCard(_ run: Run) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getCourseTitle(courseId: run.courseId))
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("\(calculateDistance(coordinates: run.trail)) · \(formatDuration(run.duration))")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDate(run.runAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .foregroundColor(themeColor)
                            .font(.system(size: 12))
                        
                        Text(run.paceStr)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
    
    // 탐색 섹션
    var exploreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("탐색")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    // 더보기 기능 구현
                    // 여기에 네비게이션 코드 추가
                }) {
                    Text("더보기")
                        .font(.system(size: 14))
                        .foregroundColor(themeColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(exploreCategories) { category in
                        exploreCategoryCard(category)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // 탐색 카테고리 카드
    func exploreCategoryCard(_ category: ExploreCategory) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(category.color.opacity(0.2))
            
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(category.color)
                
                Text(category.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(category.color)
            }
        }
        .frame(width: 120, height: 90)
    }
    
    // 하단 탭 바
    var bottomTabBar: some View {
        HStack {
            ForEach(0..<4) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(index))
                            .font(.system(size: 20))
                        
                        Text(tabTitle(index))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(selectedTab == index ? themeColor : Color.gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }
    
    // MARK: - 유틸리티 함수
    
    // 탭 아이콘
        func tabIcon(_ index: Int) -> String {
            switch index {
            case 0: return "house.fill"
            case 1: return "map.fill"
            case 2: return "chart.bar.fill"
            case 3: return "person.fill"
            default: return ""
            }
        }
        
        // 탭 제목
        func tabTitle(_ index: Int) -> String {
            switch index {
            case 0: return "홈"
            case 1: return "탐색"
            case 2: return "활동"
            case 3: return "프로필"
            default: return ""
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
        
        // 좌표 배열로부터 거리 계산
        func calculateDistance(coordinates: [CLLocationCoordinate2D]) -> String {
            // 실제로는 좌표 사이의 거리를 계산해야 함
            // 간단한 구현을 위해 좌표 개수에 비례한 값 반환
            let distance = Double(coordinates.count) * 10 // 예시 값
            return formatDistance(distance)
        }
        
        // 거리 형식 지정
        func formatDistance(_ distance: Double) -> String {
            let distanceInKm = distance / 1000
            if distanceInKm < 1 {
                return String(format: "%.0fm", distance)
            } else {
                return String(format: "%.1fkm", distanceInKm)
            }
        }
        
        // 시간 형식 지정
        func formatDuration(_ seconds: Int) -> String {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            
            if minutes < 60 {
                return "\(minutes)분 \(remainingSeconds)초"
            } else {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                return "\(hours)시간 \(remainingMinutes)분"
            }
        }
        
        // 날짜 형식 지정
        func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: date)
        }
    }

    // 미리보기
    struct MapView_Previews: PreviewProvider {
        static var previews: some View {
            MapView()
        }
    }
