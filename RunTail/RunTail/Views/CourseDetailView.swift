//
//  CourseDetailView.swift
//  RunTail
//
//  Created by 이수민 on 5/8/25.
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
    
    // 가상 뷰모델 (실제 구현 시 의존성 주입으로 제공)
    @EnvironmentObject var viewModel: MapViewModel
    @EnvironmentObject var locationService: LocationService
    @Environment(\.checkBeforeStartRunning) var checkBeforeStartRunning
    
    // MARK: - 바디
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 지도 영역
                mapSection
                
                // 코스 정보
                ScrollView {
                    // 코스 제목 및 정보
                    courseHeaderSection
                    
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
                .padding(.bottom, 20)
            }
            
            // 일정 부분 스크롤 시 상단에 고정되는 헤더
            VStack {
                // 상단 헤더바 (반투명 배경)
                fixedHeaderBar
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.top)
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
                averagePace: getUserAveragePace(viewModel: viewModel),
                onDismiss: { showSummarySheet = false },
                onStartRunning: startRunningThisCourse
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - 지도 섹션
    var mapSection: some View {
        ZStack(alignment: .top) {
            // 코스 지도
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map {
                    // 시작점 표시
                    if let firstCoord = course.coordinates.first {
                        Annotation("시작", coordinate: CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                                .padding(8)
                                .background(Circle().fill(Color.white))
                                .shadow(radius: 2)
                        }
                    }
                    
                    // 종료점 표시
                    if let lastCoord = course.coordinates.last, course.coordinates.count > 1 {
                        Annotation("종료", coordinate: CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
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
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 89/255, green: 86/255, blue: 214/255),
                                Color(red: 0/255, green: 122/255, blue: 255/255)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 4
                    )
                    
                    // 1km 마다 거리 표시
                    ForEach(getKilometerMarkers(), id: \.0) { index, coordinate in
                        Annotation("\(index)km", coordinate: coordinate) {
                            Text("\(index)km")
                                .font(.system(size: 12, weight: .bold))
                                .padding(6)
                                .background(Circle().fill(Color.white))
                                .shadow(radius: 1)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .frame(height: 300)
            } else {
                CourseDetailMapView(
                    region: $region,
                    coordinates: course.coordinates,
                    kilometerMarkers: getKilometerMarkers()
                )
                .frame(height: 300)
            }
            #else
            CourseDetailMapView(
                region: $region,
                coordinates: course.coordinates,
                kilometerMarkers: getKilometerMarkers()
            )
            .frame(height: 300)
            #endif
        }
    }
    
    // MARK: - 상단 고정 헤더 바
    var fixedHeaderBar: some View {
        HStack {
            // 뒤로가기 버튼
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .foregroundColor(.black)
            
            Spacer()
            
            // 공유 버튼
            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
    
    // MARK: - 코스 헤더 섹션
    var courseHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 코스 제목
                Text(course.title)
                    .font(.system(size: 24, weight: .bold))
                
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
            HStack(spacing: 20) {
                Label(Formatters.formatDate(course.createdAt), systemImage: "calendar")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                
                if course.isPublic {
                    Label("공개", systemImage: "globe")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                } else {
                    Label("비공개", systemImage: "lock")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - 통계 카드 섹션
    var statisticsSection: some View {
        HStack(spacing: 16) {
            // 거리 카드
            StatisticCard(
                title: "총 거리",
                value: Formatters.formatDistance(course.distance),
                icon: "ruler",
                color: Color(red: 89/255, green: 86/255, blue: 214/255)
            )
            
            // 시간 카드 (예상 시간 - 사용자 평균 페이스 기반)
            let estimatedTime = Int(course.distance / 1000 * getUserAveragePace(viewModel: viewModel))
            StatisticCard(
                title: "예상 시간",
                value: Formatters.formatDuration(estimatedTime),
                icon: "clock",
                color: Color(red: 45/255, green: 104/255, blue: 235/255)
            )
            
            // 고도 차이 카드
            let elevationGain = calculateElevationGain()
            StatisticCard(
                title: "고도 변화",
                value: "\(Int(elevationGain))m",
                icon: "mountain.2",
                color: Color(red: 76/255, green: 175/255, blue: 80/255)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - 고도 차트 섹션
    var elevationChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("고도 프로필")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    showElevationChart.toggle()
                }) {
                    Text(showElevationChart ? "접기" : "자세히")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 89/255, green: 86/255, blue: 214/255))
                }
            }
            
            if showElevationChart {
                ElevationChartView(elevationData: elevationData, distance: course.distance)
                    .frame(height: 160)
                    .padding(.vertical, 8)
            } else {
                ElevationMiniChartView(elevationData: elevationData)
                    .frame(height: 60)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .background(Color.white)
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
            
            // 코스 요약 버튼
            Button(action: {
                showSummarySheet = true
            }) {
                HStack {
                    Image(systemName: "chart.bar")
                    Text("코스 요약 보기")
                }
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(16)
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
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .foregroundColor(.red)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - 코스 상세 정보 섹션
    var courseDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("코스 정보")
                .font(.system(size: 18, weight: .semibold))
            
            // 코스 좌표 수
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundColor(Color(red: 89/255, green: 86/255, blue: 214/255))
                    .frame(width: 24, height: 24)
                
                Text("트래킹 포인트")
                    .font(.system(size: 16))
                
                Spacer()
                
                Text("\(course.coordinates.count)개")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // 누적 고도 상승
            HStack {
                Image(systemName: "arrow.up.forward")
                    .foregroundColor(Color(red: 76/255, green: 175/255, blue: 80/255))
                    .frame(width: 24, height: 24)
                
                Text("고도 상승")
                    .font(.system(size: 16))
                
                Spacer()
                
                Text("\(Int(calculateElevationGain()))m")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // 누적 고도 하강
            HStack {
                Image(systemName: "arrow.down.forward")
                    .foregroundColor(Color(red: 244/255, green: 67/255, blue: 54/255))
                    .frame(width: 24, height: 24)
                
                Text("고도 하강")
                    .font(.system(size: 16))
                
                Spacer()
                
                Text("\(Int(calculateElevationLoss()))m")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            
            // 추가 정보가 있다면 여기에 추가
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - 헬퍼 메서드
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
                // 예시: 임의의 고도 데이터 생성 (실제로는 좌표에서 고도 정보 추출)
                // 실제 앱에서는 CLLocation의 altitude 속성이나 외부 API를 사용해야 합니다
                
                // 현재는 간단한 예시 데이터를 생성합니다
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
                            viewModel.startRecording(followingCourse: course)
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
                            // 성공 시 코스 목록 갱신 (실제 구현에서는 코스 객체 자체를 업데이트)
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
            
            // 사용자의 평균 페이스 계산
            func getUserAveragePace(viewModel: MapViewModel) -> Double {
                // 기본 페이스 (초/km)
                let defaultPace: Double = 6 * 60 // 6분/km
                
                // 최근 러닝 기록이 없으면 기본값 사용
                guard !viewModel.recentRuns.isEmpty else {
                    return defaultPace
                }
                
                // 유효한 페이스가 있는 러닝만 필터링
                let validRuns = viewModel.recentRuns.filter { $0.pace > 0 }
                
                if validRuns.isEmpty {
                    return defaultPace
                }
                
                // 최근 3개까지의 유효한 러닝 기록으로 평균 페이스 계산
                let recentValidRuns = Array(validRuns.prefix(3))
                let totalPace = recentValidRuns.reduce(0) { $0 + Double($1.pace) }
                
                return totalPace / Double(recentValidRuns.count)
            }
        }

        // MARK: - 통계 카드 컴포넌트
        struct StatisticCard: View {
            let title: String
            let value: String
            let icon: String
            let color: Color
            
            var body: some View {
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
        }

        // MARK: - 고도 차트 뷰
        struct ElevationChartView: View {
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
                        
                        // 고도 차트 영역
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
                                    Color(red: 89/255, green: 86/255, blue: 214/255).opacity(0.8),
                                    Color(red: 89/255, green: 86/255, blue: 214/255).opacity(0.1)
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
                        .stroke(Color(red: 89/255, green: 86/255, blue: 214/255), lineWidth: 2)
                        
                        // 고도 레이블
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                if let maxElevation = elevationData.max() {
                                    Text("\(Int(maxElevation))m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                        .padding(.bottom, geometry.size.height - 15)
                                }
                                
                                if let minElevation = elevationData.min() {
                                    Text("\(Int(minElevation))m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            // 거리 레이블
                            VStack(alignment: .trailing, spacing: 0) {
                                Spacer()
                                Text("\(Int(distance / 1000))km")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
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

        // MARK: - 고도 미니 차트 뷰
        struct ElevationMiniChartView: View {
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
                    .stroke(Color(red: 89/255, green: 86/255, blue: 214/255), lineWidth: 2)
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                .cornerRadius(12)
            }
        }

        // MARK: - iOS 16 이하에서 코스를 표시하기 위한 지도 뷰
        struct CourseDetailMapView: UIViewRepresentable {
            @Binding var region: MKCoordinateRegion
            var coordinates: [Coordinate]
            var kilometerMarkers: [(Int, CLLocationCoordinate2D)]
            
            func makeUIView(context: Context) -> MKMapView {
                let mapView = MKMapView()
                mapView.delegate = context.coordinator
                mapView.setRegion(region, animated: true)
                return mapView
            }
            
            func updateUIView(_ uiView: MKMapView, context: Context) {
                uiView.setRegion(region, animated: true)
                
                // 기존 오버레이와 어노테이션 제거
                uiView.removeOverlays(uiView.overlays)
                uiView.removeAnnotations(uiView.annotations)
                
                // 코스 경로 추가
                if !coordinates.isEmpty {
                    let mapCoords = coordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                    let polyline = MKPolyline(coordinates: mapCoords, count: mapCoords.count)
                    uiView.addOverlay(polyline)
                    
                    // 시작점과 종료점 어노테이션 추가
                    if let firstCoord = coordinates.first {
                        let startPin = MKPointAnnotation()
                        startPin.coordinate = CLLocationCoordinate2D(latitude: firstCoord.lat, longitude: firstCoord.lng)
                        startPin.title = "시작"
                        uiView.addAnnotation(startPin)
                    }
                    
                    if let lastCoord = coordinates.last, coordinates.count > 1 {
                        let endPin = MKPointAnnotation()
                        endPin.coordinate = CLLocationCoordinate2D(latitude: lastCoord.lat, longitude: lastCoord.lng)
                        endPin.title = "종료"
                        uiView.addAnnotation(endPin)
                    }
                    
                    // 킬로미터 마커 추가
                    for (km, coordinate) in kilometerMarkers {
                        let kmPin = MKPointAnnotation()
                        kmPin.coordinate = coordinate
                        kmPin.title = "\(km)km"
                        uiView.addAnnotation(kmPin)
                    }
                }
            }
            
            func makeCoordinator() -> Coordinator {
                Coordinator(self)
            }
            
            class Coordinator: NSObject, MKMapViewDelegate {
                var parent: CourseDetailMapView
                
                init(_ parent: CourseDetailMapView) {
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
                            HStack {
                                Text("이름")
                                Spacer()
                                Text(course.title)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text("거리")
                                Spacer()
                                Text(Formatters.formatDistance(course.distance))
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text("예상 시간")
                                Spacer()
                                Text(Formatters.formatDuration(Int(course.distance / 1000 * averagePace)))
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text("생성일")
                                Spacer()
                                Text(Formatters.formatDate(course.createdAt))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Section(header: Text("고도 정보")) {
                            if !elevationData.isEmpty {
                                HStack {
                                    Text("고도 상승")
                                    Spacer()
                                    Text("\(Int(calculateElevationGain(elevationData: elevationData)))m")
                                        .foregroundColor(.gray)
                                }
                                
                                HStack {
                                    Text("고도 하강")
                                    Spacer()
                                    Text("\(Int(calculateElevationLoss(elevationData: elevationData)))m")
                                        .foregroundColor(.gray)
                                }
                                
                                HStack {
                                    Text("최고 고도")
                                    Spacer()
                                    Text("\(Int(elevationData.max() ?? 0))m")
                                        .foregroundColor(.gray)
                                }
                                
                                HStack {
                                    Text("최저 고도")
                                    Spacer()
                                    Text("\(Int(elevationData.min() ?? 0))m")
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Text("고도 정보가 없습니다")
                                    .foregroundColor(.gray)
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
                            .listRowBackground(Color(red: 89/255, green: 86/255, blue: 214/255))
                        }
                    }
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

        struct CourseDetailView_Previews: PreviewProvider {
            static var previews: some View {
                let sampleCoordinates = [
                    Coordinate(lat: 37.5665, lng: 126.9780, timestamp: Date().timeIntervalSince1970 - 1000),
                    Coordinate(lat: 37.5668, lng: 126.9785, timestamp: Date().timeIntervalSince1970 - 900),
                    Coordinate(lat: 37.5675, lng: 126.9790, timestamp: Date().timeIntervalSince1970 - 800),
                    Coordinate(lat: 37.5680, lng: 126.9795, timestamp: Date().timeIntervalSince1970 - 700),
                    Coordinate(lat: 37.5685, lng: 126.9800, timestamp: Date().timeIntervalSince1970 - 600)
                ]
                
                let sampleCourse = Course(
                    id: "sample-id",
                    title: "서울숲 러닝 코스",
                    distance: 5200,
                    coordinates: sampleCoordinates,
                    createdAt: Date(),
                    createdBy: "user-id",
                    isPublic: true
                )
                
                return CourseDetailView(course: sampleCourse)
                    .environmentObject(MapViewModel())
                    .environmentObject(LocationService())
            }
        }
