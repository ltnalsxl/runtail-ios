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
    let distance: Double  // meter
    let coordinates: [Coordinate]
    let createdAt: Date
    let createdBy: String
    let isPublic: Bool
}
