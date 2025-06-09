//
//  CourseDetailView.swift
//  RunTail
//
//  Updated on 5/10/25.
//

import SwiftUI
import MapKit
import Firebase

struct CourseDetailView: View {
    // MARK: - 프로퍼티
    let course: Course
    @Environment(\.presentationMode) var presentationMode
    @State private var region = MKCoordinateRegion()
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isPublic = false
    @State private var isSaving = false
    @State private var elevationData: [Double] = []
    @State private var showElevationChart = false
    @State private var showSummarySheet = false
    @State private var alertMessage: String?
    @State private var isLoading = true
    
    // 의존성 주입
    @EnvironmentObject var viewModel: MapViewModel
    @EnvironmentObject var locationService: LocationService
    @Environment(\.checkBeforeStartRunning) var checkBeforeStartRunning
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 고정 헤더
                ZStack {
                    LinearGradient.rtPrimaryGradient
                        .ignoresSafeArea(edges: .top)
                    
                    VStack {
                        Spacer()
                            .frame(height: getSafeAreaTop())
                        
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text("코스 상세")
                                .foregroundColor(.white)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button(action: { showShareSheet = true }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
                .frame(height: 44 + getSafeAreaTop())
                
                // 메인 콘텐츠
                ScrollView {
                    VStack(spacing: 16) {
                        courseInfoCard.padding(.top, 20)
                        mapSection
                        statisticsSection
                        elevationChartSection
                        actionButtonsSection
                        courseDetailsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color.rtBackgroundAdaptive)
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            setupInitialData()
        }
        .alert("코스 삭제", isPresented: $showDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                deleteCourse()
            }
        } message: {
            Text("정말 이 코스를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
        }
        .alert("코스 제목 편집", isPresented: $isEditingTitle) {
            TextField("코스 이름", text: $editedTitle)
            Toggle("공개 코스로 설정", isOn: $isPublic)
            Button("저장") { updateCourseInfo() }
            Button("취소", role: .cancel) {
                editedTitle = course.title
                isPublic = course.isPublic
            }
        } message: {
            Text("코스 정보를 수정합니다.")
        }
        .sheet(isPresented: $showSummarySheet) {
            CourseSummarySheet(
                course: course,
                elevationData: elevationData,
                averagePace: viewModel.getUserAveragePace(),
                onDismiss: { showSummarySheet = false },
                onStartRunning: startRunningThisCourse
            )
            .presentationDetents([.medium, .large])
        }
        .alert("오류", isPresented: Binding(
            get: { alertMessage != nil },
            set: { value in if !value { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    // MARK: - 코스 정보 카드
    var courseInfoCard: some View {
        RTCardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(course.title)
                        .rtHeading2()
                    
                    Spacer()
                    
                    Button(action: {
                        editedTitle = course.title
                        isPublic = course.isPublic
                        isEditingTitle = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                
                HStack(spacing: 16) {
                    Label(Formatters.formatDate(course.createdAt), systemImage: "calendar")
                        .rtBodySmall()
                        .foregroundColor(.secondary)
                    
                    if course.isPublic {
                        Label("공개", systemImage: "globe")
                            .rtBodySmall()
                            .foregroundColor(.rtSuccess)
                    } else {
                        Label("비공개", systemImage: "lock")
                            .rtBodySmall()
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 지도 섹션
    var mapSection: some View {
        RTCardView {
            if course.coordinates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)

                    Text("경로 데이터를 불러올 수 없습니다")
                        .rtBodySmall()
                        .foregroundColor(.secondary)

                    Button("새로고침") {
                        setupInitialData()
                    }
                    .rtBodySmall()
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                if #available(iOS 17.0, *) {
                    Map {
                        if let firstCoord = course.coordinates.first {
                            Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                                VStack(spacing: 2) {
                                    Image(systemName: "flag.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("시작")
                                        .font(.caption2.weight(.bold))
                                }
                                .foregroundColor(.rtSuccess)
                                .padding(6)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                            }
                        }
                        
                        if let lastCoord = course.coordinates.last, course.coordinates.count > 1 {
                            Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                                VStack(spacing: 2) {
                                    Image(systemName: "flag.checkered")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("종료")
                                        .font(.caption2.weight(.bold))
                                }
                                .foregroundColor(.rtError)
                                .padding(6)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                            }
                        }
                        
                        MapPolyline(coordinates: course.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .stroke(LinearGradient.rtPrimaryGradient, lineWidth: 4)
                    }
                    .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                    .frame(height: 250)
                    .cornerRadius(16)
                } else {
                    EnhancedCourseMapView(
                        region: $region,
                        coordinates: course.coordinates,
                        kilometerMarkers: getKilometerMarkers()
                    )
                    .frame(height: 250)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - 통계 카드 섹션
    var statisticsSection: some View {
        Group {
            if course.coordinates.isEmpty {
                RTCardView {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)

                        Text("통계 데이터를 불러올 수 없습니다")
                            .rtBodySmall()
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                RTCardView {
                    HStack(spacing: 16) {
                        EnhancedStatisticCard(
                            title: "총 거리",
                            value: Formatters.formatDistance(course.distance),
                            icon: "ruler",
                            color: .rtPrimary
                        )

                        let estimatedTime = Int(course.distance / 1000 * viewModel.getUserAveragePace())
                        EnhancedStatisticCard(
                            title: "예상 시간",
                            value: Formatters.formatDuration(estimatedTime),
                            icon: "clock",
                            color: .rtSecondary
                        )

                        let elevationGain = calculateElevationGain()
                        EnhancedStatisticCard(
                            title: "고도 변화",
                            value: "\(Int(elevationGain))m",
                            icon: "mountain.2",
                            color: .rtSuccess
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - 고도 차트 섹션
    var elevationChartSection: some View {
        RTCardView {
            if elevationData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)

                    Text("고도 데이터를 불러올 수 없습니다")
                        .rtBodySmall()
                        .foregroundColor(.secondary)

                    Button("새로고침") {
                        calculateElevationProfile()
                    }
                    .rtBodySmall()
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("고도 프로필")
                            .rtHeading3()

                        Spacer()

                        Button(action: {
                            showElevationChart.toggle()
                        }) {
                            Text(showElevationChart ? "접기" : "자세히")
                                .rtBodySmall()
                                .foregroundColor(.rtPrimary)
                        }
                    }

                    if showElevationChart {
                        EnhancedElevationChartView(elevationData: elevationData, distance: course.distance)
                            .frame(height: 160)
                            .padding(.vertical, 8)
                    } else {
                        EnhancedElevationMiniChartView(elevationData: elevationData)
                            .frame(height: 60)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - 액션 버튼 섹션
    var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: startRunningThisCourse) {
                HStack {
                    Image(systemName: "figure.run")
                    Text("이 코스로 달리기")
                }
                .rtBodyLarge()
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.rtPrimaryGradient)
                .foregroundColor(.white)
                .cornerRadius(20)
                .shadow(color: Color.rtPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Button(action: {
                showSummarySheet = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("코스 복습하기")
                }
                .rtBodyLarge()
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(20)
            }
            
            if course.createdBy == viewModel.userId {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("코스 삭제하기")
                    }
                    .rtBodyLarge()
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemBackground))
                    .foregroundColor(.rtError)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.rtError.opacity(0.5), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - 코스 상세 정보 섹션
    var courseDetailsSection: some View {
        RTCardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("코스 정보")
                    .rtHeading3()
                
                CourseDetailRow(icon: "point.3.connected.trianglepath.dotted", title: "트래킹 포인트", value: "\(course.coordinates.count)개", color: .rtPrimary)
                
                Divider()
                
                CourseDetailRow(icon: "arrow.up.forward", title: "고도 상승", value: "\(Int(calculateElevationGain()))m", color: .rtSuccess)
                
                Divider()
                
                CourseDetailRow(icon: "arrow.down.forward", title: "고도 하강", value: "\(Int(calculateElevationLoss()))m", color: .rtError)
            }
        }
    }
    
    // MARK: - 헬퍼 메서드
    private func setupInitialData() {
        setupMapRegion()
        calculateElevationProfile()
        editedTitle = course.title
        isPublic = course.isPublic
    }
    
    private func setupMapRegion() {
        guard !course.coordinates.isEmpty else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            return
        }
        
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
        
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        
        let latDelta = (maxLat - minLat) * 1.3
        let lngDelta = (maxLng - minLng) * 1.3
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.005), longitudeDelta: max(lngDelta, 0.005))
        )
    }
    
    private func getKilometerMarkers() -> [(Int, CLLocationCoordinate2D)] {
        guard course.coordinates.count >= 2 else { return [] }
        
        var markers: [(Int, CLLocationCoordinate2D)] = []
        var distance: Double = 0
        var lastKm: Int = 0
        
        var lastCoord = CLLocationCoordinate2D(
            latitude: course.coordinates[0].lat,
            longitude: course.coordinates[0].lng
        )
        
        for i in 1..<course.coordinates.count {
            let currentCoord = CLLocationCoordinate2D(
                latitude: course.coordinates[i].lat,
                longitude: course.coordinates[i].lng
            )
            
            let lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let currentLocation = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
            
            let segmentDistance = lastLocation.distance(from: currentLocation)
            distance += segmentDistance
            
            let currentKm = Int(distance / 1000)
            if currentKm > lastKm {
                let ratio = (Double(currentKm) * 1000 - (distance - segmentDistance)) / segmentDistance
                let interpolatedLat = lastCoord.latitude + (currentCoord.latitude - lastCoord.latitude) * ratio
                let interpolatedLng = lastCoord.longitude + (currentCoord.longitude - lastCoord.longitude) * ratio
                
                markers.append((currentKm, CLLocationCoordinate2D(
                    latitude: interpolatedLat,
                    longitude: interpolatedLng
                )))
                
                lastKm = currentKm
            }
            
            lastCoord = currentCoord
        }
        
        return markers
    }
    
    private func calculateElevationProfile() {
        elevationData = []
        
        let coordinateCount = course.coordinates.count
        if coordinateCount > 0 {
            var currentElevation = 50.0
            
            let sampleCount = min(200, coordinateCount)
            
            for i in 0..<sampleCount {
                if i % 10 == 0 {
                    currentElevation += Double.random(in: -15...15)
                } else {
                    currentElevation += Double.random(in: -5...5)
                }
                
                currentElevation = max(0, currentElevation)
                
                elevationData.append(currentElevation)
            }
        }
    }
    
    private func calculateElevationGain() -> Double {
        guard elevationData.count >= 2 else { return 0 }
        
        var totalGain: Double = 0
        
        for i in 1..<elevationData.count {
            let diff = elevationData[i] - elevationData[i-1]
            if diff > 0 {
                totalGain += diff
            }
        }
        
        return totalGain
    }
    
    private func calculateElevationLoss() -> Double {
        guard elevationData.count >= 2 else { return 0 }
        
        var totalLoss: Double = 0
        
        for i in 1..<elevationData.count {
            let diff = elevationData[i] - elevationData[i-1]
            if diff < 0 {
                totalLoss += abs(diff)
            }
        }
        
        return totalLoss
    }
    
    private func startRunningThisCourse() {
        checkBeforeStartRunning { canStart in
            if canStart {
                presentationMode.wrappedValue.dismiss()
                
                locationService.startHighAccuracyLocationUpdates()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.startFollowingCourse(course)
                }
            }
        }
    }
    
    private func updateCourseInfo() {
        guard editedTitle.trimmingCharacters(in: .whitespaces) != "" else {
            return
        }
        
        isSaving = true
        
        let db = Firestore.firestore()
        db.collection("courses").document(course.id).updateData([
            "title": editedTitle,
            "isPublic": isPublic
        ]) { error in
            DispatchQueue.main.async {
                isSaving = false
                
                if let error = error {
                    alertMessage = error.localizedDescription
                } else {
                    viewModel.loadMyCourses()
                }
            }
        }
    }
    
    private func deleteCourse() {
        let db = Firestore.firestore()
        db.collection("courses").document(course.id).delete { error in
            if let error = error {
                alertMessage = error.localizedDescription
            } else {
                viewModel.loadMyCourses()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - 강화된 통계 카드 컴포넌트
struct EnhancedStatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        RTCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(title)
                        .rtBodySmall()
                        .foregroundColor(.secondary)
                }
                
                Text(value)
                    .rtHeading3()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 강화된 고도 차트 뷰
struct EnhancedElevationChartView: View {
    let elevationData: [Double]
    let distance: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ForEach(0..<4) { i in
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .frame(height: 1)
                        if i < 3 {
                            Spacer()
                        }
                    }
                }
                
                Path { path in
                    guard elevationData.count > 1 else { return }
                    
                    let maxElevation = elevationData.max() ?? 0
                    let minElevation = elevationData.min() ?? 0
                    let elevationRange = max(maxElevation - minElevation, 10)
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(elevationData.count - 1)
                    
                    path.move(to: CGPoint(
                        x: 0,
                        y: height - CGFloat((elevationData[0] - minElevation) / elevationRange) * height
                    ))
                    
                    for i in 1..<elevationData.count {
                        let x = stepX * CGFloat(i)
                        let y = height - CGFloat((elevationData[i] - minElevation) / elevationRange) * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.rtPrimary.opacity(0.7),
                            Color.rtPrimary.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                Path { path in
                    guard elevationData.count > 1 else { return }
                    
                    let maxElevation = elevationData.max() ?? 0
                    let minElevation = elevationData.min() ?? 0
                    let elevationRange = max(maxElevation - minElevation, 10)
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(elevationData.count - 1)
                    
                    path.move(to: CGPoint(
                        x: 0,
                        y: height - CGFloat((elevationData[0] - minElevation) / elevationRange) * height
                    ))
                    
                    for i in 1..<elevationData.count {
                        let x = stepX * CGFloat(i)
                        let y = height - CGFloat((elevationData[i] - minElevation) / elevationRange) * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.rtPrimary, lineWidth: 2)
                
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        if let maxElevation = elevationData.max() {
                            Text("\(Int(maxElevation))m")
                                .rtCaption()
                                .foregroundColor(.secondary)
                                .padding(.bottom, geometry.size.height - 15)
                        }
                        
                        if let minElevation = elevationData.min() {
                            Text("\(Int(minElevation))m")
                                .rtCaption()
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Spacer()
                        Text("\(Int(distance / 1000))km")
                            .rtCaption()
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - 강화된 고도 미니 차트 뷰
struct EnhancedElevationMiniChartView: View {
    let elevationData: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard elevationData.count > 1 else { return }
                
                let maxElevation = elevationData.max() ?? 0
                let minElevation = elevationData.min() ?? 0
                let elevationRange = max(maxElevation - minElevation, 10)
                
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(elevationData.count - 1)
                
                path.move(to: CGPoint(
                    x: 0,
                    y: height - CGFloat((elevationData[0] - minElevation) / elevationRange) * height
                ))
                
                for i in 1..<elevationData.count {
                    let x = stepX * CGFloat(i)
                    let y = height - CGFloat((elevationData[i] - minElevation) / elevationRange) * height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.rtPrimary, lineWidth: 2)
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - iOS 16 이하를 위한 강화된 코스 지도 뷰
struct EnhancedCourseMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var coordinates: [Coordinate]
    var kilometerMarkers: [(Int, CLLocationCoordinate2D)]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.region = region
        
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)
        
        guard !coordinates.isEmpty else { return }
        
        let mapCoords = coordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        
        if let first = mapCoords.first {
            let startPin = CourseAnnotation(coordinate: first, title: "시작", type: .start)
            uiView.addAnnotation(startPin)
        }
        
        if let last = mapCoords.last, mapCoords.count > 1 {
            let endPin = CourseAnnotation(coordinate: last, title: "종료", type: .end)
            uiView.addAnnotation(endPin)
                   }
                   
                   for (km, coordinate) in kilometerMarkers {
                       let kmPin = CourseAnnotation(coordinate: coordinate, title: "\(km)km", type: .kilometer)
                       uiView.addAnnotation(kmPin)
                   }
                   
                   let polyline = MKPolyline(coordinates: mapCoords, count: mapCoords.count)
                   uiView.addOverlay(polyline)
               }
               
               func makeCoordinator() -> Coordinator {
                   Coordinator(self)
               }
               
               class CourseAnnotation: NSObject, MKAnnotation {
                   enum AnnotationType {
                       case start, end, kilometer
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
                   var parent: EnhancedCourseMapView
                   
                   init(_ parent: EnhancedCourseMapView) {
                       self.parent = parent
                   }
                   
                   func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                       if let courseAnnotation = annotation as? CourseAnnotation {
                           switch courseAnnotation.type {
                           case .start, .end:
                               let identifier = "CoursePointAnnotation"
                               var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                               
                               if annotationView == nil {
                                   annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                                   annotationView?.canShowCallout = true
                               }
                               
                               annotationView?.annotation = annotation
                               
                               if courseAnnotation.type == .start {
                                   annotationView?.markerTintColor = UIColor(Color.rtSuccess)
                                   annotationView?.glyphImage = UIImage(systemName: "flag.fill")
                               } else {
                                   annotationView?.markerTintColor = UIColor(Color.rtError)
                                   annotationView?.glyphImage = UIImage(systemName: "flag.checkered")
                               }
                               
                               return annotationView
                               
                           case .kilometer:
                               let identifier = "KilometerAnnotation"
                               var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                               
                               if annotationView == nil {
                                   annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                                   annotationView?.canShowCallout = true
                               }
                               
                               annotationView?.annotation = annotation
                               
                               let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
                               label.text = courseAnnotation.title
                               label.font = UIFont.boldSystemFont(ofSize: 10)
                               label.textAlignment = .center
                               label.textColor = UIColor(Color.rtPrimary)
                               label.backgroundColor = UIColor.white
                               label.layer.cornerRadius = 8
                               label.layer.borderColor = UIColor.gray.withAlphaComponent(0.4).cgColor
                               label.layer.borderWidth = 1
                               label.layer.masksToBounds = true

                               annotationView?.contentMode = .scaleAspectFit
                               annotationView?.addSubview(label)
                               annotationView?.frame.size = label.frame.size
                               
                               return annotationView
                           }
                       }
                       
                       return nil
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
               }
            }

            // MARK: - 코스 상세 행 컴포넌트
            struct CourseDetailRow: View {
               var icon: String
               var title: String
               var value: String
               var color: Color
               
               var body: some View {
                   HStack {
                       Image(systemName: icon)
                           .foregroundColor(color)
                           .frame(width: 24)
                       
                       Text(title)
                           .rtBodyLarge()
                       
                       Spacer()
                       
                       Text(value)
                           .rtBodyLarge()
                           .foregroundColor(.secondary)
                   }
                   .padding(.vertical, 4)
               }
            }

            // MARK: - 코스 요약 시트
            struct CourseSummarySheet: View {
               let course: Course
               let elevationData: [Double]
               let averagePace: Double
               let onDismiss: () -> Void
               let onStartRunning: () -> Void
               
               var body: some View {
                   NavigationView {
                       List {
                           Section(header: Text("코스 요약")) {
                               InfoRow(title: "이름", value: course.title)
                               InfoRow(title: "거리", value: Formatters.formatDistance(course.distance))
                               InfoRow(title: "예상 시간", value: Formatters.formatDuration(Int(course.distance / 1000 * averagePace)))
                               InfoRow(title: "생성일", value: Formatters.formatDate(course.createdAt))
                               InfoRow(title: "공개 여부", value: course.isPublic ? "공개" : "비공개")
                           }
                           
                           Section(header: Text("고도 정보")) {
                               if !elevationData.isEmpty {
                                   InfoRow(title: "고도 상승", value: "\(Int(calculateElevationGain(elevationData: elevationData)))m")
                                   InfoRow(title: "고도 하강", value: "\(Int(calculateElevationLoss(elevationData: elevationData)))m")
                                   InfoRow(title: "최고 고도", value: "\(Int(elevationData.max() ?? 0))m")
                                   InfoRow(title: "최저 고도", value: "\(Int(elevationData.min() ?? 0))m")
                               } else {
                                   Text("고도 정보가 없습니다")
                                       .foregroundColor(.secondary)
                               }
                           }
                           
                           Section {
                               Button(action: onStartRunning) {
                                   HStack {
                                       Spacer()
                                       Image(systemName: "figure.run")
                                       Text("이 코스로 달리기")
                                       Spacer()
                                   }
                                   .font(.system(size: 16, weight: .medium))
                               }
                               .foregroundColor(.white)
                               .listRowBackground(LinearGradient.rtPrimaryGradient)
                           }
                       }
                       .listStyle(InsetGroupedListStyle())
                       .navigationTitle("코스 정보")
                       .navigationBarTitleDisplayMode(.inline)
                       .toolbar {
                           ToolbarItem(placement: .navigationBarLeading) {
                               Button("닫기") {
                                   onDismiss()
                               }
                           }
                       }
                   }
               }
               
               struct InfoRow: View {
                   var title: String
                   var value: String
                   
                   var body: some View {
                       HStack {
                           Text(title)
                           Spacer()
                           Text(value)
                               .foregroundColor(.secondary)
                       }
                   }
               }
               
               private func calculateElevationGain(elevationData: [Double]) -> Double {
                   guard elevationData.count >= 2 else { return 0 }
                   
                   var totalGain: Double = 0
                   
                   for i in 1..<elevationData.count {
                       let diff = elevationData[i] - elevationData[i-1]
                       if diff > 0 {
                           totalGain += diff
                       }
                   }
                   
                   return totalGain
               }
               
               private func calculateElevationLoss(elevationData: [Double]) -> Double {
                   guard elevationData.count >= 2 else { return 0 }
                   
                   var totalLoss: Double = 0
                   
                   for i in 1..<elevationData.count {
                       let diff = elevationData[i] - elevationData[i-1]
                       if diff < 0 {
                           totalLoss += abs(diff)
                       }
                   }
                   
                   return totalLoss
               }
            }
