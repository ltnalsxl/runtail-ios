//
//  Course.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

import SwiftUI
import MapKit

import Foundation

struct Coordinate: Codable, Hashable {
    let lat: Double
    let lng: Double
    let timestamp: TimeInterval
}

struct Course: Identifiable, Codable {
    let id: String
    let title: String
    let distance: Double
    let coordinates: [Coordinate]
    let createdAt: Date
    let createdBy: String
    let isPublic: Bool
    let runCount: Int     // 새로 추가된 필드
    
    // 생성자 업데이트 (기본값 설정으로 기존 코드와 호환성 유지)
    init(id: String, title: String, distance: Double, coordinates: [Coordinate],
         createdAt: Date, createdBy: String, isPublic: Bool, runCount: Int = 0) {
        self.id = id
        self.title = title
        self.distance = distance
        self.coordinates = coordinates
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.isPublic = isPublic
        self.runCount = runCount
    }
}
