//
//  HomeTabView.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

import SwiftUI
import MapKit
import Firebase  // 이 부분이 누락됨
import FirebaseAuth  // 이 부분도 추가
import FirebaseFirestore
import Combine

struct HomeTabView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var locationService: LocationService
    
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
    }
    
    // 상단 상태 바
    var statusBar: some View {
        HStack {
            Text("RunTail")
                .font(.system(size: 18, weight: .bold))
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("GPS")
                    .font(.system(size: 12, weight: .medium))
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(viewModel.themeGradient) // 그라데이션 적용
        .foregroundColor(.white)
    }
    
    // 지도 섹션
    var mapSection: some View {
        ZStack(alignment: .bottom) {
            // 지도 (iOS 17에서 변경된 방식)
            #if swift(>=5.9) // iOS 17 이상
            if #available(iOS 17.0, *) {
                Map(initialPosition: MapCameraPosition.region(locationService.region)) {
                    UserAnnotation()
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            } else {
                Map(coordinateRegion: $locationService.region, showsUserLocation: true)
                    .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            #else
            Map(coordinateRegion: $locationService.region, showsUserLocation: true)
                .frame(height: UIScreen.main.bounds.height * 0.5)
            #endif
            
            // 검색 바 - 스타일 개선
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .top)
            
            // 지도 컨트롤 - 스타일 개선
            mapControls
            
            // 달리기 시작 버튼 - 스타일 개선
            startRunningButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }
    
    // 검색 바
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
    
    // 지도 컨트롤
    var mapControls: some View {
        VStack(spacing: 8) {
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
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    // 달리기 시작 버튼
    var startRunningButton: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring()) {
                    viewModel.isStartRunExpanded.toggle()
                }
            }) {
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
                VStack(spacing: 0) {
                    // 자유 달리기 옵션
                    Button(action: {
                        // 자유 달리기 시작 로직 구현
                        print("자유 달리기 시작")
                        withAnimation(.spring()) {
                            viewModel.isStartRunExpanded = false
                        }
                    }) {
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
                        }
                    }) {
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
    
    // 통계 바
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
        
        // 최근 활동 섹션
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
        
        // 달리기 기록 카드
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
                        
                        Text("\(Formatters.calculateDistance(coordinates: run.trail)) · \(Formatters.formatDuration(run.duration))")
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
        
        // 탐색 섹션
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
        
        // 탐색 카테고리 카드
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
    }
