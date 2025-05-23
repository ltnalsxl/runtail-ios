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

// MARK: - EnhancedMapView (iOS 16 이하용)
struct EnhancedMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var showsUserLocation: Bool
    var recordedCoordinates: [Coordinate]
    var previewCourse: Course?
    var nearbyCourses: [Course]
    var isPaused: Bool

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
    
    // 코스 어노테이션
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

// MARK: - HomeTabView
struct HomeTabView: View {
    // 기존 HomeTabView 코드가 이어집니다...
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var locationService: LocationService
    @Environment(\.checkBeforeStartRunning) var checkBeforeStartRunning
    @State private var showCourseSelection = false
    @State private var selectedCourse: Course?
    @State private var showRoutePreview = false
    
    // 통계 아이템 컴포넌트
    struct StatItem: View {
        var title: String
        var value: String
        var icon: String
        
        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.rtPrimary)
                
                Text(title)
                    .rtCaption()
                    .foregroundColor(.gray)
                
                Text(value)
                    .rtBodyLarge()
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 지도 영역
                mapSection
                    .frame(height: geometry.size.height * 0.55)
                
                // 하단 콘텐츠 영역
                VStack(spacing: 0) {
                    // 통계 바
                    statisticsBar
                    
                    // 스크롤 가능한 콘텐츠
                    ScrollView {
                        VStack(spacing: 24) {
                            // 최근 활동 섹션
                            recentRunsSection
                            
                            // 탐색 섹션
                            categoriesSection
                        }
                        .padding(.bottom, 100)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showCourseSelection) {
            CourseSelectionView(viewModel: viewModel, locationService: locationService)
        }
        .alert("코스 저장", isPresented: $viewModel.showSaveAlert) {
            TextField("코스 이름", text: $viewModel.tempCourseName)
            Toggle("공개 코스로 설정", isOn: .constant(false))
            
            Button("저장", action: {
                viewModel.saveRecordingAsCourse(
                    title: viewModel.tempCourseName,
                    isPublic: false
                ) { success, _ in
                    if success {
                        viewModel.loadMyCourses()
                        viewModel.loadRecentRuns()
                    }
                }
            })
            
            Button("취소", role: .cancel) {}
        } message: {
            Text("방금 완료한 러닝을 코스로 저장합니다.")
        }
        .background(Color.rtBackground)
    }
    
    // MARK: - 지도 섹션
    var mapSection: some View {
        ZStack {
            // 지도 뷰
            if #available(iOS 17.0, *) {
                Map(position: .constant(.region(locationService.region))) {
                    // 사용자 현재 위치
                    UserAnnotation()
                    
                    // 현재 기록 중인 러닝 경로 표시
                    if viewModel.isRecording && !viewModel.recordedCoordinates.isEmpty {
                        MapPolyline(coordinates: viewModel.recordedCoordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(
                            viewModel.isPaused ? Color.rtWarning : Color.rtPrimary,
                            lineWidth: 4
                        )
                    }
                    
                    // 따라 달리기 중인 코스 표시
                    if viewModel.isFollowingCourse, let course = viewModel.currentFollowingCourse {
                        // 전체 코스 경로 (연한 색)
                        MapPolyline(coordinates: course.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(Color.rtSecondary.opacity(0.4), lineWidth: 3)
                        
                        // 완료된 구간 (진한 색)
                        let completedCoords = Array(course.coordinates.prefix(viewModel.currentCoursePoint + 1))
                        if completedCoords.count > 1 {
                            MapPolyline(coordinates: completedCoords.map {
                                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                            })
                            .stroke(Color.rtSuccess, lineWidth: 4)
                        }
                        
                        // 다음 웨이포인트 표시
                        if let nextWaypoint = viewModel.nextWaypoint {
                            Annotation("목표", coordinate: CLLocationCoordinate2D(latitude: nextWaypoint.lat, longitude: nextWaypoint.lng)) {
                                ZStack {
                                    Circle()
                                        .fill(Color.rtPrimary)
                                        .frame(width: 30, height: 30)
                                    
                                    Image(systemName: "target")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                                .shadow(radius: 3)
                            }
                        }
                        
                        // 시작점과 종료점
                        if let firstCoord = course.coordinates.first {
                            Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                                ZStack {
                                    Circle()
                                        .fill(Color.rtSuccess)
                                        .frame(width: 25, height: 25)
                                    
                                    Image(systemName: "flag.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                .shadow(radius: 2)
                            }
                        }
                        
                        if let lastCoord = course.coordinates.last {
                            Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                                ZStack {
                                    Circle()
                                        .fill(Color.rtError)
                                        .frame(width: 25, height: 25)
                                    
                                    Image(systemName: "flag.checkered")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                .shadow(radius: 2)
                            }
                        }
                    }
                    
                    // 주변 코스 표시 (러닝 중이 아닐 때)
                    if !viewModel.isRecording, !viewModel.isFollowingCourse,
                       let userLocation = locationService.lastLocation?.coordinate {
                        let nearbyCourses = viewModel.findNearbyCoursesFor(coordinate: userLocation, radius: 5000)
                        
                        ForEach(Array(nearbyCourses.prefix(3)), id: \.id) { course in
                            if let firstCoord = course.coordinates.first {
                                Marker(course.title, coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng))
                                    .tint(Color.rtPrimary)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
            } else {
                // iOS 16 이하용 맵 뷰
                EnhancedMapView(
                    region: $locationService.region,
                    showsUserLocation: true,
                    recordedCoordinates: viewModel.isRecording ? viewModel.recordedCoordinates : [],
                    previewCourse: viewModel.currentFollowingCourse,
                    nearbyCourses: !viewModel.isRecording && !viewModel.isFollowingCourse
                        ? viewModel.findNearbyCoursesFor(coordinate: locationService.lastLocation?.coordinate ?? CLLocationCoordinate2D(), radius: 5000)
                        : [],
                    isPaused: viewModel.isPaused
                )
            }
            
            // 지도 위 오버레이들
            VStack {
                // 상단 오버레이들
                VStack(spacing: 16) {
                    // 검색 바 (러닝 중이 아닐 때만)
                    if !viewModel.isRecording && !viewModel.isFollowingCourse {
                        searchBar
                            .padding(.horizontal, 16)
                    }
                    
                    // 따라 달리기 상태 표시
                    if viewModel.isFollowingCourse {
                        CourseFollowingStatusView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    Spacer()
                }
                .padding(.top, 16)
                
                // 하단 컨트롤들
                HStack {
                    Spacer()
                    
                    // 지도 컨트롤
                    mapControls
                        .padding(.trailing, 16)
                }
                .padding(.bottom, 16)
                
                // 달리기 시작/종료 버튼
                startRunningButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - 검색 바
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            Text("장소 또는 코스 검색")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - 지도 컨트롤
    var mapControls: some View {
        VStack(spacing: 10) {
            MapControlButton(icon: "plus", action: { locationService.zoomIn() })
            MapControlButton(icon: "minus", action: { locationService.zoomOut() })
            MapControlButton(icon: "location.fill", action: { locationService.centerOnUserLocation() })
            
            // 음성 안내 토글 버튼 추가
            Button(action: {
                viewModel.toggleVoiceGuidance()
            }) {
                Image(systemName: viewModel.isVoiceGuidanceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.isVoiceGuidanceEnabled ? .rtPrimary : .gray)
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
        }
    }
    
    struct MapControlButton: View {
        var icon: String
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.rtPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - 달리기 시작/종료 버튼
    var startRunningButton: some View {
        VStack(spacing: 8) {
            if viewModel.isRecording || viewModel.isFollowingCourse {
                // 달리기 중일 때 표시되는 뷰
                RunningSessionCard(
                    elapsedTime: viewModel.recordingElapsedTime,
                    distance: viewModel.recordingDistance,
                    pace: calculateCurrentPace(),
                    isPaused: viewModel.isPaused,
                    isFollowingCourse: viewModel.isFollowingCourse,
                    courseProgress: viewModel.courseProgress,
                    onPause: { viewModel.pauseRecording() },
                    onResume: { viewModel.resumeRecording() },
                    onStop: {
                        viewModel.stopRecording { success, courseId in
                            if success {
                                // 저장 성공 처리
                            }
                        }
                    }
                )
            } else {
                // 달리기 시작 버튼들
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
                                withAnimation(.spring()) {
                                    viewModel.isStartRunExpanded = false
                                    showCourseSelection = true
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
                        .background(Color.white)
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
    
    // MARK: - 러닝 세션 카드 (수정됨)
    struct RunningSessionCard: View {
        var elapsedTime: TimeInterval
        var distance: Double
        var pace: Double
        var isPaused: Bool
        var isFollowingCourse: Bool
        var courseProgress: Double
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
                    
                    // 페이스 또는 진행률
                    if isFollowingCourse {
                        StatisticItem(
                            title: "진행률",
                            value: "\(Int(courseProgress * 100))%",
                            foregroundColor: .white
                        )
                    } else {
                        StatisticItem(
                            title: "페이스",
                            value: formatPace(pace),
                            foregroundColor: .white
                        )
                    }
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
                        .frame(maxWidth: .infinity)
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
                        .frame(maxWidth: .infinity)
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
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(foregroundColor)
                }
                .frame(maxWidth: .infinity)
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
                .frame(width: 1, height: 40)
            
            // 주간 거리
            StatItem(
                title: "이번 주",
                value: Formatters.formatDistance(viewModel.weeklyDistance),
                icon: "calendar"
            )
            
            // 구분선
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 40)
            
            // 오늘 거리
            StatItem(
                title: "오늘",
                value: Formatters.formatDistance(viewModel.todayDistance),
                icon: "clock"
            )
        }
        .padding(.vertical, 12)
        .background(Color.white)
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
                    withAnimation {
                        viewModel.selectedTab = 2
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
                EmptyStateView(
                    icon: "figure.run",
                    title: "아직 러닝 기록이 없습니다",
                    message: "첫 러닝을 시작해보세요!"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.recentRuns) { run in
                            RecentRunCard(run: run) {
                                if !run.courseId.isEmpty, let course = viewModel.getCourse(by: run.courseId) {
                                    viewModel.selectedCourseId = run.courseId
                                    viewModel.showCourseDetailView = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - 카테고리 섹션
    var categoriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("살펴보기")
                    .rtHeading3()
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        viewModel.selectedTab = 1
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
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.exploreCategories) { category in
                        CategoryCard(category: category) {
                            withAnimation {
                                viewModel.selectedTab = 1
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 헬퍼 컴포넌트들
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
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            .padding(.horizontal, 16)
        }
    }
    
    struct RecentRunCard: View {
        var run: Run
        var onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.rtPrimary.opacity(0.1))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 22))
                            .foregroundColor(.rtPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getDayAndDate(run.runAt))
                            .rtBodyLarge()
                            .fontWeight(.medium)
                        
                        HStack(spacing: 14) {
                            Label(
                                Formatters.formatDistance(run.trail.count > 0 ? 150 * Double(run.trail.count) : 0),
                                systemImage: "ruler"
                            )
                            .labelStyle(IconFirstLabelStyle())
                            .rtBodySmall()
                            .foregroundColor(.gray)
                            
                            Label(
                                Formatters.formatDuration(run.duration),
                                systemImage: "clock"
                            )
                            .labelStyle(IconFirstLabelStyle())
                            .rtBodySmall()
                            .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                .frame(width: 280)
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        private func getDayAndDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "M월 d일 (E)"
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter.string(from: date)
        }
    }
    
    struct CategoryCard: View {
        var category: ExploreCategory
        var onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 18))
                            .foregroundColor(category.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .rtBodyLarge()
                            .fontWeight(.medium)
                        
                        Text("새로운 경로 살펴보기")
                            .rtBodySmall()
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                .frame(width: 260)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    struct IconFirstLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 4) {
                configuration.icon
                    .font(.system(size: 10))
                configuration.title
            }
        }
    }
    
    // MARK: - 유틸리티 함수
    private func calculateCurrentPace() -> Double {
        if viewModel.recordingDistance < 100 {
            return 0
        }
        
        let distanceInKm = viewModel.recordingDistance / 1000
        return viewModel.recordingElapsedTime / distanceInKm
    }
 }
