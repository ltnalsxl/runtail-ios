//
//  ExploreTabView.swift
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


struct ExploreTabView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 상태 바
            ZStack {
                viewModel.themeGradient
                Text("탐색")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(height: 44)
            
            // 내용 (예시)
            ScrollView {
                VStack(spacing: 16) {
                    // 검색 바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("코스나 지역 검색", text: .constant(""))
                            .font(.system(size: 16))
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(28)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 카테고리 제목
                    HStack {
                        Text("추천 코스")
                            .font(.system(size: 18, weight: .bold))
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 추천 코스 목록 (예시)
                    ForEach(0..<5) { index in
                        HStack(spacing: 16) {
                            // 코스 이미지
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(viewModel.themeColor.opacity(0.1))
                                
                                Image(systemName: "map.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(viewModel.themeColor)
                            }
                            .frame(width: 80, height: 80)
                            
                            // 코스 정보
                            VStack(alignment: .leading, spacing: 4) {
                                Text("인기 코스 \(index + 1)")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("5.3km · 약 30분")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                // 태그
                                HStack {
                                    Text("공원")
                                        .font(.system(size: 12))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(viewModel.themeColor.opacity(0.1))
                                        .foregroundColor(viewModel.themeColor)
                                        .cornerRadius(12)
                                    
                                    Text("인기")
                                        .font(.system(size: 12))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .foregroundColor(Color.orange)
                                        .cornerRadius(12)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 80)
            }
        }
    }
}
