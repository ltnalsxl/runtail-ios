//
//  ThemeManager.swift
//  RunTail
//
//  Created by 이수민 on 5/10/25.
//

import SwiftUI

// MARK: - 색상 시스템
extension Color {
    // 앱 테마 색상
    static let rtPrimary = Color(red: 89/255, green: 86/255, blue: 214/255) // #5956D6 (기존 퍼플)
    static let rtSecondary = Color(red: 45/255, green: 104/255, blue: 235/255) // #2D68EB (블루)
    static let rtAccent = Color(red: 0/255, green: 122/255, blue: 255/255) // #007AFF (라이트 블루)
    
    // 상태 색상
    static let rtSuccess = Color(red: 76/255, green: 217/255, blue: 100/255) // #4CD964 (그린)
    static let rtWarning = Color(red: 255/255, green: 184/255, blue: 0/255) // #FFB800 (옐로우)
    static let rtError = Color(red: 255/255, green: 59/255, blue: 48/255) // #FF3B30 (레드)
    
    // 배경 색상
    static let rtBackground = Color(red: 249/255, green: 249/255, blue: 254/255) // #F9F9FE
    static let rtCard = Color.white
    static let rtBackgroundDark = Color(red: 28/255, green: 28/255, blue: 35/255) // #1C1C23
    static let rtCardDark = Color(red: 38/255, green: 38/255, blue: 45/255) // #26262D
}

// MARK: - 그라데이션
extension LinearGradient {
    // 메인 그라데이션
    static let rtPrimaryGradient = LinearGradient(
        gradient: Gradient(colors: [Color.rtPrimary, Color.rtSecondary]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // 다크 그라데이션
    static let rtDarkGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 74/255, green: 55/255, blue: 126/255), // #4A377E (다크 퍼플)
            Color(red: 26/255, green: 86/255, blue: 155/255)  // #1A569B (다크 블루)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // 경고 그라데이션 (일시정지 상태에 사용)
    static let rtWarningGradient = LinearGradient(
        gradient: Gradient(colors: [Color.rtWarning, Color.rtWarning.opacity(0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // 에러 그라데이션 (중지 버튼 등에 사용)
    static let rtErrorGradient = LinearGradient(
        gradient: Gradient(colors: [Color.rtError, Color.rtError.opacity(0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - 텍스트 스타일
extension View {
    // 제목 스타일
    func rtHeading1() -> some View {
        self.font(.system(size: 28, weight: .bold))
    }
    
    func rtHeading2() -> some View {
        self.font(.system(size: 22, weight: .bold))
    }
    
    func rtHeading3() -> some View {
        self.font(.system(size: 18, weight: .semibold))
    }
    
    // 본문 스타일
    func rtBodyLarge() -> some View {
        self.font(.system(size: 16, weight: .medium))
    }
    
    func rtBody() -> some View {
        self.font(.system(size: 14, weight: .regular))
    }
    
    func rtBodySmall() -> some View {
        self.font(.system(size: 12, weight: .regular))
    }
    
    // 캡션 스타일
    func rtCaption() -> some View {
        self.font(.system(size: 10, weight: .regular))
    }
}

// MARK: - 버튼 스타일
struct RTButtonStyle: ButtonStyle {
    var foregroundColor: Color = .white
    var backgroundColor: Color = .rtPrimary
    var pressedOpacity: Double = 0.9
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .background(backgroundColor.opacity(configuration.isPressed ? pressedOpacity : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct RTPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(
                LinearGradient.rtPrimaryGradient
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .foregroundColor(.white)
            .cornerRadius(28)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: Color.rtPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 공통 UI 컴포넌트
struct RTCardView<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(Color.rtCard)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}
