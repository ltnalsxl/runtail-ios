//
//  HomeTabView.swift
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

struct EnhancedMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var showsUserLocation: Bool
    var recordedCoordinates: [Coordinate]
    var previewCourse: Course?
    var nearbyCourses: [Course]
    var isPaused: Bool

    // ✅ UIView 생성
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.setRegion(region, animated: true)
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }

    // ✅ UIView 업데이트
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
        
        // 기존 오버레이 제거
        uiView.removeOverlays(uiView.overlays)
        
        // 기존 어노테이션 제거 (사용자 위치 제외)
        let annotations = uiView.annotations.filter { !($0 is MKUserLocation) }
        uiView.removeAnnotations(annotations)
        
        // 현재 기록 중인 러닝 코스 표시
        if !recordedCoordinates.isEmpty {
            let coordinates = recordedCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "recording"
            uiView.addOverlay(polyline)
        }
        
        // 미리보기 코스 표시
        if let course = previewCourse {
            let coordinates = course.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }
            
            // 시작점과 종료점 표시
            if let first = coordinates.first {
                let startPin = CourseAnnotation(
                    coordinate: first,
                    title: "시작",
                    type: .start
                )
                uiView.addAnnotation(startPin)
            }
            
            if let last = coordinates.last, coordinates.count > 1 {
                let endPin = CourseAnnotation(
                    coordinate: last,
                    title: "종료",
                    type: .end
                )
                uiView.addAnnotation(endPin)
            }
            
            // 코스 경로 표시
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "preview"
            uiView.addOverlay(polyline)
        }
        
        // 주변 코스 표시
        for course in nearbyCourses {
            let coordinates = course.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }
            
            // 시작점 표시
            if let first = coordinates.first {
                let pin = CourseAnnotation(
                    coordinate: first,
                    title: course.title,
                    type: .nearby
                )
                uiView.addAnnotation(pin)
            }
            
            // 코스 경로 표시
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "nearby"
            uiView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 강화된 코스 어노테이션
    class CourseAnnotation: NSObject, MKAnnotation {
        enum AnnotationType {
            case start, end, nearby
        }
        
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let type: AnnotationType
        
        init(coordinate: CLLocationCoordinate2D, title: String, type: AnnotationType) {
            self.coordinate = coordinate
            self.title = title
            self.type = type
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: EnhancedMapView
        
        init(_ parent: EnhancedMapView) {
            self.parent = parent
        }
        
        // 커스텀 어노테이션 뷰
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            if let courseAnnotation = annotation as? CourseAnnotation {
                let identifier = "CourseAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                }
                
                annotationView?.annotation = annotation
                
                // 어노테이션 타입에 따른 스타일 변경
                switch courseAnnotation.type {
                case .start:
                    annotationView?.markerTintColor = UIColor(Color.rtSuccess)
                    annotationView?.glyphImage = UIImage(systemName: "flag.fill")
                case .end:
                    annotationView?.markerTintColor = UIColor(Color.rtError)
                    annotationView?.glyphImage = UIImage(systemName: "flag.checkered")
                case .nearby:
                    annotationView?.markerTintColor = UIColor(Color.rtPrimary)
                    annotationView?.glyphImage = UIImage(systemName: "mappin")
                }
                
                return annotationView
            }
            
            return nil
        }
        
        // 커스텀 오버레이 렌더러
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                switch polyline.title ?? "" {
                case "recording":
                    // 현재 기록 중인 러닝
                    renderer.strokeColor = parent.isPaused ?
                        UIColor(Color.rtWarning) :
                        UIColor(Color.rtPrimary)
                    renderer.lineWidth = 5
                case "preview":
                    // 미리보기 코스
                    renderer.strokeColor = UIColor(Color.rtSecondary.opacity(0.8))
                    renderer.lineWidth = 5
                case "nearby":
                    // 주변 코스
                    renderer.strokeColor = UIColor(Color.rtPrimary.opacity(0.6))
                    renderer.lineWidth = 3
                default:
                    renderer.strokeColor = UIColor(Color.rtPrimary)
                    renderer.lineWidth = 4
                }
                
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}


struct HomeTabView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var locationService: LocationService
    @Environment(\.checkBeforeStartRunning) var checkBeforeStartRunning
    @State private var showCourseNameDialog = false
    @State private var courseName = ""
    @State private var isCoursePublic = false
    @State private var selectedCourse: Course?
    @State private var showRoutePreview = false
    
    // 통계 아이템 컴포넌트 수정
    struct StatItem: View {
        var title: String
        var value: String
        var icon: String
        
        var body: some View {
            VStack(spacing: 0) { // 간격을 0으로 설정
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.rtPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .rtCaption()
                        .foregroundColor(.gray)
                    
                    Text(value)
                        .rtBodyLarge()
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 지도 영역 - 상단 절반
            mapSection
            
            // 통계 바
            statisticsBar
            
            // 스크롤 가능한 컨텐츠 영역
            ScrollView {
                VStack(spacing: 24) {
                    // 최근 활동 섹션
                    recentRunsSection
                    
                    // 탐색 섹션
                    categoriesSection
                }
                .padding(.bottom, 100) // 하단 탭바 공간 확보
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
            
            Button("취소", role: .cancel) {}
        } message: {
            Text("방금 완료한 러닝을 코스로 저장합니다.")
        }
        .sheet(isPresented: $showRoutePreview) {
            if let course = selectedCourse {
                RoutePreviewView(course: course, viewModel: viewModel, locationService: locationService)
            }
        }
        .background(Color.rtBackground)
    }
    
    // MARK: - 지도 섹션
    var mapSection: some View {
        ZStack(alignment: .bottom) {
            // 지도 영역
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map(position: .constant(.automatic), content: {
                    // 사용자 현재 위치
                    UserAnnotation()
                    
                    // 현재 기록 중인 코스 표시
                    if viewModel.isRecording && !viewModel.recordedCoordinates.isEmpty {
                        MapPolyline(coordinates: viewModel.recordedCoordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(
                            viewModel.isPaused ? Color.rtWarning : Color.rtPrimary,
                            lineWidth: 4
                        )
                    }
                    
                    // 현재 선택된 근처 코스 표시 (예: 선택한 코스 미리보기)
                    if let selectedCourse = selectedCourse, showRoutePreview, !viewModel.isRecording {
                        // 시작점 표시
                        if let firstCoord = selectedCourse.coordinates.first {
                            Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.rtSuccess)
                            }
                        }
                        
                        // 종료점 표시
                        if let lastCoord = selectedCourse.coordinates.last {
                            Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 24))
                                    .foregroundColor(.rtError)
                            }
                        }
                        
                        // 코스 경로 표시 (점선)
                        MapPolyline(coordinates: selectedCourse.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(
                            Color.rtSecondary.opacity(0.8),
                            lineWidth: 5
                        )
                    }
                    
                    // 주변 코스 표시 (상위 3개)
                    if !viewModel.isRecording, !showRoutePreview, let userLocation = locationService.lastLocation?.coordinate {
                        let nearbyCourses = viewModel.findNearbyCoursesFor(coordinate: userLocation, radius: 5000) // 5km 이내
                        
                        ForEach(Array(nearbyCourses.prefix(3)), id: \.id) { course in
                            if let firstCoord = course.coordinates.first {
                                Marker(course.title, coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng))
                                    .tint(Color.rtPrimary)
                            }
                            
                            MapPolyline(coordinates: course.coordinates.map {
                                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                            })
                            .stroke(
                                Color.rtPrimary.opacity(0.6),
                                lineWidth: 3
                            )
                        }
                    }
                })
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                .mapControls {
                    // 지도 컨트롤 추가
                    MapCompass()
                    MapScaleView()
                }
                .frame(height: UIScreen.main.bounds.height * 0.4)
                .edgesIgnoringSafeArea(.horizontal) // 수평 가장자리 무시

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
                    isPaused: viewModel.isPaused
                )
                .frame(height: UIScreen.main.bounds.height * 0.4)
                .edgesIgnoringSafeArea(.horizontal) // 수평 가장자리 무시

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
                isPaused: viewModel.isPaused
            )
            .frame(height: UIScreen.main.bounds.height * 0.4)
            .edgesIgnoringSafeArea(.horizontal) // 수평 가장자리 무시

            #endif
            
            // 지도 컨트롤
            mapControls
            
            // 검색 바 - 달리기 중이 아닐 때만 표시
            if !viewModel.isRecording {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(maxWidth: CGFloat.infinity, alignment: .top)
            }
            
            // 달리기 시작/종료 버튼
            startRunningButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }
    
    // MARK: - 통계 바 섹션
    var statisticsBar: some View {
        HStack(spacing: 0) {
            // 총 거리
            StatItem(
                title: "총 거리",
                value: Formatters.formatDistance(viewModel.totalDistance),
                icon: "figure.walk"
            )
            
            // 구분선
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 30)
            
            // 주간 거리
            StatItem(
                title: "이번 주",
                value: Formatters.formatDistance(viewModel.weeklyDistance),
                icon: "calendar"
            )
            
            // 구분선
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 30)
            
            // 오늘 거리
            StatItem(
                title: "오늘",
                value: Formatters.formatDistance(viewModel.todayDistance),
                icon: "clock"
            )
        }
        .padding(.vertical, 12)
        .background(Color.rtCard)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - 최근 런 섹션
    var recentRunsSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Text("최근 활동")
                    .rtHeading3()
                
                Spacer()
                
                Button(action: {
                    // 모든 활동 보기
                    withAnimation {
                        viewModel.selectedTab = 2 // 활동 탭으로 이동
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("더보기")
                            .rtBodySmall()
                            .foregroundColor(.rtPrimary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.rtPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // 최근 러닝 목록
            if viewModel.recentRuns.isEmpty {
                // 데이터가 없는 경우
                EmptyStateView(
                    icon: "figure.run",
                    title: "아직 러닝 기록이 없습니다",
                    message: "첫 러닝을 시작해보세요!"
                )
                .padding(20)
            } else {
                // 데이터가 있는 경우 최근 러닝 표시
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.recentRuns) { run in
                            RecentRunCard(run: run) {
                                // 코스 ID가 있는 경우 상세 화면으로 이동
                                if !run.courseId.isEmpty, let course = viewModel.getCourse(by: run.courseId) {
                                    viewModel.selectedCourseId = run.courseId
                                    viewModel.showCourseDetailView = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    // MARK: - 검색 바
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)
            
            Text("장소 또는 코스 검색")
                .rtBodySmall()
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.rtCard)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - 지도 컨트롤
    var mapControls: some View {
        VStack(spacing: 10) {
            MapControlButton(icon: "plus", action: { locationService.zoomIn() })
            MapControlButton(icon: "minus", action: { locationService.zoomOut() })
            MapControlButton(icon: "location.fill", action: { locationService.centerOnUserLocation() })
            
            if showRoutePreview {
                MapControlButton(icon: "xmark", action: {
                    showRoutePreview = false
                    selectedCourse = nil
                })
                .foregroundColor(.rtError)
            }
        }
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity, alignment: .topTrailing)
        .padding(16)
    }
    
    // 지도 컨트롤 버튼
    struct MapControlButton: View {
        var icon: String
        var action: () -> Void
        var foregroundColor: Color = .rtPrimary
        
        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(foregroundColor)
                    .frame(width: 36, height: 36)
                    .background(Color.rtCard)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
        }
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
                            viewModel.startRecording()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text("\(course.title) 따라 달리기")
                            .rtBodyLarge()
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: CGFloat.infinity)
                    .background(LinearGradient.rtPrimaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(24)
                    .shadow(color: Color.rtPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            else if viewModel.isRecording {
                // 달리기 중일 때 표시되는 뷰
                VStack(spacing: 0) {
                    // 러닝 세션 카드
                    RunningSessionCard(
                        elapsedTime: viewModel.recordingElapsedTime,
                        distance: viewModel.recordingDistance,
                        pace: calculateCurrentPace(),
                        isPaused: viewModel.isPaused,
                        onPause: { viewModel.pauseRecording() },
                        onResume: { viewModel.resumeRecording() },
                        onStop: {
                            // 달리기 종료
                            viewModel.stopRecording { success, courseId in
                                if success {
                                    // 성공 시 코스 리스트 갱신 (저장 대화창에서 저장 버튼 누르면 수행)
                                }
                            }
                        }
                    )
                }
            } else {
                // 기존 코드 (달리기 시작 버튼)
                VStack(spacing: 0) {
                    // 메인 시작 버튼
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.isStartRunExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                            Text("달리기 시작하기")
                                .rtBodyLarge()
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: viewModel.isStartRunExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(LinearGradient.rtPrimaryGradient)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .shadow(color: Color.rtPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    // 확장 메뉴
                    if viewModel.isStartRunExpanded {
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
                                StartRunOption(
                                    icon: "play.fill",
                                    title: "자유 달리기",
                                    subtitle: "달리면서 새 코스 만들기",
                                    color: .rtPrimary
                                )
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
                                StartRunOption(
                                    icon: "map.fill",
                                    title: "코스 따라 달리기",
                                    subtitle: "기존 코스 선택하기",
                                    color: .rtSecondary
                                )
                            }
                        }
                        .background(Color.rtCard)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
        }
    }
    
    // 러닝 시작 옵션 컴포넌트
    struct StartRunOption: View {
        var icon: String
        var title: String
        var subtitle: String
        var color: Color
        
        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .rtBodyLarge()
                    
                    Text(subtitle)
                        .rtBodySmall()
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 러닝 세션 카드
    struct RunningSessionCard: View {
        var elapsedTime: TimeInterval
        var distance: Double
        var pace: Double
        var isPaused: Bool
        var onPause: () -> Void
        var onResume: () -> Void
        var onStop: () -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                // 통계 정보 영역
                HStack(spacing: 0) {
                    // 시간
                    StatisticItem(
                        title: "시간",
                        value: formatTime(elapsedTime),
                        foregroundColor: .white
                    )
                    
                    // 구분선
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 40)
                    
                    // 거리
                    StatisticItem(
                        title: "거리",
                        value: formatDistance(distance),
                        foregroundColor: .white
                    )
                    
                    // 구분선
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 40)
                    
                    // 페이스
                    StatisticItem(
                        title: "페이스",
                        value: formatPace(pace),
                        foregroundColor: .white
                    )
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    isPaused ?
                        LinearGradient.rtWarningGradient :
                        LinearGradient.rtPrimaryGradient
                )
                .cornerRadius(20, corners: [.topLeft, .topRight])
                
                // 버튼 영역
                HStack(spacing: 16) {
                    // 일시정지/재개 버튼
                    Button(action: {
                        if isPaused {
                            onResume()
                        } else {
                            onPause()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 16))
                            
                            Text(isPaused ? "계속하기" : "일시정지")
                                .rtBodySmall()
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: CGFloat.infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.15))
                        )
                        .foregroundColor(.white)
                    }
                    
                    // 종료 버튼
                    Button(action: onStop) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16))
                            
                            Text("종료")
                                .rtBodySmall()
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: CGFloat.infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.rtError.opacity(0.9))
                        )
                        .foregroundColor(.white)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.2))
                .cornerRadius(20, corners: [.bottomLeft, .bottomRight])
            }
            .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
        }
        
        private struct StatisticItem: View {
            var title: String
            var value: String
            var foregroundColor: Color
            
            var body: some View {
                VStack(spacing: 4) {
                    Text(title)
                        .rtCaption()
                        .foregroundColor(foregroundColor.opacity(0.8))
                    
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(foregroundColor)
                }
                .frame(maxWidth: CGFloat.infinity)
            }
        }
        
        // 포맷팅 함수들
        private func formatTime(_ seconds: TimeInterval) -> String {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            let secs = Int(seconds) % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, secs)
            } else {
                return String(format: "%02d:%02d", minutes, secs)
            }
        }
        
        private func formatDistance(_ meters: Double) -> String {
            if meters < 1000 {
                return String(format: "%.0fm", meters)
            } else {
                return String(format: "%.2fkm", meters/1000)
            }
        }
        
        private func formatPace(_ pace: Double) -> String {
            if pace.isNaN || pace.isInfinite || pace <= 0 {
                return "--'--\""
            }
            
            let minutes = Int(pace) / 60
            let seconds = Int(pace) % 60
            return String(format: "%d'%02d\"", minutes, seconds)
        }
    }
    
    // 최근 러닝 카드 컴포넌트
    struct RecentRunCard: View {
        var run: Run
        var onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // 좌측 아이콘
                    ZStack {
                        Circle()
                            .fill(Color.rtPrimary.opacity(0.1))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 22))
                            .foregroundColor(.rtPrimary)
                    }
                    
                    // 정보 영역
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getDayAndDate(run.runAt))
                            .rtBodyLarge()
                            .fontWeight(.medium)
                        
                        // 통계 라인
                        HStack(spacing: 14) {
                            // 거리
                            Label(
                                Formatters.formatDistance(run.trail.count > 0 ? 150 * Double(run.trail.count) : 0),
                                systemImage: "ruler"
                            )
                            .labelStyle(IconFirstLabelStyle())
                            .rtBodySmall()
                            .foregroundColor(.gray)
                            
                            // 시간
                            Label(
                                Formatters.formatDuration(run.duration),
                                systemImage: "clock"
                            )
                            .labelStyle(IconFirstLabelStyle())
                            .rtBodySmall()
                            .foregroundColor(.gray)
                            
                            // 페이스
                            Label(
                                run.paceStr,
                                systemImage: "speedometer"
                            )
                            .labelStyle(IconFirstLabelStyle())
                            .rtBodySmall()
                            .foregroundColor(.rtPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    // 화살표
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.rtCard)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                .frame(width: 280)
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        // 날짜 포맷팅
        private func getDayAndDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "M월 d일 (E)"
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter.string(from: date)
        }
    }
    
    // MARK: - 카테고리 섹션
    var categoriesSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Text("살펴보기")
                    .rtHeading3()
                
                Spacer()
                
                Button(action: {
                    // 더 많은 카테고리 보기
                    withAnimation {
                        viewModel.selectedTab = 1 // 탐색 탭으로 이동
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("더보기")
                            .rtBodySmall()
                            .foregroundColor(.rtPrimary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.rtPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // 카테고리 목록
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.exploreCategories) { category in
                        CategoryCard(category: category) {
                            // 카테고리 탭
                            withAnimation {
                                viewModel.selectedTab = 1 // 탐색 탭으로 이동
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
    
    // 카테고리 카드 컴포넌트
    struct CategoryCard: View {
        var category: ExploreCategory
        var onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // 아이콘
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 18))
                            .foregroundColor(category.color)
                    }
                    
                    // 텍스트
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .rtBodyLarge()
                            .fontWeight(.medium)
                        
                        Text("새로운 경로 살펴보기")
                            .rtBodySmall()
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // 화살표
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.rtCard)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                .frame(width: 260)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // 빈 상태 표시 컴포넌트
    struct EmptyStateView: View {
        var icon: String
        var title: String
        var message: String
        
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text(title)
                    .rtBodyLarge()
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Text(message)
                    .rtBodySmall()
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color.rtCard)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 유틸리티 함수
    
    // 현재 페이스 계산
    private func calculateCurrentPace() -> Double {
        if viewModel.recordingDistance < 100 {  // 최소 100m 이상 달려야 페이스 계산
            return 0
        }
        
        // 페이스 = 시간(초) / 거리(km)
        let distanceInKm = viewModel.recordingDistance / 1000
        return viewModel.recordingElapsedTime / distanceInKm
    }
    
    // 라벨 스타일
    struct IconFirstLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 4) {
                configuration.icon
                    .font(.system(size: 10))
                configuration.title
            }
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
            ZStack {
                LinearGradient.rtPrimaryGradient
                    .ignoresSafeArea()
                
                HStack {
                    // 닫기 버튼
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("코스 미리보기")
                        .rtBodyLarge()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 상세 정보 버튼
                    Button(action: {
                        // 코스 세부 정보로 이동
                        viewModel.selectedCourseId = course.id
                        viewModel.showCourseDetailView = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
            
            // 코스 제목 및 정보
            VStack(spacing: 8) {
                Text(course.title)
                    .rtHeading3()
                    .foregroundColor(.primary)
                
                // 코스 통계
                HStack(spacing: 24) {
                    // 거리
                    VStack(spacing: 4) {
                        Text("거리")
                            .rtCaption()
                            .foregroundColor(.gray)
                        
                        Text(Formatters.formatDistance(course.distance))
                            .rtBodyLarge()
                            .fontWeight(.medium)
                    }
                    
                    // 예상 시간
                    VStack(spacing: 4) {
                        Text("예상 시간")
                            .rtCaption()
                            .foregroundColor(.gray)
                        
                        let userAveragePace = viewModel.getUserAveragePace()
                        let estimatedTime = course.distance > 0 ? Int(course.distance / 1000 * userAveragePace) : 0
                        
                        Text(Formatters.formatDuration(estimatedTime))
                            .rtBodyLarge()
                            .fontWeight(.medium)
                    }
                    
                    // 생성일
                    VStack(spacing: 4) {
                        Text("생성일")
                            .rtCaption()
                            .foregroundColor(.gray)
                        
                        Text(Formatters.formatDate(course.createdAt))
                            .rtBodyLarge()
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
            .background(Color.rtCard)
            
            // 코스 지도
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map(position: .constant(.automatic), content: {
                    // 사용자 현재 위치
                    UserAnnotation()
                    
                    // 시작점 표시
                    if let firstCoord = course.coordinates.first {
                        Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.rtSuccess)
                                .padding(8)
                                .background(Circle().fill(Color.white))
                                .shadow(radius: 2)
                        }
                    }
                    
                    // 종료점 표시
                    if let lastCoord = course.coordinates.last {
                        Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 20))
                                .foregroundColor(.rtError)
                                .padding(8)
                                .background(Circle().fill(Color.white))
                                .shadow(radius: 2)
                        }
                    }
                    
                    // 경로 표시
                    MapPolyline(coordinates: course.coordinates.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                    })
                    .stroke(
                        Color.rtSecondary.opacity(0.8),
                        lineWidth: 5
                    )
                })
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                .frame(maxHeight: CGFloat.infinity)
            } else {
                EnhancedMapView(
                    region: $region,
                    showsUserLocation: true,
                    recordedCoordinates: [],
                    previewCourse: course,
                    nearbyCourses: [],
                    isPaused: false
                )
                .frame(maxHeight: CGFloat.infinity)
            }
            #else
            EnhancedMapView(
                region: $region,
                showsUserLocation: true,
                recordedCoordinates: [],
                previewCourse: course,
                nearbyCourses: [],
                isPaused: false
            )
            .frame(maxHeight: CGFloat.infinity)
            #endif
            
            // 하단 버튼
            Button(action: {
                // 앱 메인 화면으로 돌아가서 이 코스로 달리기 시작
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.system(size: 18))
                    Text("이 코스로 달리기")
                        .rtBodyLarge()
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: CGFloat.infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.rtPrimaryGradient)
                .foregroundColor(.white)
                .cornerRadius(24)
                .shadow(color: Color.rtPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(16)
            }
            .background(Color.rtCard)
        }
    }
}
