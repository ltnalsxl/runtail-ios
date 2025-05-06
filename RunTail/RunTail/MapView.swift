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

// 둥근 모서리 커스텀 모디파이어
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
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
    @Environment(\.colorScheme) var colorScheme
    
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
    
    // 다크 그라데이션 - 더 진한 색상
    let darkGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 74/255, green: 55/255, blue: 126/255), // #4A377E (다크 퍼플)
            Color(red: 26/255, green: 86/255, blue: 155/255)  // #1A569B (다크 블루)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // 초기화 및 데이터 로드
    var body: some View {
        NavigationView {
            ZStack {
                // 선택된 탭에 따라 다른 콘텐츠 표시
                Group {
                    if selectedTab == 0 {
                        homeTabView
                    } else if selectedTab == 1 {
                        exploreTabView
                    } else if selectedTab == 2 {
                        activityTabView
                    } else if selectedTab == 3 {
                        profileTabView
                    }
                }
                
                // 하단 탭 바
                VStack {
                    Spacer()
                    customTabBar
                }
                
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
                    
                    // 데이터 로드 함수 호출
                    loadUserData()
                    loadRecentRuns()
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
    
    // 커스텀 탭 바
    var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(index))
                            .font(.system(size: 22))
                        
                        Text(tabTitle(index))
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == index ?
                            themeColor.opacity(0.1) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .foregroundColor(
                        selectedTab == index ?
                            themeColor :
                            Color.gray
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(Color.white)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
    }
    
    // 홈 탭 뷰
    var homeTabView: some View {
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
                .padding(.bottom, 80) // 하단 탭바 공간 확보
            }
        }
    }
    
    // 탐색 탭 뷰
    var exploreTabView: some View {
        VStack(spacing: 0) {
            // 상단 상태 바
            ZStack {
                themeGradient
                Text("탐색")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(height: 44)
            
            // 내용 (예시)
            ScrollView {
                VStack(spacing: 16) {
                    // 검색 바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("코스나 지역 검색", text: .constant(""))
                            .font(.system(size: 16))
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(28)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 카테고리 제목
                    HStack {
                        Text("추천 코스")
                            .font(.system(size: 18, weight: .bold))
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 추천 코스 목록 (예시)
                    ForEach(0..<5) { index in
                        HStack(spacing: 16) {
                            // 코스 이미지
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(themeColor.opacity(0.1))
                                
                                Image(systemName: "map.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(themeColor)
                            }
                            .frame(width: 80, height: 80)
                            
                            // 코스 정보
                            VStack(alignment: .leading, spacing: 4) {
                                Text("인기 코스 \(index + 1)")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("5.3km · 약 30분")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                // 태그
                                HStack {
                                    Text("공원")
                                        .font(.system(size: 12))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(themeColor.opacity(0.1))
                                        .foregroundColor(themeColor)
                                        .cornerRadius(12)
                                    
                                    Text("인기")
                                        .font(.system(size: 12))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .foregroundColor(Color.orange)
                                        .cornerRadius(12)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 80)
            }
        }
    }
    
    // 활동 탭 뷰
    var activityTabView: some View {
        VStack(spacing: 0) {
            // 상단 상태 바
            ZStack {
                themeGradient
                Text("활동")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(height: 44)
            
            // 달력 뷰 (예시)
            VStack(spacing: 10) {
                // 월 선택
                HStack {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(themeColor)
                    }
                    
                    Spacer()
                    
                    Text("2025년 5월")
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(themeColor)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // 요일 헤더
                HStack(spacing: 0) {
                    ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(day == "일" ? .red : .primary)
                    }
                }
                .padding(.vertical, 8)
                
                // 날짜 그리드 (간단한 예시)
                VStack(spacing: 8) {
                    ForEach(0..<5) { week in
                        HStack(spacing: 0) {
                            ForEach(1...7, id: \.self) { day in
                                let date = week * 7 + day
                                if date <= 31 {
                                    ZStack {
                                        Circle()
                                            .fill(date == 15 ? themeColor : Color.clear)
                                            .frame(width: 36, height: 36)
                                        
                                        Text("\(date)")
                                            .font(.system(size: 14))
                                            .foregroundColor(date == 15 ? .white : (day == 1 ? .red : .primary))
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Text("")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom)
            
            // 통계 요약
            VStack(spacing: 16) {
                Text("이번 달 통계")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // 통계 카드들
                HStack(spacing: 12) {
                    // 거리 카드
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(themeColor)
                            
                            Text("총 거리")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Text("42.5km")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // 시간 카드
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(exploreCategories[1].color)
                            
                            Text("총 시간")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Text("5시간 12분")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // 러닝 히스토리 타이틀
                Text("최근 러닝")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 예시 러닝 기록들
                ForEach(0..<3) { index in
                    HStack(spacing: 16) {
                        // 날짜 표시
                        VStack(spacing: 4) {
                            Text("5월")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Text("\(10 + index)")
                                .font(.system(size: 18, weight: .bold))
                            
                            Text("2025")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 50)
                        
                        // 구분선
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1, height: 50)
                        
                        // 러닝 정보
                        VStack(alignment: .leading, spacing: 4) {
                            Text("저녁 러닝")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("5.2km · 31분 12초")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // 페이스
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("페이스")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Text("6'02\"")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(themeColor)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 80)
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // 프로필 탭 뷰
    var profileTabView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // 프로필 헤더
                    VStack(spacing: 16) {
                        // 배경 이미지
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(colorScheme == .dark ? darkGradient : themeGradient)
                                .frame(height: 150)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("프로필")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("러닝 활동 및 설정")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.leading)
                                .padding(.bottom)
                                
                                Spacer()
                            }
                        }
                        
                        // 프로필 정보
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(themeColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userEmail)
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("RunTail 러너")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                // 미니 통계
                                HStack(spacing: 12) {
                                    Label("\(formatDistance(totalDistance))", systemImage: "figure.run")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(themeColor)
                                    
                                    Text("•")
                                        .foregroundColor(.gray)
                                    
                                    Text("이번 주 \(formatDistance(weeklyDistance))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 4)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // 설정 섹션 - Material Design 스타일
                    VStack(spacing: 0) {
                        // 섹션 헤더
                        HStack {
                            Text("설정")
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // 설정 옵션들
                        Group {
                            Button(action: {
                                // 프로필 설정 액션
                            }) {
                                settingRow(icon: "person.fill", title: "프로필 수정", iconColor: themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 알림 설정 액션
                            }) {
                                settingRow(icon: "bell.fill", title: "알림 설정", iconColor: themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 개인정보 설정 액션
                            }) {
                                settingRow(icon: "lock.fill", title: "개인정보 설정", iconColor: themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // 로그아웃 버튼
                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                settingRow(icon: "arrow.right.square", title: "로그아웃", iconColor: .red)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // 앱 정보 섹션
                    VStack(spacing: 0) {
                        // 섹션 헤더
                        HStack {
                            Text("앱 정보")
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // 앱 정보 옵션들
                        Group {
                            Button(action: {
                                // 앱 버전 정보
                            }) {
                                settingRow(icon: "info.circle.fill", title: "버전 정보", subtitle: "1.0.0", iconColor: themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 이용약관
                            }) {
                                settingRow(icon: "doc.text.fill", title: "이용약관", iconColor: themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 개인정보 처리방침
                            }) {
                                settingRow(icon: "hand.raised.fill", title: "개인정보 처리방침", iconColor: themeColor)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
                .padding(.bottom, 80)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // 설정 행 헬퍼 함수
    func settingRow(icon: String, title: String, subtitle: String? = nil, iconColor: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(title == "로그아웃" ? .red : .primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
    
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
        .padding(.vertical, 12)
        .background(themeGradient) // 그라데이션 적용
        .foregroundColor(.white)
    }
    
    // 지도 섹션
    var mapSection: some View {
        ZStack(alignment: .bottom) {
            // 지도 (iOS 17에서 변경된 방식)
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map(initialPosition: MapCameraPosition.region(region)) {
                    UserAnnotation()
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            } else {
                Map(coordinateRegion: $region, showsUserLocation: true)
                    .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            #else
            Map(coordinateRegion: $region, showsUserLocation: true)
                .frame(height: UIScreen.main.bounds.height * 0.5)
            #endif
            
            // 검색 바 - 스타일 개선
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .top)
            
            // 지도 컨트롤 - 스타일 개선
            mapControls
            
            // 달리기 시작 버튼 - 스타일 개선
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
                            .padding(.leading, 4)
                        
                        Text("장소 또는 코스 검색")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 48, height: 48)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                
                                Text("+")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.black)
                            }
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
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 48, height: 48)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                
                                Text("-")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                
                // 달리기 시작 버튼
                var startRunningButton: some View {
                    VStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.spring()) {
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
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(themeGradient)
                            .foregroundColor(.white)
                            .cornerRadius(28)
                            .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        if isStartRunExpanded {
                            VStack(spacing: 0) {
                                // 자유 달리기 옵션
                                Button(action: {
                                    // 자유 달리기 시작 로직 구현
                                    print("자유 달리기 시작")
                                    withAnimation(.spring()) {
                                        isStartRunExpanded = false
                                    }
                                }) {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(themeColor.opacity(0.1))
                                                .frame(width: 48, height: 48)
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
                                    .padding(16)
                                }
                                
                                Divider()
                                    .padding(.horizontal)
                                
                                // 코스 따라 달리기 옵션
                                Button(action: {
                                    // 코스 따라 달리기 로직 구현
                                    print("코스 따라 달리기")
                                    withAnimation(.spring()) {
                                        isStartRunExpanded = false
                                    }
                                }) {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(exploreCategories[2].color.opacity(0.1))
                                                .frame(width: 48, height: 48)
                                            Image(systemName: "map.fill")
                                                .foregroundColor(exploreCategories[2].color)
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
                                    .padding(16)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(28)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                
                // 통계 바 - 미니 그래프 추가
                var statsBar: some View {
                    HStack {
                        Spacer()
                        
                        // 총 달린 거리
                        VStack(spacing: 6) {
                            Text("총 달린 거리")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            // 거리 표시와 미니 그래프
                            VStack(spacing: 2) {
                                Text(formatDistance(totalDistance))
                                    .font(.system(size: 16, weight: .bold))
                                
                                // 미니 그래프
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(themeColor)
                                    .frame(width: 60, height: 4)
                            }
                        }
                        
                        Spacer()
                        
                        // 이번 주
                        VStack(spacing: 6) {
                            Text("이번 주")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            // 거리 표시와 미니 그래프
                            VStack(spacing: 2) {
                                Text(formatDistance(weeklyDistance))
                                    .font(.system(size: 16, weight: .bold))
                                
                                // 미니 그래프 (주간 데이터 비율 반영)
                                let ratio = min(max(weeklyDistance / (totalDistance > 0 ? totalDistance : 1), 0.1), 1.0)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(exploreCategories[1].color)
                                    .frame(width: 60 * ratio, height: 4)
                            }
                        }
                        
                        Spacer()
                        
                        // 오늘
                        VStack(spacing: 6) {
                            Text("오늘")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            // 거리 표시와 미니 그래프
                            VStack(spacing: 2) {
                                Text(formatDistance(todayDistance))
                                    .font(.system(size: 16, weight: .bold))
                                
                                // 미니 그래프 (일간 데이터 비율 반영)
                                let ratio = min(max(todayDistance / (weeklyDistance > 0 ? weeklyDistance : 1), 0.1), 1.0)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(exploreCategories[2].color)
                                    .frame(width: 60 * ratio, height: 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                
                // 최근 활동 섹션
                var recentActivitiesSection: some View {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("최근 활동")
                                .font(.system(size: 18, weight: .bold))
                            
                            Spacer()
                            
                            Button(action: {
                                // 모두 보기 기능 구현
                                selectedTab = 2 // 활동 탭으로 이동
                            }) {
                                Text("모두 보기")
                                    .font(.system(size: 14))
                                    .foregroundColor(themeColor)
                            }
                        }
                        
                        if recentRuns.isEmpty {
                            // 빈 상태 UI
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(themeColor.opacity(0.6))
                                
                                Text("최근 러닝 기록이 없습니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Text("달리기를 시작하고 첫 기록을 만들어보세요!")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                            .cornerRadius(28)
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
                        HStack(spacing: 16) {
                            // 런닝 아이콘
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "figure.run")
                                    .foregroundColor(themeColor)
                                    .font(.system(size: 20))
                            }
                            
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
                        .padding(16)
                    }
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                
                // 탐색 섹션
                var exploreSection: some View {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("탐색")
                                .font(.system(size: 18, weight: .bold))
                            
                            Spacer()
                            
                            Button(action: {
                                // 더보기 기능 구현
                                selectedTab = 1 // 탐색 탭으로 이동
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
                            .padding(.bottom, 8) // 그림자가 잘리지 않도록
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // 탐색 카테고리 카드
                func exploreCategoryCard(_ category: ExploreCategory) -> some View {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(category.color.opacity(0.1))
                            .shadow(color: category.color.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: category.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(category.color)
                            }
                            
                            Text(category.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(category.color)
                        }
                        .padding(.vertical, 16)
                    }
                    .frame(width: 140, height: 120)
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
