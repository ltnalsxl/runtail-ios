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
                Group {
                    if viewModel.selectedTab == 0 {
                        VStack(spacing: 0) {
                            topBarWithTitle("RunTail")
                            homeTabView
                        }
                    } else if viewModel.selectedTab == 1 {
                        VStack(spacing: 0) {
                            topBarWithTitle("탐색")
                            exploreTabView
                        }
                    } else if viewModel.selectedTab == 2 {
                        VStack(spacing: 0) {
                            topBarWithTitle("활동")
                            activityTabView
                        }
                    } else if viewModel.selectedTab == 3 {
                        VStack(spacing: 0) {
                            topBarWithTitle("프로필")
                            profileTabView
                        }
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
            .edgesIgnoringSafeArea([.top,.bottom])
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
    
    // MARK: - 상단 바 헬퍼 함수
    func topBarWithTitle(_ title: String) -> some View {
        VStack(spacing: 0) {
            // 상단 상태 바 (앱 이름 및 GPS 상태)
            HStack {
                Text("RunTail")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // GPS 상태 표시
                HStack(spacing: 4) {
                    Text("GPS")
                        .font(.system(size: 12, weight: .medium))
                    
                    // GPS 신호 강도에 따른 색상 변경
                    Circle()
                        .fill(gpsSignalColor)
                        .frame(width: 8, height: 8)
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, getSafeAreaTop())
            .padding(.bottom, 4)
            
            // 섹션 제목 (인자로 받은 제목)
            if title != "RunTail" {  // RunTail이 아닌 경우에만 별도 제목 표시
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                // RunTail일 경우 간격만 추가
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 4)
            }
            
            // 구분선
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
        }
        .background(viewModel.themeGradient)
        .foregroundColor(.white)
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
    
    // MARK: - 홈 탭 뷰
    var homeTabView: some View {
        HomeTabView(viewModel: viewModel, locationService: locationService)
            .environmentObject(viewModel)
            .environmentObject(locationService)
            .environment(\.checkBeforeStartRunning, checkBeforeStartRunning)
    }
    
    // MARK: - 탐색 탭 뷰
    var exploreTabView: some View {
        ExploreTabView(viewModel: viewModel)
    }
    
    // MARK: - 활동 탭 뷰
    var activityTabView: some View {
        ActivityTabView(viewModel: viewModel)
    }
    
    // MARK: - 프로필 탭 뷰
    var profileTabView: some View {
        ProfileTabView(viewModel: viewModel, colorScheme: colorScheme)
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
