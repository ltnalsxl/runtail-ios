//
//  ActivityTabView.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//  Updated with actual running data
//

import SwiftUI
import MapKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ActivityTabView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var selectedMonth = Date()
    @State private var calendarDates: [Date] = []
    @State private var activeDates: Set<String> = []
    @State private var monthlyStats: (distance: Double, time: Int) = (0, 0)
    @State private var isLoading = true
    
    // 달력 관련 상수
    private let daysOfWeek = ["일", "월", "화", "수", "목", "금", "토"]
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // 월 선택 달력
                    calendarView
                        .padding(.horizontal)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // 통계 요약
                    monthlyStatsView
                        .padding(.horizontal)
                    
                    // 러닝 히스토리 섹션
                    runningHistorySection
                        .padding(.top, 8)
                    
                    // 추가 통계 섹션 - 차트 등
                    if !viewModel.recentRuns.isEmpty {
                        additionalStatsSection
                            .padding(.top, 16)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // 하단 탭바 공간 확보를 위해 패딩 추가
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                loadCalendarDates()
                loadUserRunsForMonth()
            }
        }
    }
    
    // MARK: - 달력 뷰
    var calendarView: some View {
        VStack(spacing: 10) {
            // 월 선택 헤더
            HStack {
                Button(action: {
                    // 이전 달
                    if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                        selectedMonth = newDate
                        loadCalendarDates()
                        loadUserRunsForMonth()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.rtPrimary)
                }
                
                Spacer()
                
                Text(monthYearString(from: selectedMonth))
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                Button(action: {
                    // 다음 달
                    if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                        selectedMonth = newDate
                        loadCalendarDates()
                        loadUserRunsForMonth()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.rtPrimary)
                }
            }
            .padding(.vertical, 12)
            
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(day == "일" ? .red : .primary)
                }
            }
            .padding(.vertical, 8)
            
            // 달력 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDates, id: \.self) { date in
                    if calendar.isDate(date, equalTo: selectedMonth, toGranularity: .month) {
                        // 현재 달의 날짜
                        let dateString = dateToString(date)
                        let isActive = activeDates.contains(dateString)
                        
                        CalendarDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            isActive: isActive,
                            isSelected: false
                        )
                    } else {
                        // 다른 달의 날짜
                        Text("")
                            .frame(height: 36)
                    }
                }
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 월간 통계 뷰
    var monthlyStatsView: some View {
        HStack(spacing: 16) {
            // 거리 카드
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(.rtPrimary)
                    
                    Text("이번 달 거리")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 8)
                } else {
                    Text(Formatters.formatDistance(monthlyStats.distance))
                        .font(.system(size: 24, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // 시간 카드
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(viewModel.exploreCategories[1].color)
                    
                    Text("이번 달 시간")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 8)
                } else {
                    Text(Formatters.formatDuration(monthlyStats.time))
                        .font(.system(size: 24, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - 러닝 히스토리 섹션
    var runningHistorySection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Text("러닝 기록")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    viewModel.loadRecentRuns()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.rtPrimary)
                }
            }
            .padding(.horizontal)
            
            if isLoading {
                // 로딩 중
                ProgressView()
                    .padding(.vertical, 40)
            } else if viewModel.recentRuns.isEmpty {
                // 데이터 없음
                VStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("아직 러닝 기록이 없습니다")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("첫 러닝을 시작해보세요!")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            } else {
                // 최근 러닝 기록 표시
                ForEach(viewModel.recentRuns) { run in
                    RunningHistoryItem(run: run) {
                        // 코스 ID가 있는 경우 상세 화면으로 이동
                        if !run.courseId.isEmpty, let course = viewModel.getCourse(by: run.courseId) {
                            viewModel.selectedCourseId = run.courseId
                            viewModel.showCourseDetailView = true
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - 추가 통계 섹션
    var additionalStatsSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Text("월간 통계")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
            }
            
            // 통계 카드 (차트 등 추가 요소)
            VStack(spacing: 16) {
                // 예: 평균 페이스 그래프
                HStack {
                    Text("평균 페이스")
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    // 실제 평균 페이스 계산
                    let avgPace = calculateAveragePace()
                    let paceMinutes = Int(avgPace) / 60
                    let paceSeconds = Int(avgPace) % 60
                    
                    Text("\(paceMinutes)'\(String(format: "%02d", paceSeconds))\"")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.rtPrimary)
                }
                
                // 평균 거리 표시 (막대 그래프처럼 표현)
                VStack(spacing: 8) {
                    HStack {
                        Text("평균 거리:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        let avgDistance = calculateAverageDistance()
                        Text(Formatters.formatDistance(avgDistance))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    // 진행 바
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 배경 바
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            // 진행 바
                            let progress = min(calculateAverageDistance() / 10000, 1.0) // 10km 기준
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient.rtPrimaryGradient)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - 헬퍼 뷰
    
    // 달력 날짜 셀
    struct CalendarDayCell: View {
        let date: Date
        let isToday: Bool
        let isActive: Bool
        let isSelected: Bool
        
        private let calendar = Calendar.current
        
        var body: some View {
            ZStack {
                // 배경
                if isToday {
                    Circle()
                        .fill(Color.rtPrimary)
                        .frame(width: 36, height: 36)
                } else if isActive {
                    Circle()
                        .fill(Color.rtPrimary.opacity(0.2))
                        .frame(width: 36, height: 36)
                } else if isSelected {
                    Circle()
                        .stroke(Color.rtPrimary, lineWidth: 1)
                        .frame(width: 36, height: 36)
                }
                
                // 날짜 텍스트
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14))
                    .foregroundColor(
                        isToday ? .white :
                            (calendar.component(.weekday, from: date) == 1 ? .red : .primary)
                    )
            }
            .frame(height: 36)
        }
    }
    
    // 러닝 히스토리 아이템
    struct RunningHistoryItem: View {
        let run: Run
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // 날짜 표시
                    VStack(spacing: 4) {
                        Text(monthString(from: run.runAt))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text("\(Calendar.current.component(.day, from: run.runAt))")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text(yearString(from: run.runAt))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 50)
                    
                    // 구분선
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 50)
                    
                    // 러닝 정보
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getDayOfWeek(date: run.runAt))
                            .font(.system(size: 16, weight: .medium))
                        
                        // 거리와 시간
                        let distance = run.trail.count > 0 ? 150 * Double(run.trail.count) : 0
                        Text("\(Formatters.formatDistance(distance)) · \(Formatters.formatDuration(run.duration))")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // 페이스
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("페이스")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(run.paceStr)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.rtPrimary)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        // 요일 가져오기
        private func getDayOfWeek(date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // 요일 전체 이름
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter.string(from: date)
        }
        
        // 월 문자열
        private func monthString(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM월"
            return formatter.string(from: date)
        }
        
        // 년도 문자열
        private func yearString(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        }
    }
    
    // MARK: - 헬퍼 메서드
    
    // 월, 년 문자열 (2025년 5월)
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    // 날짜를 문자열로 변환 (yyyy-MM-dd)
    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 달력 날짜 로드
    private func loadCalendarDates() {
        // 선택된 달의 첫날
        let firstDayOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: selectedMonth)
        )!
        
        // 첫날의 요일
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // 달의 일수
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedMonth)!.count
        
        // 달력에 표시할 날짜 계산 (6주 표시)
        var dates: [Date] = []
        
        // 첫째 주 시작 전 이전 달 날짜
        for i in 0..<(firstWeekday - 1) {
            let daysBefore = Double(i - (firstWeekday - 1))
            if let date = calendar.date(byAdding: .day, value: Int(daysBefore), to: firstDayOfMonth) {
                dates.append(date)
            }
        }
        
        // 현재 달 날짜
        for i in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: i - 1, to: firstDayOfMonth) {
                dates.append(date)
            }
        }
        
        // 남은 주 표시를 위한 다음 달 날짜
        let remainingCells = 42 - dates.count // 6주 * 7일 = 42
        if remainingCells > 0 {
            let lastDate = dates.last!
            for i in 1...remainingCells {
                if let date = calendar.date(byAdding: .day, value: i, to: lastDate) {
                    dates.append(date)
                }
            }
        }
        
        calendarDates = dates
    }
    
    // 사용자의 월간 러닝 기록 로드
    private func loadUserRunsForMonth() {
        isLoading = true
        
        // 선택한 달의 시작일과 종료일
        guard let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: selectedMonth)
        ) else {
            isLoading = false
            return
        }
        
        guard let endOfMonth = calendar.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: startOfMonth
        ) else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // 현재 로그인한 사용자의 ID
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        // Firestore에서 선택한 달의 러닝 기록 쿼리
        db.collection("runs")
            .whereField("userId", isEqualTo: userId)
            .whereField("runAt", isGreaterThanOrEqualTo: startOfMonth)
            .whereField("runAt", isLessThanOrEqualTo: endOfMonth)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                }
                
                if let error = error {
                    print("러닝 기록 로드 오류: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("러닝 기록이 없습니다")
                    // 통계 리셋
                    self.monthlyStats = (0, 0)
                    self.activeDates = []
                    return
                }
                
                print("월간 러닝 기록 로드: \(documents.count)개")
                
                // 통계 계산 변수
                var totalDistance: Double = 0
                var totalTime: Int = 0
                var activeDatesSet: Set<String> = []
                
                // 각 기록 처리
                for document in documents {
                    let data = document.data()
                    
                    // 날짜 정보
                    if let timestamp = data["runAt"] as? Timestamp {
                        let date = timestamp.dateValue()
                        let dateString = self.dateToString(date)
                        activeDatesSet.insert(dateString)
                    }
                    
                    // 거리 누적
                    if let distance = data["distance"] as? Double {
                        totalDistance += distance
                    }
                    
                    // 시간 누적
                    if let duration = data["duration"] as? Int {
                        totalTime += duration
                    }
                }
                
                // 상태 업데이트
                DispatchQueue.main.async {
                    self.monthlyStats = (totalDistance, totalTime)
                    self.activeDates = activeDatesSet
                }
            }
    }
    
    // 평균 페이스 계산
    private func calculateAveragePace() -> Double {
        let runs = viewModel.recentRuns
        
        // 유효한 페이스를 가진 러닝만 필터링
        let validRuns = runs.filter { $0.pace > 0 }
        
        if validRuns.isEmpty {
            return 6 * 60 // 기본값: 6분/km
        }
        
        // 페이스의 합계 계산
        let totalPace = validRuns.reduce(0) { $0 + Double($1.pace) }
        
        // 평균 반환
        return totalPace / Double(validRuns.count)
    }
    
    // 평균 거리 계산
    private func calculateAverageDistance() -> Double {
        let runs = viewModel.recentRuns
        
        if runs.isEmpty {
            return 0
        }
        
        // 각 러닝 거리 합계 계산
        let totalDistance = runs.reduce(0.0) { total, run in
            // 실제 앱에서는 저장된 distance 값을 사용하는 것이 좋습니다
            // 여기서는 예시로 trail 길이로 추정
            let distance = run.trail.count > 0 ? 150 * Double(run.trail.count) : 0
            return total + distance
        }
        
        // 평균 반환
        return totalDistance / Double(runs.count)
    }
}
