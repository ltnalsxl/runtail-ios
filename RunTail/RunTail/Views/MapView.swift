//
//  MapView.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//  Updated with location service and viewModel connection
//

import SwiftUI
import MapKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

struct MapView: View {
    // MARK: - 뷰모델
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationService = LocationService()
    
    // MARK: - 상태
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var showLocationPermissionAlert = false
    @State private var showNoGPSSignalAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 선택된 탭에 따라 다른 콘텐츠 표시
                if viewModel.selectedTab == 0 {
                    // 홈 화면 (지도 화면)
                    VStack(spacing: 0) {
                        headerBar(showTitle: false, showGPS: true)
                        HomeTabView(viewModel: viewModel, locationService: locationService)
                            .environmentObject(viewModel)
                            .environmentObject(locationService)
                            .environment(\.checkBeforeStartRunning, checkBeforeStartRunning)
                    }
                } else if viewModel.selectedTab == 1 {
                    // 탐색 화면
                    VStack(spacing: 0) {
                        headerBar(title: "탐색", showGPS: false)
                        ExploreTabView(viewModel: viewModel)
                    }
                } else if viewModel.selectedTab == 2 {
                    // 활동 화면
                    VStack(spacing: 0) {
                        headerBar(title: "활동", showGPS: false)
                        ActivityTabView(viewModel: viewModel)
                    }
                } else if viewModel.selectedTab == 3 {
                    // 프로필 화면
                    VStack(spacing: 0) {
                        headerBar(title: "프로필", subtitle: "러닝 활동 및 설정", showGPS: false)
                        ProfileTabView(viewModel: viewModel, colorScheme: colorScheme)
                    }
                }
                
                // 하단 탭 바
                VStack {
                    Spacer()
                    customTabBar
                }
                
                // 로그인 화면으로 돌아가기 위한 NavigationLink
                NavigationLink(destination: LoginView().navigationBarHidden(true),
                              isActive: $viewModel.isLoggedOut) {
                    EmptyView()
                }
                
                // 코스 상세 화면으로 이동하기 위한 NavigationLink
                NavigationLink(
                    destination: Group {
                        if let courseId = viewModel.selectedCourseId,
                           let course = viewModel.getCourse(by: courseId) {
                            CourseDetailView(course: course)
                                .environmentObject(viewModel)
                                .environmentObject(locationService)
                                .navigationBarHidden(true)
                        }
                    },
                    isActive: $viewModel.showCourseDetailView,
                    label: { EmptyView() }
                )
            }
            .ignoresSafeArea(edges: [.top])
            .navigationBarHidden(true)
            // 로그아웃 확인 알림
            .alert(isPresented: $viewModel.showLogoutAlert) {
                Alert(
                    title: Text("로그아웃"),
                    message: Text("정말 로그아웃 하시겠습니까?"),
                    primaryButton: .destructive(Text("로그아웃")) {
                        viewModel.logout()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
            // 위치 권한 알림
            .alert("위치 권한 필요", isPresented: $showLocationPermissionAlert) {
                Button("설정") {
                    // 앱 설정으로 이동
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("러닝 경로를 기록하려면 위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.")
            }
            // GPS 신호 약함 알림
            .alert("GPS 신호 약함", isPresented: $showNoGPSSignalAlert) {
                Button("계속", role: .destructive) {
                    // 사용자가 강제로 계속하기 원하는 경우
                    startRunningSession()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("GPS 신호가 약합니다. 이로 인해 러닝 경로가 부정확하게 기록될 수 있습니다. 개방된 장소로 이동하거나 잠시 후 다시 시도해주세요.")
            }
        }
        .onAppear {
            setupLocationServiceAndViewModel()
        }
    }
    
    // MARK: - 통합된 헤더바
    func headerBar(title: String? = nil, subtitle: String? = nil, showTitle: Bool = true, showGPS: Bool = false) -> some View {
        ZStack {
            // 배경
            viewModel.themeGradient
                .ignoresSafeArea(edges: .top)
            
            VStack(spacing: 0) {
                // RunTail 타이틀 영역
                HStack {
                    Text("RunTail")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // GPS 상태 (지도 화면에만 표시)
                    if showGPS {
                        HStack(spacing: 4) {
                            Text("GPS")
                                .font(.system(size: 12, weight: .medium))
                            
                            Circle()
                                .fill(gpsSignalColor)
                                .frame(width: 8, height: 8)
                        }
                        .foregroundColor(.white)
                    }
                }
                .padding(.top, getSafeAreaTop())
                .padding(.horizontal, 16)
                .padding(.bottom, showTitle ? 8 : 16)
                
                // 화면 제목 (필요한 경우에만)
                if showTitle, let title = title {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, subtitle != nil ? 4 : 12)
                    
                    // 부제목 (있는 경우에만)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .frame(height: calculateHeaderHeight(showTitle: showTitle, hasSubtitle: subtitle != nil))
    }
    
    // 헤더 높이 계산
    func calculateHeaderHeight(showTitle: Bool, hasSubtitle: Bool) -> CGFloat {
        let safeAreaTop = getSafeAreaTop()
        let baseTitleHeight: CGFloat = 44 // RunTail 타이틀 영역 높이
        
        if !showTitle {
            return safeAreaTop + baseTitleHeight
        }
        
        let titleHeight: CGFloat = 44 // 제목 영역 높이
        let subtitleHeight: CGFloat = hasSubtitle ? 30 : 0 // 부제목 높이
        
        return safeAreaTop + baseTitleHeight + titleHeight + subtitleHeight
    }
    
    // 안전 영역 상단 높이를 가져오는 함수
    func getSafeAreaTop() -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        
        return keyWindow?.safeAreaInsets.top ?? 0
    }
    
    // GPS 신호 강도에 따른 색상
    var gpsSignalColor: Color {
        switch locationService.gpsSignalStrength {
        case 0:
            return .red
        case 1:
            return .orange
        case 2:
            return .yellow
        case 3, 4:
            return .green
        default:
            return .gray
        }
    }
    
    // MARK: - 초기 설정
    private func setupLocationServiceAndViewModel() {
        // LocationService와 ViewModel 연결
        locationService.onLocationUpdate = { coordinate in
            if viewModel.isRecording {
                viewModel.addLocationToRecording(coordinate: coordinate)
            }
        }
        
        // 위치 권한 확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !locationService.checkLocationServicesStatus() {
                showLocationPermissionAlert = true
            }
        }
    }
    
    // MARK: - 러닝 세션 시작
    private func startRunningSession() {
        // 위치 서비스 정확도 높이기
        locationService.startHighAccuracyLocationUpdates()
        
        // 러닝 기록 시작
        viewModel.startRecording()
    }
    
    // MARK: - 러닝 시작 전 체크
    func checkBeforeStartRunning(completion: @escaping (Bool) -> Void) {
        // 위치 권한 확인
        if !locationService.checkLocationServicesStatus() {
            showLocationPermissionAlert = true
            completion(false)
            return
        }
        
        // GPS 신호 강도 확인
        if locationService.gpsSignalStrength < 2 {
            showNoGPSSignalAlert = true
            completion(false)
            return
        }
        
        completion(true)
    }
    
    // MARK: - 커스텀 탭 바
    var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    withAnimation(.spring()) {
                        viewModel.selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.tabIcon(index))
                            .font(.system(size: 22))
                        
                        Text(viewModel.tabTitle(index))
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.selectedTab == index ?
                            viewModel.themeColor.opacity(0.1) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .foregroundColor(
                        viewModel.selectedTab == index ?
                            viewModel.themeColor :
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
}

// MARK: - 환경 키 정의
struct CheckBeforeStartRunningKey: EnvironmentKey {
    static let defaultValue: ((@escaping (Bool) -> Void) -> Void) = { _ in }
}

extension EnvironmentValues {
    var checkBeforeStartRunning: (@escaping (Bool) -> Void) -> Void {
        get { self[CheckBeforeStartRunningKey.self] }
        set { self[CheckBeforeStartRunningKey.self] = newValue }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
