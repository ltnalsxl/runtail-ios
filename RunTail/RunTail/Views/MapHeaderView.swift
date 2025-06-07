import SwiftUI

// Extracted header components from MapView

struct HomeHeader: View {
    @ObservedObject var locationService: LocationService

    var body: some View {
        ZStack {
            LinearGradient.rtPrimaryGradient
                .ignoresSafeArea(.all)

            VStack {
                Spacer()
                    .frame(height: getSafeAreaTop())

                HStack {
                    Text("RunTail")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // GPS 상태 표시
                    HStack(spacing: 4) {
                        Text("GPS")
                            .foregroundColor(.white)
                            .font(.system(size: 10))

                        Circle()
                            .fill(gpsSignalColor)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private var gpsSignalColor: Color {
        switch locationService.gpsSignalStrength {
        case 0:
            return .rtError
        case 1:
            return .rtWarning
        case 2, 3, 4:
            return .green
        default:
            return .yellow
        }
    }
}

struct ExploreHeader: View {
    var body: some View {
        ZStack {
            LinearGradient.rtPrimaryGradient
                .ignoresSafeArea(.all)

            VStack {
                Spacer()
                    .frame(height: getSafeAreaTop())

                HStack {
                    Text("RunTail")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}

struct ActivityHeader: View {
    var body: some View {
        ZStack {
            LinearGradient.rtPrimaryGradient
                .ignoresSafeArea(.all)

            VStack {
                Spacer()
                    .frame(height: getSafeAreaTop())

                HStack {
                    Text("RunTail")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}

struct ProfileHeader: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        ZStack {
            LinearGradient.rtPrimaryGradient
                .ignoresSafeArea(.all)

            VStack {
                Spacer()
                    .frame(height: getSafeAreaTop())

                HStack {
                    Text("RunTail")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // 로그아웃 버튼
                    Button(action: {
                        viewModel.showLogoutAlert = true
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}

