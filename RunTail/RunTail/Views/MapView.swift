//
//  MapView.swift
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


struct MapView: View {
    // 뷰모델
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationService = LocationService()
    
    // 상태
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // 선택된 탭에 따라 다른 콘텐츠 표시
                Group {
                    if viewModel.selectedTab == 0 {
                        homeTabView
                    } else if viewModel.selectedTab == 1 {
                        exploreTabView
                    } else if viewModel.selectedTab == 2 {
                        activityTabView
                    } else if viewModel.selectedTab == 3 {
                        profileTabView
                    }
                }
                
                // 하단 탭 바
                VStack {
                    Spacer()
                    customTabBar
                }
                
                // 로그인 화면으로 돌아가기 위한 NavigationLink
                NavigationLink(destination: LoginView().navigationBarHidden(true),
                              isActive: $viewModel.isLoggedOut) {
                    EmptyView()
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarHidden(true)
            // 로그아웃 확인 알림
            .alert(isPresented: $viewModel.showLogoutAlert) {
                Alert(
                    title: Text("로그아웃"),
                    message: Text("정말 로그아웃 하시겠습니까?"),
                    primaryButton: .destructive(Text("로그아웃")) {
                        viewModel.logout()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
        }
    }
    
    // 커스텀 탭 바
    var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    withAnimation(.spring()) {
                        viewModel.selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.tabIcon(index))
                            .font(.system(size: 22))
                        
                        Text(viewModel.tabTitle(index))
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.selectedTab == index ?
                            viewModel.themeColor.opacity(0.1) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .foregroundColor(
                        viewModel.selectedTab == index ?
                            viewModel.themeColor :
                            Color.gray
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(Color.white)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
    }
    
    // 홈 탭 뷰
    var homeTabView: some View {
        HomeTabView(viewModel: viewModel, locationService: locationService)
    }
    
    // 탐색 탭 뷰
    var exploreTabView: some View {
        ExploreTabView(viewModel: viewModel)
    }
    
    // 활동 탭 뷰
    var activityTabView: some View {
        ActivityTabView(viewModel: viewModel)
    }
    
    // 프로필 탭 뷰
    var profileTabView: some View {
        ProfileTabView(viewModel: viewModel, colorScheme: colorScheme)
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
