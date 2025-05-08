//
//  HomeTabView.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//  Updated with running recording functionality
//

import SwiftUI
import MapKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

struct HomeTabView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var locationService: LocationService
    @State private var showCourseNameDialog = false
    @State private var courseName = ""
    @State private var isCoursePublic = false
    
    var body: some View {
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
        .alert("코스 저장", isPresented: $viewModel.showSaveAlert) {
            TextField("코스 이름", text: $viewModel.tempCourseName)
            
            Toggle("공개 코스로 설정", isOn: $isCoursePublic)
            
            Button("저장", action: {
                viewModel.saveRecordingAsCourse(
                    title: viewModel.tempCourseName,
                    isPublic: isCoursePublic
                ) { success, _ in
                    if success {
                        // 저장 성공 시 코스 목록 갱신
                        viewModel.loadMyCourses()
                        viewModel.loadRecentRuns()
                    }
                }
            })
            
            Button("취소", role: .cancel) {
                // 취소 처리 - 추가 작업 없음
            }
        } message: {
            Text("방금 완료한 러닝을 코스로 저장합니다.")
        }
        .sheet(isPresented: $viewModel.showCourseDetailView) {
            if let courseId = viewModel.selectedCourseId,
               let course = viewModel.getCourse(by: courseId) {
                CourseDetailView(course: course)
            }
        }
    }
    
    // MARK: - 상단 상태 바
    var statusBar: some View {
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
        .padding(.vertical, 12)
        .background(viewModel.themeGradient)
        .foregroundColor(.white)
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
    
    // MARK: - 지도 섹션
    var mapSection: some View {
        ZStack(alignment: .bottom) {
            // 지도 (iOS 17에서 변경된 방식)
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map(initialPosition: MapCameraPosition.region(locationService.region)) {
                    UserAnnotation()
                    
                    // 현재 기록 중인 코스 표시
                    if viewModel.isRecording && !viewModel.recordedCoordinates.isEmpty {
                        MapPolyline(coordinates: viewModel.recordedCoordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(viewModel.themeColor, lineWidth: 4)
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            } else {
                MapWithOverlay(
                    region: $locationService.region,
                    showsUserLocation: true,
                    recordedCoordinates: viewModel.isRecording ? viewModel.recordedCoordinates : []
                )
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            #else
            MapWithOverlay(
                region: $locationService.region,
                showsUserLocation: true,
                recordedCoordinates: viewModel.isRecording ? viewModel.recordedCoordinates : []
            )
            .frame(height: UIScreen.main.bounds.height * 0.5)
            #endif
            
            // 검색 바 - 달리기 중이 아닐 때만 표시
            if !viewModel.isRecording {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            
            // 지도 컨트롤
            mapControls
            
            // 달리기 시작/종료 버튼
            startRunningButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }
    
    // MARK: - 검색 바
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
    
    // MARK: - 지도 컨트롤
    var mapControls: some View {
        VStack(spacing: 8) {
            // 확대 버튼
            Button(action: {
                locationService.zoomIn()
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
            
            // 축소 버튼
            Button(action: {
                locationService.zoomOut()
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
            
            // 내 위치로 이동 버튼
            Button(action: {
                locationService.centerOnUserLocation()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.themeColor)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    // MARK: - 달리기 시작/종료 버튼
    var startRunningButton: some View {
        VStack(spacing: 8) {
            if viewModel.isRecording {
                // 달리기 중일 때 표시되는 뷰
                VStack(spacing: 0) {
                    HStack {
                        // 러닝 타이머
                        VStack(alignment: .leading, spacing: 4) {
                            Text("달리는 중...")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(formatDuration(viewModel.recordingElapsedTime))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // 거리
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("거리")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(Formatters.formatDistance(viewModel.recordingDistance))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // 일시정지/재개 버튼
                        Button(action: {
                            if viewModel.isPaused {
                                viewModel.resumeRecording()
                            } else {
                                viewModel.pauseRecording()
                            }
                        }) {
                            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(viewModel.darkGradient)
                    .cornerRadius(28)
                    .shadow(color: viewModel.themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // 종료 버튼
                    Button(action: {
                        // 달리기 종료
                        viewModel.stopRecording { success, courseId in
                            if success {
                                // 성공 시 코스 리스트 갱신 (저장 대화창에서 저장 버튼 누르면 수행)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16))
                            Text("달리기 종료")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(28)
                        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 12)
                }
            } else {
                // 기존 코드 (달리기 시작 버튼)
                Button(action: {
                    withAnimation(.spring()) {
                        viewModel.isStartRunExpanded.toggle()
                    }
                }) {
                    // 기존 UI 유지
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text("달리기 시작하기")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: viewModel.isStartRunExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(viewModel.themeGradient)
                    .foregroundColor(.white)
                    .cornerRadius(28)
                    .shadow(color: viewModel.themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                if viewModel.isStartRunExpanded {
                    // 확장 메뉴에 실제 기능 추가
                    VStack(spacing: 0) {
                        // 자유 달리기 옵션
                        Button(action: {
                            // GPS 신호 강도 확인
                            if locationService.gpsSignalStrength < 2 {
                                // GPS 신호가 약한 경우 경고
                                // (실제 구현에서는 경고 알림 추가)
                                print("GPS 신호가 약합니다. 좀 더 기다려주세요.")
                                return
                            }
                            
                            // 자유 달리기 시작 로직 구현
                            withAnimation(.spring()) {
                                viewModel.isStartRunExpanded = false
                                
                                // 위치 서비스 정확도 높이기
                                locationService.startHighAccuracyLocationUpdates()
                                locationService.onLocationUpdate = { coordinate in
                                    viewModel.addLocationToRecording(coordinate: coordinate)
                                }
                                
                                // 러닝 기록 시작
                                viewModel.startRecording()
                            }
                        }) {
                            // 자유 달리기 UI
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(viewModel.themeColor.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "play.fill")
                                        .foregroundColor(viewModel.themeColor)
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
                                viewModel.isStartRunExpanded = false
                                // 코스 선택 화면으로 이동하는 로직 구현
                                // (별도의 화면 필요)
                            }
                        }) {
                            // 코스 따라 달리기 UI
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(viewModel.exploreCategories[2].color.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "map.fill")
                                        .foregroundColor(viewModel.exploreCategories[2].color)
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
    }
    
    // MARK: - 통계 바
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
                    Text(Formatters.formatDistance(viewModel.totalDistance))
                        .font(.system(size: 16, weight: .bold))
                    
                    // 미니 그래프
                    RoundedRectangle(cornerRadius: 2)
                        .fill(viewModel.themeColor)
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
                    Text(Formatters.formatDistance(viewModel.weeklyDistance))
                        .font(.system(size: 16, weight: .bold))
                    
                    // 미니 그래프 (주간 데이터 비율 반영)
                    let ratio = min(max(viewModel.weeklyDistance / (viewModel.totalDistance > 0 ? viewModel.totalDistance : 1), 0.1), 1.0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(viewModel.exploreCategories[1].color)
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
                    Text(Formatters.formatDistance(viewModel.todayDistance))
                        .font(.system(size: 16, weight: .bold))
                    
                    // 미니 그래프 (일간 데이터 비율 반영)
                    let ratio = min(max(viewModel.todayDistance / (viewModel.weeklyDistance > 0 ? viewModel.weeklyDistance : 1), 0.1), 1.0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(viewModel.exploreCategories[2].color)
                        .frame(width: 60 * ratio, height: 4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 최근 활동 섹션
    var recentActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("최근 활동")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    // 모두 보기 기능 구현
                    viewModel.selectedTab = 2 // 활동 탭으로 이동
                }) {
                    Text("모두 보기")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.themeColor)
                }
            }
            
            if viewModel.recentRuns.isEmpty {
                // 빈 상태 UI
                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.themeColor.opacity(0.6))
                    
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
                ForEach(viewModel.recentRuns) { run in
                    runCard(run)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - 달리기 기록 카드
    func runCard(_ run: Run) -> some View {
        VStack {
            HStack(spacing: 16) {
                // 런닝 아이콘
                ZStack {
                    Circle()
                        .fill(viewModel.themeColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "figure.run")
                        .foregroundColor(viewModel.themeColor)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.getCourseTitle(courseId: run.courseId))
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("\(Formatters.formatDistance(run.trail.isEmpty ? 0 : run.calculateDistance())) · \(Formatters.formatDuration(run.duration))")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Formatters.formatDate(run.runAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .foregroundColor(viewModel.themeColor)
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
    
    // MARK: - 탐색 섹션
    var exploreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("탐색")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    // 더보기 기능 구현
                    viewModel.selectedTab = 1 // 탐색 탭으로 이동
                }) {
                    Text("더보기")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.themeColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.exploreCategories) { category in
                        exploreCategoryCard(category)
                    }
                }
                .padding(.bottom, 8) // 그림자가 잘리지 않도록
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 탐색 카테고리 카드
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
    
    // MARK: - 유틸리티 함수
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

// MARK: - 지도 오버레이 뷰 (iOS 16 이하용)
struct MapWithOverlay: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var showsUserLocation: Bool
    var recordedCoordinates: [Coordinate]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.setRegion(region, animated: true)
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
        
        // 기존 오버레이 제거
        uiView.removeOverlays(uiView.overlays)
        
        // 새 오버레이 추가 (기록된 좌표가 있는 경우)
        if !recordedCoordinates.isEmpty {
            let coordinates = recordedCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            uiView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapWithOverlay
        
        init(_ parent: MapWithOverlay) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color(red: 89/255, green: 86/255, blue: 214/255))
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Run 모델 확장 (거리 계산 기능)
extension Run {
    func calculateDistance() -> Double {
        guard trail.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        
        for i in 0..<(trail.count - 1) {
            let start = CLLocation(latitude: trail[i].latitude, longitude: trail[i].longitude)
            let end = CLLocation(latitude: trail[i + 1].latitude, longitude: trail[i + 1].longitude)
            
            totalDistance += start.distance(from: end)
        }
        
        return totalDistance
    }
}

// MARK: - 코스 상세 보기 화면
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
                } else {
                    CourseMapView(region: $region, coordinates: course.coordinates)
                        .frame(height: 300)
                }
                #else
                CourseMapView(region: $region, coordinates: course.coordinates)
                    .frame(height: 300)

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
        .edgesIgnoringSafeArea(.top)
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
