//
//  ActivityTabView.swift
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


struct ActivityTabView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {  // 여기에 문제가 있을 수 있음
        VStack(spacing: 0) {
            // 상단 상태 바
            ZStack {
                viewModel.themeGradient
                Text("활동")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(height: 44)
            
            // 달력 뷰 (예시)
            VStack(spacing: 10) {
                // 월 선택
                HStack {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(viewModel.themeColor)
                    }
                    
                    Spacer()
                    
                    Text("2025년 5월")
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(viewModel.themeColor)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // 요일 헤더
                HStack(spacing: 0) {
                    ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(day == "일" ? .red : .primary)
                    }
                }
                .padding(.vertical, 8)
                
                // 날짜 그리드 (간단한 예시)
                VStack(spacing: 8) {
                    ForEach(0..<5) { week in
                        HStack(spacing: 0) {
                            ForEach(1...7, id: \.self) { day in
                                let date = week * 7 + day
                                if date <= 31 {
                                    ZStack {
                                        Circle()
                                            .fill(date == 15 ? viewModel.themeColor : Color.clear)
                                            .frame(width: 36, height: 36)
                                        
                                        Text("\(date)")
                                            .font(.system(size: 14))
                                            .foregroundColor(date == 15 ? .white : (day == 1 ? .red : .primary))
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Text("")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom)
            
            // 통계 요약
            VStack(spacing: 16) {
                Text("이번 달 통계")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // 통계 카드들
                HStack(spacing: 12) {
                    // 거리 카드
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(viewModel.themeColor)
                            
                            Text("총 거리")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Text("42.5km")
                            .font(.system(size: 24, weight: .bold))
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
                            
                            Text("총 시간")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Text("5시간 12분")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // 러닝 히스토리 타이틀
                Text("최근 러닝")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 예시 러닝 기록들
                ForEach(0..<3) { index in
                    HStack(spacing: 16) {
                        // 날짜 표시
                        VStack(spacing: 4) {
                            Text("5월")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Text("\(10 + index)")
                                .font(.system(size: 18, weight: .bold))
                            
                            Text("2025")
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
                            Text("저녁 러닝")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("5.2km · 31분 12초")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // 페이스
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("페이스")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Text("6'02\"")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(viewModel.themeColor)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 80)
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    } // 이 중괄호가 누락되었을 수 있음
}
