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
            VStack(spacing: 8) {
                // 코스 정보
                HStack {
                    Text(course.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.courseProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // 진행률 바
                ProgressView(value: viewModel.courseProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .background(Color.white.opacity(0.3))
                
                // 상태 정보
                HStack {
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
                    
                    // 코스 이탈 상태
                    if viewModel.isOffCourse {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("코스 이탈")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    } else {
                        HStack(spacing: 4) {
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
                    Text(instruction)
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewModel.isOffCourse ? Color.orange : Color.rtPrimary)
                    .opacity(0.9)
            )
            .padding(.horizontal)
        }
    }
}
