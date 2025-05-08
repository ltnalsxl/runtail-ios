//
//  Run.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//
import SwiftUI
import MapKit

struct Run: Identifiable {
    let id: String
    let courseId: String
    let duration: Int      // 초 단위
    let pace: Int          // 초/km 단위
    let paceStr: String    // 문자열 표시 (e.g. "6'20"")
    let runAt: Date
    let trail: [CLLocationCoordinate2D]
    let userId: String
}
