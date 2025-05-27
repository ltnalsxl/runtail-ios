//
//  EnhancedCourseSelectionView.swift
//  RunTail
//
//  Created by 이수민 on 5/10/25.
//

import SwiftUI
import MapKit

struct EnhancedCourseSelectionView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var locationService: LocationService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var nearbyCourses: [Course] = []
    @State private var selectedCourse: Course?
    @State private var isLoading = true
    @State private var previewRegion = MKCoordinateRegion()
    @State private var shouldStartRunning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 헤더
                headerView
                
                if isLoading {
                    loadingView
                } else if nearbyCourses.isEmpty {
                    emptyStateView
                } else {
                    // 메인 콘텐츠
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        // iPad에서는 좌우 분할
                        HStack(spacing: 0) {
                            // 좌측: 코스 목록
                            courseListView
                                .frame(maxWidth: .infinity)
                            
                            Divider()
                            
                            // 우측: 코스 미리보기 지도
                            if let course = selectedCourse {
                                coursePreviewMap(course: course)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("코스를 선택하세요")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(UIColor.systemGray6))
                            }
                        }
                    } else {
                        // iPhone에서는 상하 분할
                        VStack(spacing: 0) {
                            // 상단: 코스 미리보기 지도
                            if let course = selectedCourse {
                                coursePreviewMap(course: course)
                                    .frame(height: 200)
                            } else {
                                Text("코스를 선택하세요")
                                    .foregroundColor(.gray)
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.systemGray6))
                            }
                            
                            Divider()
                            
                            // 하단: 코스 목록
                            courseListView
                                .frame(maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadNearbyCourses()
        }
        .onChange(of: shouldStartRunning) { newValue in
            if newValue, let course = selectedCourse {
                // 코스 선택 화면 닫기
                presentationMode.wrappedValue.dismiss()
                
                // 0.5초 후 러닝 시작 (화면 전환 완료 후)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startFollowingSelectedCourse(course)
                }
            }
        }
    }
    
    // MARK: - 헤더
    var headerView: some View {
        HStack {
            Button("취소") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.rtPrimary)
            
            Spacer()
            
            Text("코스 선택")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("시작") {
                if selectedCourse != nil {
                    shouldStartRunning = true
                }
            }
            .disabled(selectedCourse == nil)
            .foregroundColor(selectedCourse == nil ? .gray : .rtPrimary)
            .fontWeight(.semibold)
        }
        .padding()
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 코스 목록
    var courseListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("주변 코스 (\(nearbyCourses.count)개)")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(nearbyCourses) { course in
                        CourseListItem(
                            course: course,
                            isSelected: selectedCourse?.id == course.id,
                            onSelect: {
                                withAnimation {
                                    selectedCourse = course
                                    setupPreviewRegion(for: course)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 코스 미리보기 지도
    func coursePreviewMap(course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 코스 정보 헤더
            VStack(alignment: .leading, spacing: 8) {
                Text(course.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    Label(Formatters.formatDistance(course.distance), systemImage: "ruler")
                    Label(estimatedTime(for: course), systemImage: "clock")
                    if course.runCount > 0 {
                        Label("\(course.runCount)회 실행", systemImage: "figure.run")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            
            // 지도
            ZStack {
                if #available(iOS 17.0, *) {
                    Map(position: .constant(.region(previewRegion))) {
                        // 코스 경로
                        MapPolyline(coordinates: course.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(LinearGradient.rtPrimaryGradient, lineWidth: 4)
                        
                        // 시작점
                        if let first = course.coordinates.first {
                            Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)) {
                                ZStack {
                                    Circle()
                                        .fill(Color.rtSuccess)
                                        .frame(width: 30, height: 30)
                                    
                                    Image(systemName: "flag.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                                .shadow(radius: 3)
                            }
                        }
                        
                        // 종료점
                        if let last = course.coordinates.last, course.coordinates.count > 1 {
                            Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lng)) {
                                ZStack {
                                    Circle()
                                        .fill(Color.rtError)
                                        .frame(width: 30, height: 30)
                                    
                                    Image(systemName: "flag.checkered")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                                .shadow(radius: 3)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                } else {
                    // iOS 16 이하용 미리보기 지도
                    CoursePreviewMapForSelection(
                        region: $previewRegion,
                        course: course
                    )
                }
                
                // 예상 경로 오버레이
                VStack {
                    Spacer()
                    
                    HStack {
                        Text("예상 소요 시간: \(estimatedTime(for: course))")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .frame(maxHeight: .infinity)
            .cornerRadius(16)
        }
    }
    
    // MARK: - 기타 뷰들
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("주변 코스를 검색 중...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("주변에 코스가 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("다른 위치로 이동하거나\n먼저 코스를 생성해보세요")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 헬퍼 메서드
    private func loadNearbyCourses() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let userLocation = locationService.lastLocation?.coordinate else {
                isLoading = false
                return
            }
            
            nearbyCourses = viewModel.findNearbyCoursesFor(coordinate: userLocation, radius: 10000)
            isLoading = false
            
            // 첫 번째 코스를 자동으로 선택
            if let firstCourse = nearbyCourses.first {
                selectedCourse = firstCourse
                setupPreviewRegion(for: firstCourse)
            }
        }
    }
    
    private func setupPreviewRegion(for course: Course) {
        guard !course.coordinates.isEmpty else { return }
        
        let coords = course.coordinates
        let minLat = coords.map(\.lat).min() ?? 0
        let maxLat = coords.map(\.lat).max() ?? 0
        let minLng = coords.map(\.lng).min() ?? 0
        let maxLng = coords.map(\.lng).max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        
        let latDelta = (maxLat - minLat) * 1.2
        let lngDelta = (maxLng - minLng) * 1.2
        
        previewRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.005),
                longitudeDelta: max(lngDelta, 0.005)
            )
        )
    }
    
    private func estimatedTime(for course: Course) -> String {
        let estimatedSeconds = course.distance / 1000 * viewModel.getUserAveragePace()
        return Formatters.formatDuration(Int(estimatedSeconds))
    }
    
    private func startFollowingSelectedCourse(_ course: Course) {
        locationService.startHighAccuracyLocationUpdates()
        locationService.onLocationUpdate = { coordinate in
            viewModel.addLocationToRecordingWithCourseTracking(coordinate: coordinate)
        }
        viewModel.startFollowingCourse(course)
    }
}

// MARK: - iOS 16 이하용 코스 미리보기 지도 뷰
struct CoursePreviewMapForSelection: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var course: Course
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
        
        // 기존 오버레이와 어노테이션 제거
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)
        
        // 코스 경로 추가
        let coordinates = course.coordinates.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        
        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            uiView.addOverlay(polyline)
        }
        
        // 시작점과 종료점 어노테이션 추가
        if let first = coordinates.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = first
            startAnnotation.title = "시작"
            uiView.addAnnotation(startAnnotation)
        }
        
        if let last = coordinates.last, coordinates.count > 1 {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = last
            endAnnotation.title = "종료"
            uiView.addAnnotation(endAnnotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CoursePreviewMapForSelection
        
        init(_ parent: CoursePreviewMapForSelection) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.rtPrimary)
                renderer.lineWidth = 4
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "CoursePoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            }
            
            annotationView?.annotation = annotation
            
            if annotation.title == "시작" {
                annotationView?.markerTintColor = UIColor(Color.rtSuccess)
                annotationView?.glyphImage = UIImage(systemName: "flag.fill")
            } else if annotation.title == "종료" {
                annotationView?.markerTintColor = UIColor(Color.rtError)
                annotationView?.glyphImage = UIImage(systemName: "flag.checkered")
            }
            
            return annotationView
        }
    }
}

// MARK: - 코스 목록 아이템
struct CourseListItem: View {
    let course: Course
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 선택 표시
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.rtPrimary : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.rtPrimary)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // 코스 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.rtPrimary.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "map.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .rtPrimary : .gray)
                }
                
                // 코스 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(Formatters.formatDistance(course.distance))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(course.distance / 1000 * 6))분 예상")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if course.runCount > 0 {
                        Text("실행 횟수: \(course.runCount)회")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.rtPrimary.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.rtPrimary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
