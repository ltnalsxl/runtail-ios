//
//  CourseSelectionView.swift
//  RunTail
//
//  Created by 이수민 on 5/10/25.
//

import SwiftUI
import MapKit

struct CourseSelectionView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var locationService: LocationService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var nearbyCourses: [Course] = []
    @State private var selectedCourse: Course?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Button("취소") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    
                    Spacer()
                    
                    Text("코스 선택")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("시작") {
                        if let course = selectedCourse {
                            startFollowingSelectedCourse(course)
                        }
                    }
                    .disabled(selectedCourse == nil)
                    .foregroundColor(selectedCourse == nil ? .gray : .rtPrimary)
                }
                .padding()
                
                // 코스 목록
                if nearbyCourses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("주변에 코스가 없습니다")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("다른 위치로 이동하거나\n먼저 코스를 생성해보세요")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(nearbyCourses) { course in
                            CourseRowView(
                                course: course,
                                isSelected: selectedCourse?.id == course.id,
                                onSelect: { selectedCourse = course }
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            loadNearbyCourses()
        }
    }
    
    private func loadNearbyCourses() {
        guard let userLocation = locationService.lastLocation?.coordinate else { return }
        nearbyCourses = viewModel.findNearbyCoursesFor(coordinate: userLocation, radius: 10000) // 10km 반경
    }
    
    private func startFollowingSelectedCourse(_ course: Course) {
        presentationMode.wrappedValue.dismiss()
        
        // 위치 서비스 정확도 높이기
        locationService.startHighAccuracyLocationUpdates()
        locationService.onLocationUpdate = { coordinate in
            viewModel.addLocationToRecordingWithCourseTracking(coordinate: coordinate)
        }
        
        // 따라 달리기 시작
        viewModel.startFollowingCourse(course)
    }
}

struct CourseRowView: View {
    let course: Course
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(Formatters.formatDistance(course.distance)) • \(estimatedTimeText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("실행 횟수: \(course.runCount)회")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.rtPrimary)
                        .font(.title2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var estimatedTimeText: String {
        let estimatedSeconds = course.distance / 1000 * 6 * 60 // 6분/km 기준
        return Formatters.formatDuration(Int(estimatedSeconds))
    }
}
