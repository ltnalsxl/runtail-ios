//
//  MapView.swift
//  RunTail
//
//  Updated on 5/10/25.
//

import SwiftUI
import MapKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

// 안전 영역 상단 높이를 가져오는 함수 - 전역 함수로 변경
func getSafeAreaTop() -> CGFloat {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
        return 44 // 기본값
    }
    return window.safeAreaInsets.top
}

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
        GeometryReader { geometry in
            ZStack {
                // 배경색 - 전체 화면 채우기
                Color.rtBackground
                    .ignoresSafeArea(.all)
                
                // 메인 콘텐츠
                VStack(spacing: 0) {
                    // 상단 헤더 - 고정 높이
                    headerBar(for: viewModel.selectedTab)
                        .frame(height: 44 + getSafeAreaTop())
                        .zIndex(2) // 다른 콘텐츠 위에 표시
                    
                    // 탭 콘텐츠 - 남은 공간 모두 사용
                    Group {
                        if viewModel.selectedTab == 0 {
                            // 홈 화면 (지도 화면)
                            HomeTabView(viewModel: viewModel, locationService: locationService)
                                .environmentObject(viewModel)
                                .environmentObject(locationService)
                                .environment(\.checkBeforeStartRunning, checkBeforeStartRunning)
                        } else if viewModel.selectedTab == 1 {
                            // 탐색 화면
                            ExploreTabView(viewModel: viewModel)
                        } else if viewModel.selectedTab == 2 {
                            // 활동 화면
                            ActivityTabView(viewModel: viewModel)
                        } else if viewModel.selectedTab == 3 {
                            // 프로필 화면
                            ProfileTabView(viewModel: viewModel, colorScheme: colorScheme)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                
                // 하단 탭 바 - 최상단에 고정
                VStack {
                    Spacer()
                    FloatingTabBar(selectedTab: $viewModel.selectedTab)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 8)
                }
                .zIndex(3) // 최상단에 표시
                
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
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.all) // 모든 안전 영역 무시
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
        .onAppear {
            setupLocationServiceAndViewModel()
        }
    }
    
    // MARK: - 헤더바 선택
    func headerBar(for tab: Int) -> some View {
        switch tab {
        case 0:
            return AnyView(
                HomeHeader(locationService: locationService)
            )
        case 1:
            return AnyView(
                ExploreHeader()
            )
        case 2:
            return AnyView(
                ActivityHeader()
            )
        case 3:
            return AnyView(
                ProfileHeader(viewModel: viewModel)
            )
        default:
            return AnyView(EmptyView())
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
}

// MARK: - 플로팅 탭 바
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs = [
        (icon: "house.fill", title: "홈"),
        (icon: "map.fill", title: "탐색"),
        (icon: "chart.bar.fill", title: "활동"),
        (icon: "person.fill", title: "프로필")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 18))
                        
                        Text(tabs[index].title)
                            .rtCaption()
                    }
                    .foregroundColor(selectedTab == index ? .rtPrimary : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == index ?
                            Color.rtPrimary.opacity(0.1) :
                            Color.clear
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.rtCard)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, getSafeAreaBottom())
    }
}

// 안전 영역 하단 높이 가져오기
func getSafeAreaBottom() -> CGFloat {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
        return 8 // 기본값
    }
    return window.safeAreaInsets.bottom > 0 ? window.safeAreaInsets.bottom : 8
}

// MARK: - 환경 키 정의 (기존 코드와 동일)
struct CheckBeforeStartRunningKey: EnvironmentKey {
    static let defaultValue: ((@escaping (Bool) -> Void) -> Void) = { _ in }
}

extension EnvironmentValues {
    var checkBeforeStartRunning: (@escaping (Bool) -> Void) -> Void {
        get { self[CheckBeforeStartRunningKey.self] }
        set { self[CheckBeforeStartRunningKey.self] = newValue }
    }
}
