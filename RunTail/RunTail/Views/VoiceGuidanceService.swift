//
//  VoiceGuidanceService.swift
//  RunTail
//
//  Created by 이수민 on 5/10/25.
//

import Foundation
import AVFoundation
import UIKit

class VoiceGuidanceService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var isEnabled = true
    
    // 마지막 안내 시간 추적 (중복 방지)
    private var lastAnnouncementTime: Date = Date()
    private let minimumInterval: TimeInterval = 5.0 // 최소 5초 간격
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("오디오 세션 설정 오류: \(error)")
        }
    }
    
    // MARK: - 공개 메서드
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // 기본 음성 안내
    func announce(_ message: String, priority: AnnouncementPriority = .normal) {
        guard isEnabled else { return }
        
        // 우선순위가 높은 경우나 충분한 시간이 지난 경우에만 실행
        let now = Date()
        if priority == .high || now.timeIntervalSince(lastAnnouncementTime) >= minimumInterval {
            speak(message)
            lastAnnouncementTime = now
        }
    }
    
    // 러닝 시작 안내
    func announceRunStart() {
        announce("러닝을 시작합니다. 화이팅!", priority: .high)
        provideStartHaptic()
    }
    
    // 코스 따라달리기 시작 안내
    func announceCourseFollowStart(courseName: String) {
        announce("\(courseName) 코스 따라달리기를 시작합니다.", priority: .high)
        provideStartHaptic()
    }
    
    // 거리 알림 (1km마다)
    func announceDistance(_ distance: Double, elapsedTime: TimeInterval) {
        let km = Int(distance / 1000)
        let minutes = Int(elapsedTime / 60)
        let seconds = Int(elapsedTime.truncatingRemainder(dividingBy: 60))
        
        let message = "\(km)킬로미터 완주. 경과 시간 \(minutes)분 \(seconds)초"
        announce(message, priority: .high)
        provideDistanceHaptic()
    }
    
    // 코스 이탈 경고
    func announceOffCourse() {
        announce("코스에서 벗어났습니다. 경로로 돌아가세요.", priority: .high)
        provideWarningHaptic()
    }
    
    // 코스 복귀 안내
    func announceBackOnCourse() {
        announce("코스로 돌아왔습니다. 잘하고 있어요!", priority: .high)
        provideSuccessHaptic()
    }
    
    // 방향 안내
    func announceNavigation(distance: Double, instruction: String) {
        let distanceText: String
        if distance < 50 {
            distanceText = "\(Int(distance))미터 후"
        } else if distance < 1000 {
            distanceText = "\(Int(distance/10)*10)미터 후"
        } else {
            distanceText = String(format: "약 %.1f킬로미터 후", distance / 1000)
        }
        
        announce("\(distanceText) \(instruction)")
        provideLightHaptic()
    }
    
    // 진행률 안내
    func announceProgress(_ progress: Double) {
        let percentage = Int(progress * 100)
        announce("코스 \(percentage)퍼센트 완주했습니다.", priority: .normal)
    }
    
    // 완주 축하
    func announceCompletion(distance: Double, time: TimeInterval) {
        let distanceText = String(format: "%.1f", distance / 1000)
        let minutes = Int(time / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        
        announce("축하합니다! \(distanceText)킬로미터를 \(minutes)분 \(seconds)초에 완주했습니다!", priority: .high)
        provideCompletionHaptic()
    }
    
    // 일시정지 안내
    func announcePause() {
        announce("러닝이 일시정지되었습니다.", priority: .high)
        providePauseHaptic()
    }
    
    // 재개 안내
    func announceResume() {
        announce("러닝을 재개합니다.", priority: .high)
        provideResumeHaptic()
    }
    
    // MARK: - 내부 메서드
    
    private func speak(_ message: String) {
        // 현재 말하고 있는 중이면 중단
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        synthesizer.speak(utterance)
    }
}

// MARK: - 햅틱 피드백 확장
extension VoiceGuidanceService {
    
    // 가벼운 피드백 (일반 안내)
    private func provideLightHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    // 성공 피드백 (목표 달성, 코스 복귀)
    private func provideSuccessHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)
    }
    
    // 경고 피드백 (코스 이탈)
    private func provideWarningHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    // 시작 피드백
    private func provideStartHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // 0.2초 후 한 번 더
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactFeedback.impactOccurred()
        }
    }
    
    // 거리 달성 피드백
    private func provideDistanceHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        
        // 3번 연속 진동
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                impactFeedback.impactOccurred()
            }
        }
    }
    
    // 완주 축하 피드백
    private func provideCompletionHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        
        // 성공음 + 강한 진동 조합
        notificationFeedback.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    // 일시정지 피드백
    private func providePauseHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    // 재개 피드백
    private func provideResumeHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        
        // 2번 빠르게
        impactFeedback.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension VoiceGuidanceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("음성 안내 시작: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("음성 안내 완료: \(utterance.speechString)")
    }
}

// MARK: - 안내 우선순위
enum AnnouncementPriority {
    case low
    case normal
    case high
}
