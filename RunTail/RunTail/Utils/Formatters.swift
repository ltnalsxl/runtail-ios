//
//  Formatters.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//
import Foundation
import MapKit

class Formatters {
    // 거리 형식 지정
    static func formatDistance(_ distance: Double) -> String {
        let distanceInKm = distance / 1000
        if distanceInKm < 1 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distanceInKm)
        }
    }
    
    // 시간 형식 지정
    static func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        
        if minutes < 60 {
            return "\(minutes)분 \(remainingSeconds)초"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)시간 \(remainingMinutes)분"
        }
    }
    
    // 날짜 형식 지정
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
    
    // 좌표 배열로부터 거리 계산
    static func calculateDistance(coordinates: [CLLocationCoordinate2D]) -> String {
        // 실제로는 좌표 사이의 거리를 계산해야 함
        // 간단한 구현을 위해 좌표 개수에 비례한 값 반환
        let distance = Double(coordinates.count) * 10 // 예시 값
        return formatDistance(distance)
    }
}
