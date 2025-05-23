//
//  CourseFollowingStatusView.swift
//  RunTail
//
//  Created by 이수민 on 5/10/25.
//

import SwiftUI

struct CourseFollowingStatusView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        if viewModel.isFollowingCourse, let course = viewModel.currentFollowingCourse {
            VStack(spacing: 12) {
                // 코스 정보 헤더
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("코스 따라 달리기")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // 진행률 표시
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(viewModel.courseProgress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("완료")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // 진행률 바
                ProgressView(value: viewModel.courseProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(4)
                
                // 상태 정보
                HStack(spacing: 16) {
                    // 남은 거리
                    VStack(alignment: .leading, spacing: 2) {
                        Text("남은 거리")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(Formatters.formatDistance(viewModel.remainingDistance))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // 코스 상태
                    HStack(spacing: 6) {
                        if viewModel.isOffCourse {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("코스 이탈")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("경로 내")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // 네비게이션 안내
                let instruction = viewModel.getNavigationInstruction()
                if !instruction.isEmpty {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(instruction)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        viewModel.isOffCourse ?
                        LinearGradient(colors: [Color.orange, Color.red.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient.rtPrimaryGradient
                    )
                    .opacity(0.95)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
        }
    }
}
