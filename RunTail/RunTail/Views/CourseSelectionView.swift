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
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Button("취소") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.rtPrimary)
                    
                    Spacer()
                    
                    Text("코스 선택")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("시작") {
                        if let course = selectedCourse {
                            startFollowingSelectedCourse(course)
                        }
                    }
                    .disabled(selectedCourse == nil)
                    .foregroundColor(selectedCourse == nil ? .gray : .rtPrimary)
                    .fontWeight(.semibold)
                }
                .padding()
                .background(Color.rtCardAdaptive)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // 코스 목록
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                        
                        Text("주변 코스를 검색 중...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if nearbyCourses.isEmpty {
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
                        
                        Button("코스 만들기") {
                            presentationMode.wrappedValue.dismiss()
                            // 자유 달리기로 이동
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.rtPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section(header: Text("주변 코스 (\(nearbyCourses.count)개)")) {
                            ForEach(nearbyCourses) { course in
                                CourseRowView(
                                    course: course,
                                    isSelected: selectedCourse?.id == course.id,
                                    onSelect: { selectedCourse = course }
                                )
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
        }
        .onAppear {
            loadNearbyCourses()
        }
    }
    
    private func loadNearbyCourses() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let userLocation = locationService.lastLocation?.coordinate else {
                isLoading = false
                return
            }
            
            nearbyCourses = viewModel.findNearbyCoursesFor(coordinate: userLocation, radius: 10000) // 10km 반경
            isLoading = false
        }
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
            HStack(spacing: 12) {
                // 코스 미리보기 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.rtPrimary.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "map.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .rtPrimary : .gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(Formatters.formatDistance(course.distance))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(estimatedTimeText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if course.runCount > 0 {
                        Text("실행 횟수: \(course.runCount)회")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.rtPrimary)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var estimatedTimeText: String {
        let estimatedSeconds = course.distance / 1000 * 6 * 60 // 6분/km 기준
        return Formatters.formatDuration(Int(estimatedSeconds))
    }
}
