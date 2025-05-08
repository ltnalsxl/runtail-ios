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
                        homeTabView
                    } else if viewModel.selectedTab == 1 {
                        exploreTabView
                    } else if viewModel.selectedTab == 2 {
                        activityTabView
                    } else if viewModel.selectedTab == 3 {
                        profileTabView
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
                                .navigationBarHidden(true)
                        }
                    },
                    isActive: $viewModel.showCourseDetailView,
                    label: { EmptyView() }
                )
            }
            .edgesIgnoringSafeArea(.bottom)
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
            .environmentObject(Environment(\.self)) // 환경 변수 전달
            .environment(\.checkBeforeStartRunning, checkBeforeStartRunning) // 러닝 시작 전 체크 함수 전달
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

// MARK: - 코스 상세 화면
struct CourseDetailView: View {
    let course: Course
    @Environment(\.presentationMode) var presentationMode
    @State private var region = MKCoordinateRegion()
    
    var body: some View {
        VStack(spacing: 0) {
            // 지도 영역
            ZStack(alignment: .top) {
                // 코스 지도
                #if swift(>=5.9) // iOS 17 이상
                if #available(iOS 17.0, *) {
                    Map(initialPosition: MapCameraPosition.region(region)) {
                        MapPolyline(coordinates: course.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(Color(red: 89/255, green: 86/255, blue: 214/255), lineWidth: 4)
                    }
                    .frame(height: 300)
                    .edgesIgnoringSafeArea(.top)
                } else {
                    CourseMapView(region: $region, coordinates: course.coordinates)
                        .frame(height: 300)
                        .edgesIgnoringSafeArea(.top)
                }
                #else
                CourseMapView(region: $region, coordinates: course.coordinates)
                    .frame(height: 300)
                    .edgesIgnoringSafeArea(.top)
                #endif
                
                // 뒤로가기 버튼
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(12)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .foregroundColor(.black)
                    .padding(16)
                    
                    Spacer()
                }
            }
            
            // 코스 정보
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 코스 제목 및 정보
                    VStack(alignment: .leading, spacing: 8) {
                        Text(course.title)
                            .font(.system(size: 24, weight: .bold))
                        
                        HStack(spacing: 20) {
                            Label(Formatters.formatDistance(course.distance), systemImage: "ruler")
                                .foregroundColor(.gray)
                            
                            Label(Formatters.formatDate(course.createdAt), systemImage: "calendar")
                                .foregroundColor(.gray)
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.top, 20)
                    
                    // 통계 카드
                    HStack(spacing: 16) {
                        // 거리 카드
                        statisticCard(
                            title: "총 거리",
                            value: Formatters.formatDistance(course.distance),
                            icon: "ruler",
                            color: Color(red: 89/255, green: 86/255, blue: 214/255)
                        )
                        
                        // 시간 카드 (예상 시간)
                        let estimatedTime = course.distance > 0 ? Int(course.distance / 1000 * 6 * 60) : 0 // 평균 6분/km 가정
                        statisticCard(
                            title: "예상 시간",
                            value: Formatters.formatDuration(estimatedTime),
                            icon: "clock",
                            color: Color(red: 45/255, green: 104/255, blue: 235/255)
                        )
                    }
                    
                    // 액션 버튼
                    Button(action: {
                        // 이 코스로 달리기 시작
                    }) {
                        HStack {
                            Image(systemName: "figure.run")
                            Text("이 코스로 달리기")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 89/255, green: 86/255, blue: 214/255),
                                    Color(red: 45/255, green: 104/255, blue: 235/255)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color(red: 89/255, green: 86/255, blue: 214/255).opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupMapRegion()
        }
    }
    
    // 통계 카드 뷰
    func statisticCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 지도 영역 설정
    private func setupMapRegion() {
        guard !course.coordinates.isEmpty else { return }
        
        // 좌표의 최소/최대값 찾기
        var minLat = course.coordinates[0].lat
        var maxLat = course.coordinates[0].lat
        var minLng = course.coordinates[0].lng
        var maxLng = course.coordinates[0].lng
        
        for coordinate in course.coordinates {
            minLat = min(minLat, coordinate.lat)
            maxLat = max(maxLat, coordinate.lat)
            minLng = min(minLng, coordinate.lng)
            maxLng = max(maxLng, coordinate.lng)
        }
        
        // 중앙점 계산
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        
        // 스팬 계산 (여백 추가)
        let latDelta = (maxLat - minLat) * 1.2
        let lngDelta = (maxLng - minLng) * 1.2
        
        // 지도 영역 설정
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lngDelta, 0.01))
        )
    }
}

// iOS 16 이하에서 코스를 표시하기 위한 지도 뷰
struct CourseMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var coordinates: [Coordinate]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: true)
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
        
        // 기존 오버레이 제거
        uiView.removeOverlays(uiView.overlays)
        
        // 새 오버레이 추가
        if !coordinates.isEmpty {
            let mapCoords = coordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
            let polyline = MKPolyline(coordinates: mapCoords, count: mapCoords.count)
            uiView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CourseMapView
        
        init(_ parent: CourseMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 89/255, green: 86/255, blue: 214/255, alpha: 1)
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
