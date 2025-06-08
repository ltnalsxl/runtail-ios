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
    
    // 의존성 주입
    @EnvironmentObject var viewModel: MapViewModel
    @EnvironmentObject var locationService: LocationService
    @Environment(\.checkBeforeStartRunning) var checkBeforeStartRunning
    
    // MARK: - 바디
    var body: some View {
        ZStack {
            // 배경색
            Color.rtBackgroundAdaptive
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 상단 헤더 배경
                LinearGradient.rtPrimaryGradient
                    .frame(height: 140)
                    .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                    .ignoresSafeArea(edges: .top)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .overlay(alignment: .top) {
                        // 헤더 내용
                        VStack {
                            // 뒤로가기, 제목, 공유 버튼
                            HStack {
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                
                                Spacer()
                                
                                Text("코스 상세")
                                    .rtBodyLarge()
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    showShareSheet = true
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.top, getSafeAreaTop())
                            .padding(.horizontal, 16)
                            
                            Spacer()
                        }
                
                // 스크롤 가능한 콘텐츠
                ScrollView {
                    VStack(spacing: 16) {
                        // 코스 정보 카드
                        courseInfoCard
                            .padding(.top, 20)
                        
                        // 지도 섹션
                        mapSection
                        
                        // 통계 카드 섹션
                        statisticsSection
                        
                        // 고도 차트 섹션
                        if !elevationData.isEmpty {
                            elevationChartSection
                        }
                        
                        // 액션 버튼 섹션
                        actionButtonsSection
                        
                        // 코스 상세 섹션
                        courseDetailsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
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
            
            Button("저장") {
                updateCourseInfo()
            }
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
    }
    }

    
    // MARK: - 코스 정보 카드
    var courseInfoCard: some View {
        RTCardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // 코스 제목
                    Text(course.title)
                        .rtHeading2()
                    
                    Spacer()
                    
                    // 편집 버튼
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
                
                // 생성 정보
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
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map {
                    // 시작점 표시
                    if let firstCoord = course.coordinates.first {
                        Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                            VStack(spacing: 2) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("시작")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundColor(Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1) : UIColor(Color.rtSuccess) }))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.9) : UIColor.white }))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
                        }
                    }
                    
                    // 종료점 표시
                    if let lastCoord = course.coordinates.last, course.coordinates.count > 1 {
                        Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                            VStack(spacing: 2) {
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("종료")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundColor(Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1) : UIColor(Color.rtError) }))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.9) : UIColor.white }))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
                        }
                    }
                    
                    // 경로 표시
                    MapPolyline(coordinates: course.coordinates.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                    })
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.rtPrimary, Color.rtSecondary]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 4
                    )
                    
                    // 1km 마다 거리 표시
                    ForEach(getKilometerMarkers(), id: \.0) { index, coordinate in
                        Annotation("\(index)km", coordinate: coordinate) {
                            Text("\(index)km")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(Color(UIColor { trait in
                                    trait.userInterfaceStyle == .dark ? UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1) : UIColor(Color.rtPrimary)
                                }))
                                .padding(6)
                                .background(
                                    Circle().fill(Color(UIColor { trait in
                                        trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.9) : UIColor.white
                                    }))
                                )
                                .overlay(
                                    Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
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
            #else
            EnhancedCourseMapView(
                region: $region,
                coordinates: course.coordinates,
                kilometerMarkers: getKilometerMarkers()
            )
            .frame(height: 250)
            .cornerRadius(16)
            #endif
        }
    }
    
    // MARK: - 통계 카드 섹션
    var statisticsSection: some View {
        HStack(spacing: 16) {
            // 거리 카드
            EnhancedStatisticCard(
                title: "총 거리",
                value: Formatters.formatDistance(course.distance),
                icon: "ruler",
                color: .rtPrimary
            )
            
            // 시간 카드 (예상 시간 - 사용자 평균 페이스 기반)
            let estimatedTime = Int(course.distance / 1000 * viewModel.getUserAveragePace())
            EnhancedStatisticCard(
                title: "예상 시간",
                value: Formatters.formatDuration(estimatedTime),
                icon: "clock",
                color: .rtSecondary
            )
            
            // 고도 차이 카드
            let elevationGain = calculateElevationGain()
            EnhancedStatisticCard(
                title: "고도 변화",
                value: "\(Int(elevationGain))m",
                icon: "mountain.2",
                color: .rtSuccess
            )
        }
    }
    
    // MARK: - 고도 차트 섹션
    var elevationChartSection: some View {
        RTCardView {
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
    
    // MARK: - 액션 버튼 섹션
    var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 이 코스로 달리기 버튼
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
            
            // 코스 요약 버튼
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
            
            // 코스 삭제 버튼 (자신이 만든 코스인 경우에만)
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
                
                // 코스 좌표 수
                CourseDetailRow(icon: "point.3.connected.trianglepath.dotted", title: "트래킹 포인트", value: "\(course.coordinates.count)개", color: .rtPrimary)
                
                Divider()
                
                // 누적 고도 상승
                CourseDetailRow(icon: "arrow.up.forward", title: "고도 상승", value: "\(Int(calculateElevationGain()))m", color: .rtSuccess)
                
                Divider()
                
                // 누적 고도 하강
                CourseDetailRow(icon: "arrow.down.forward", title: "고도 하강", value: "\(Int(calculateElevationLoss()))m", color: .rtError)
            }
        }
    }
    
    // 코스 상세 행 컴포넌트
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
    
    // MARK: - 헬퍼 메서드
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
    
    // 초기 데이터 설정
    private func setupInitialData() {
        setupMapRegion()
        calculateElevationProfile()
        editedTitle = course.title
        isPublic = course.isPublic
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
        let latDelta = (maxLat - minLat) * 1.3 // 30% 여백
        let lngDelta = (maxLng - minLng) * 1.3
        
        // 지도 영역 설정
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.005), longitudeDelta: max(lngDelta, 0.005))
        )
    }
    
    // 1km 마다 마커 생성
    private func getKilometerMarkers() -> [(Int, CLLocationCoordinate2D)] {
        guard course.coordinates.count >= 2 else { return [] }
        
        var markers: [(Int, CLLocationCoordinate2D)] = []
        var distance: Double = 0
        var lastKm: Int = 0
        
        // 첫 번째 좌표
        var lastCoord = CLLocationCoordinate2D(
            latitude: course.coordinates[0].lat,
            longitude: course.coordinates[0].lng
        )
        
        // 각 좌표 사이의 거리를 누적하며 1km 마다 마커 추가
        for i in 1..<course.coordinates.count {
            let currentCoord = CLLocationCoordinate2D(
                latitude: course.coordinates[i].lat,
                longitude: course.coordinates[i].lng
            )
            
            let lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let currentLocation = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
            
            let segmentDistance = lastLocation.distance(from: currentLocation)
            distance += segmentDistance
            
            // 1km 단위로 마커 추가
            let currentKm = Int(distance / 1000)
            if currentKm > lastKm {
                // 정확한 1km 지점 보간
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
    
    // 고도 프로파일 계산 (실제 앱에서는 API나 CoreLocation에서 고도 정보 활용)
    private func calculateElevationProfile() {
        // 예시: 임의의 고도 데이터 생성
        elevationData = []
        
        // 코스 좌표 수에 따라 고도 데이터 생성
        let coordinateCount = course.coordinates.count
        if coordinateCount > 0 {
            // 시작 고도: 50m (예시)
            var currentElevation = 50.0
            
            // 코스 길이에 따라 포인트 샘플링
            let sampleCount = min(200, coordinateCount) // 최대 200개 샘플
            
            for i in 0..<sampleCount {
                // 일부 변동을 주어 자연스러운 고도 변화 시뮬레이션
                if i % 10 == 0 {
                    currentElevation += Double.random(in: -15...15)
                } else {
                    currentElevation += Double.random(in: -5...5)
                }
                
                // 고도는 최소 0m
                currentElevation = max(0, currentElevation)
                
                elevationData.append(currentElevation)
            }
        }
    }
    
    // 누적 고도 상승 계산
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
    
    // 누적 고도 하강 계산
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
    
    // 코스 따라 달리기 시작
    private func startRunningThisCourse() {
        checkBeforeStartRunning { canStart in
            if canStart {
                // 현재 화면 닫기
                presentationMode.wrappedValue.dismiss()
                
                // 위치 서비스 정확도 높이기
                locationService.startHighAccuracyLocationUpdates()
                
                // 0.5초 후 러닝 시작 (뷰 전환 후)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // MapViewModel에 코스 팔로우 모드로 러닝 시작
                    viewModel.startFollowingCourse(course)
                }
            }
        }
    }
    
    // 코스 정보 업데이트
    private func updateCourseInfo() {
        guard editedTitle.trimmingCharacters(in: .whitespaces) != "" else {
            return
        }
        
        isSaving = true
        
        // Firestore에서 코스 정보 업데이트
        let db = Firestore.firestore()
        db.collection("courses").document(course.id).updateData([
            "title": editedTitle,
            "isPublic": isPublic
        ]) { error in
            DispatchQueue.main.async {
                isSaving = false
                
                if let error = error {
                    print("Error updating course: \(error)")
                    // 에러 처리
                } else {
                    // 성공 시 코스 목록 갱신
                    viewModel.loadMyCourses()
                }
            }
        }
    }
    
    // 코스 삭제
    private func deleteCourse() {
        // Firestore에서 코스 삭제
        let db = Firestore.firestore()
        db.collection("courses").document(course.id).delete { error in
            if let error = error {
                print("Error deleting course: \(error)")
                // 에러 처리
            } else {
                // 성공 시 코스 목록 갱신 후 이전 화면으로 돌아가기
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
                // 배경 그리드
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
                
                // 고도 차트
                Path { path in
                    guard elevationData.count > 1 else { return }
                    
                    let maxElevation = elevationData.max() ?? 0
                    let minElevation = elevationData.min() ?? 0
                    let elevationRange = max(maxElevation - minElevation, 10) // 최소 10m 범위
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(elevationData.count - 1)
                    
                    // 첫 지점 설정
                    path.move(to: CGPoint(
                        x: 0,
                        y: height - CGFloat((elevationData[0] - minElevation) / elevationRange) * height
                    ))
                    
                    // 나머지 지점 연결
                    for i in 1..<elevationData.count {
                        let x = stepX * CGFloat(i)
                        let y = height - CGFloat((elevationData[i] - minElevation) / elevationRange) * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    // 차트 하단 마무리
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
                
                // 고도 차트 선
                Path { path in
                    guard elevationData.count > 1 else { return }
                    
                    let maxElevation = elevationData.max() ?? 0
                    let minElevation = elevationData.min() ?? 0
                    let elevationRange = max(maxElevation - minElevation, 10) // 최소 10m 범위
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(elevationData.count - 1)
                    
                    // 첫 지점 설정
                    path.move(to: CGPoint(
                        x: 0,
                        y: height - CGFloat((elevationData[0] - minElevation) / elevationRange) * height
                    ))
                    
                    // 나머지 지점 연결
                    for i in 1..<elevationData.count {
                        let x = stepX * CGFloat(i)
                        let y = height - CGFloat((elevationData[i] - minElevation) / elevationRange) * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.rtPrimary, lineWidth: 2)
                
                // 고도 레이블
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
                    
                    // 거리 레이블
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
                let elevationRange = max(maxElevation - minElevation, 10) // 최소 10m 범위
                
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(elevationData.count - 1)
                
                // 첫 지점 설정
                path.move(to: CGPoint(
                    x: 0,
                    y: height - CGFloat((elevationData[0] - minElevation) / elevationRange) * height
                ))
                
                // 나머지 지점 연결
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
        
        // 지도 스타일 설정
        mapView.mapType = .standard
        
        // 컨트롤 표시
        mapView.showsCompass = true
        mapView.showsScale = true
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.region = region
        
        // 기존 오버레이와 어노테이션 제거
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)
        
        // 코스 경로가 없으면 종료
        guard !coordinates.isEmpty else { return }
        
        // 좌표 변환
        let mapCoords = coordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        
        // 시작점과 종료점 어노테이션 추가
        if let first = mapCoords.first {
            let startPin = CourseAnnotation(coordinate: first, title: "시작", type: .start)
            uiView.addAnnotation(startPin)
        }
        
        if let last = mapCoords.last, mapCoords.count > 1 {
            let endPin = CourseAnnotation(coordinate: last, title: "종료", type: .end)
            uiView.addAnnotation(endPin)
        }
        
        // 킬로미터 마커 추가
        for (km, coordinate) in kilometerMarkers {
            let kmPin = CourseAnnotation(coordinate: coordinate, title: "\(km)km", type: .kilometer)
            uiView.addAnnotation(kmPin)
        }
        
        // 코스 경로 폴리라인 추가
        let polyline = MKPolyline(coordinates: mapCoords, count: mapCoords.count)
        uiView.addOverlay(polyline)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 코스 어노테이션 유형
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
        
        // 커스텀 어노테이션 뷰
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let courseAnnotation = annotation as? CourseAnnotation {
                // 어노테이션 타입에 따라 다르게 처리
                switch courseAnnotation.type {
                case .start, .end:
                    let identifier = "CoursePointAnnotation"
                    var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    
                    if annotationView == nil {
                        annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                        annotationView?.canShowCallout = true
                    }
                    
                    annotationView?.annotation = annotation
                    
                    // 어노테이션 스타일 설정
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
                    
                    // 킬로미터 마커 스타일 설정
                    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
                    label.text = courseAnnotation.title
                    label.font = UIFont.boldSystemFont(ofSize: 10)
                    label.textAlignment = .center
                    label.textColor = UIColor { trait in
                        trait.userInterfaceStyle == .dark ? UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1) : UIColor(Color.rtPrimary)
                    }
                    label.backgroundColor = UIColor { trait in
                        trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.9) : UIColor.white
                    }
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
        
        // 폴리라인 스타일 정의
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKGradientPolylineRenderer(polyline: polyline)
                renderer.setColors([
                    UIColor(Color.rtPrimary),
                    UIColor(Color.rtSecondary)
                ], locations: [0, 1])
                renderer.lineCap = .round
                renderer.lineWidth = 4
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
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
    
    // 정보 행 컴포넌트
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
    
    // 누적 고도 상승 계산
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
    
    // 누적 고도 하강 계산
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
