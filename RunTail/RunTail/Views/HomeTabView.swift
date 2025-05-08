//
//  HomeTabView.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//  Updated with enhanced course visualization
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
    @Environment(\.checkBeforeStartRunning) var checkBeforeStartRunning
    @State private var showCourseNameDialog = false
    @State private var courseName = ""
    @State private var isCoursePublic = false
    @State private var selectedCourse: Course?
    @State private var showRoutePreview = false
    
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
        .sheet(isPresented: $showRoutePreview) {
            if let course = selectedCourse {
                RoutePreviewView(course: course, viewModel: viewModel, locationService: locationService)
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
            // 지도 영역
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map {
                    // 사용자 현재 위치
                    UserAnnotation()
                    
                    // 현재 기록 중인 코스 표시
                    if viewModel.isRecording && !viewModel.recordedCoordinates.isEmpty {
                        MapPolyline(coordinates: viewModel.recordedCoordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(
                            viewModel.isPaused ? Color.orange : viewModel.themeColor,
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    }
                    
                    // 현재 선택된 근처 코스 표시 (예: 선택한 코스 미리보기)
                    if let selectedCourse = selectedCourse, showRoutePreview, !viewModel.isRecording {
                        // 시작점 표시
                        if let firstCoord = selectedCourse.coordinates.first {
                            Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        // 종료점 표시
                        if let lastCoord = selectedCourse.coordinates.last {
                            Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // 경로 표시
                        MapPolyline(coordinates: selectedCourse.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(
                            Color.blue.opacity(0.8),
                            lineWidth: 5,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [8, 4]
                        )
                    }
                    
                    // 주변 코스 표시 (상위 3개)
                    if !viewModel.isRecording, !showRoutePreview, let userLocation = locationService.lastLocation?.coordinate {
                        let nearbyCourses = viewModel.findNearbyCoursesFor(coordinate: userLocation, radius: 5000) // 5km 이내
                        
                        ForEach(Array(nearbyCourses.prefix(3)), id: \.id) { course in
                            if let firstCoord = course.coordinates.first {
                                Marker(course.title, coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng))
                                    .tint(viewModel.themeColor)
                            }
                            
                            MapPolyline(coordinates: course.coordinates.map {
                                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                            })
                            .stroke(
                                viewModel.themeColor.opacity(0.6),
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                .mapControls {
                    // 지도 컨트롤 추가
                    MapCompass()
                    MapScaleView()
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .mapCameraKeyframeAnimator(trigger: viewModel.isRecording) { camera in
                    KeyframeTrack(\MapCamera.centerCoordinate) {
                        // 달리기 시작 시 현재 위치로 이동
                        if let location = locationService.lastLocation?.coordinate {
                            CubicKeyframe(MapCamera.Coordinate(location), duration: 0.8)
                        }
                    }
                    KeyframeTrack(\MapCamera.distance) {
                        // 달리기 시작 시 확대 (800미터 거리에서 보기)
                        CubicKeyframe(800, duration: 0.8)
                    }
                }
                .onChange(of: locationService.lastLocation) { oldValue, newValue in
                    // 달리기 중일 때 현재 위치로 자동 이동
                    if viewModel.isRecording, let location = newValue?.coordinate {
                        withAnimation {
                            let camera = MapCamera(centerCoordinate: location, distance: 800)
                            camera.setMapCamera(camera)
                        }
                    }
                }
            } else {
                // iOS 16 이하용 맵 뷰
                EnhancedMapView(
                    region: $locationService.region,
                    showsUserLocation: true,
                    recordedCoordinates: viewModel.isRecording ? viewModel.recordedCoordinates : [],
                    previewCourse: showRoutePreview ? selectedCourse : nil,
                    nearbyCourses: !viewModel.isRecording && !showRoutePreview
                        ? viewModel.findNearbyCoursesFor(coordinate: locationService.lastLocation?.coordinate ?? CLLocationCoordinate2D(), radius: 5000)
                        : [],
                    isPaused: viewModel.isPaused,
                    themeColor: UIColor(viewModel.themeColor),
                    onCourseSelected: { course in
                        selectedCourse = course
                        showRoutePreview = true
                    }
                )
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            #else
            // iOS 16 이하용 맵 뷰
            EnhancedMapView(
                region: $locationService.region,
                showsUserLocation: true,
                recordedCoordinates: viewModel.isRecording ? viewModel.recordedCoordinates : [],
                previewCourse: showRoutePreview ? selectedCourse : nil,
                nearbyCourses: !viewModel.isRecording && !showRoutePreview
                    ? viewModel.findNearbyCoursesFor(coordinate: locationService.lastLocation?.coordinate ?? CLLocationCoordinate2D(), radius: 5000)
                    : [],
                isPaused: viewModel.isPaused,
                themeColor: UIColor(viewModel.themeColor),
                onCourseSelected: { course in
                    selectedCourse = course
                    showRoutePreview = true
                }
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
            
            // 코스 미리보기 모드일 때 닫기 버튼
            if showRoutePreview {
                Button(action: {
                    showRoutePreview = false
                    selectedCourse = nil
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    // MARK: - 달리기 시작/종료 버튼
    var startRunningButton: some View {
        VStack(spacing: 8) {
            // 코스 미리보기 모드일 때 따라 달리기 버튼
            if showRoutePreview, let course = selectedCourse {
                Button(action: {
                    // 코스 따라 달리기 시작
                    checkBeforeStartRunning { canStart in
                        if canStart {
                            // 위치 서비스 정확도 높이기
                            locationService.startHighAccuracyLocationUpdates()
                            locationService.onLocationUpdate = { coordinate in
                                viewModel.addLocationToRecording(coordinate: coordinate)
                            }
                            
                            // 미리보기 종료
                            showRoutePreview = false
                            
                            // 러닝 기록 시작 (코스 따라 달리기 모드)
                            viewModel.startRecording(followingCourse: course)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text("\(course.title) 따라 달리기")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(viewModel.themeGradient)
                    .foregroundColor(.white)
                    .cornerRadius(28)
                    .shadow(color: viewModel.themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            else if viewModel.isRecording {
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
                    .background(viewModel.isPaused ? Color.orange.opacity(0.8) : viewModel.darkGradient)
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
                            checkBeforeStartRunning { canStart in
                                if canStart {
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
                                }
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
                            // 현재 위치 주변 코스 목록 가져오기
                            if let userLocation = locationService.lastLocation?.coordinate {
                                let nearbyCourses = viewModel.findNearbyCoursesFor(coordinate: userLocation, radius: 5000)
                                
                                withAnimation(.spring()) {
                                    viewModel.isStartRunExpanded = false
                                    
                                    // 주변 코스가 있으면 첫 번째 코스 미리보기
                                    if let firstCourse = nearbyCourses.first {
                                        selectedCourse = firstCourse
                                        showRoutePreview = true
                                    } else {
                                        // 주변 코스가 없을 경우 알림
                                        print("주변에 저장된 코스가 없습니다.")
                                    }
                                }
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
    
    // 생략: 통계 바, 최근 활동 섹션, 달리기 기록 카드, 탐색 섹션, 탐색 카테고리 카드, 유틸리티 함수
    // (이 부분은 앞서 제공된 HomeTabView.swift 코드와 동일)
    
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

// MARK: - 코스 미리보기 뷰
struct RoutePreviewView: View {
    let course: Course
    let viewModel: MapViewModel
    let locationService: LocationService
    @Environment(\.presentationMode) var presentationMode
    @State private var region: MKCoordinateRegion
    
    init(course: Course, viewModel: MapViewModel, locationService: LocationService) {
        self.course = course
        self.viewModel = viewModel
        self.locationService = locationService
        
        // 초기 지역 설정
        if let firstCoord = course.coordinates.first {
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            self._region = State(initialValue: locationService.region)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .padding(8)
                }
                
                Spacer()
                
                Text(course.title)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    // 코스 세부 정보로 이동
                    viewModel.selectedCourseId = course.id
                    viewModel.showCourseDetailView = true
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 코스 정보 요약
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("거리")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(Formatters.formatDistance(course.distance))
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(spacing: 4) {
                    Text("예상 시간")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    // 예상 시간 계산 (평균 6분/km 가정)
                    let estimatedTime = course.distance > 0 ? Int(course.distance / 1000 * 6 * 60) : 0
                    Text(Formatters.formatDuration(estimatedTime))
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(spacing: 4) {
                    Text("생성일")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(Formatters.formatDate(course.createdAt))
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding(.vertical, 12)
            
            // 코스 지도
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map {
                    // 사용자 현재 위치
                    UserAnnotation()
                    
                    // 시작점 표시
                    if let firstCoord = course.coordinates.first {
                        Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        }
                    }
                    
                    // 종료점 표시
                    if let lastCoord = course.coordinates.last {
                        Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                        }
                    }
                    
                    // 경로 표시
                    MapPolyline(coordinates:
