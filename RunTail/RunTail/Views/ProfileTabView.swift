//
//  ProfileTabView.swift
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


struct ProfileTabView: View {
    @ObservedObject var viewModel: MapViewModel
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // 프로필 헤더
                    VStack(spacing: 16) {
                        // 배경 이미지
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(colorScheme == .dark ? viewModel.darkGradient : viewModel.themeGradient)
                                .frame(height: 150)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("프로필")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("러닝 활동 및 설정")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.leading)
                                .padding(.bottom)
                                
                                Spacer()
                            }
                        }
                        
                        // 프로필 정보
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.themeColor.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(viewModel.themeColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.userEmail)
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("RunTail 러너")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                // 미니 통계
                                HStack(spacing: 12) {
                                    Label("\(Formatters.formatDistance(viewModel.totalDistance))", systemImage: "figure.run")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(viewModel.themeColor)
                                    
                                    Text("•")
                                        .foregroundColor(.gray)
                                    
                                    Text("이번 주 \(Formatters.formatDistance(viewModel.weeklyDistance))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 4)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // 설정 섹션 - Material Design 스타일
                    VStack(spacing: 0) {
                        // 섹션 헤더
                        HStack {
                            Text("설정")
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // 설정 옵션들
                        Group {
                            Button(action: {
                                // 프로필 설정 액션
                            }) {
                                settingRow(icon: "person.fill", title: "프로필 수정", iconColor: viewModel.themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 알림 설정 액션
                            }) {
                                settingRow(icon: "bell.fill", title: "알림 설정", iconColor: viewModel.themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 개인정보 설정 액션
                            }) {
                                settingRow(icon: "lock.fill", title: "개인정보 설정", iconColor: viewModel.themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // 로그아웃 버튼
                            Button(action: {
                                viewModel.showLogoutAlert = true
                            }) {
                                settingRow(icon: "arrow.right.square", title: "로그아웃", iconColor: .red)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // 앱 정보 섹션
                    VStack(spacing: 0) {
                        // 섹션 헤더
                        HStack {
                            Text("앱 정보")
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // 앱 정보 옵션들
                        Group {
                            Button(action: {
                                // 앱 버전 정보
                            }) {
                                settingRow(icon: "info.circle.fill", title: "버전 정보", subtitle: "1.0.0", iconColor: viewModel.themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 이용약관
                            }) {
                                settingRow(icon: "doc.text.fill", title: "이용약관", iconColor: viewModel.themeColor)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            Button(action: {
                                // 개인정보 처리방침
                            }) {
                                settingRow(icon: "hand.raised.fill", title: "개인정보 처리방침", iconColor: viewModel.themeColor)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
                .padding(.bottom, 80)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // 설정 행 헬퍼 함수
    func settingRow(icon: String, title: String, subtitle: String? = nil, iconColor: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(title == "로그아웃" ? .red : .primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}
