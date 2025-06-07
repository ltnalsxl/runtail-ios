import SwiftUI
import Firebase

// Card used in ExploreTabView course lists
struct ExploreCourseCard: View {
    let course: Course
    @ObservedObject var viewModel: MapViewModel
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        Button(action: {
            viewModel.selectedCourseId = course.id
            viewModel.showCourseDetailView = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(viewModel.themeColor.opacity(0.1))

                    Image(systemName: "map.fill")
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.themeColor)
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(course.title)
                            .font(.system(size: 16, weight: .medium))

                        Spacer()

                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundColor(isFavorite ? .yellow : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text("\(Formatters.formatDistance(course.distance)) · 약 \(calculateEstimatedTime(distance: course.distance))")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    HStack {
                        if course.createdBy == Auth.auth().currentUser?.uid {
                            if course.isPublic {
                                Text("내 공개")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(12)
                            } else {
                                Text("내 비공개")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(viewModel.themeColor.opacity(0.1))
                                    .foregroundColor(viewModel.themeColor)
                                    .cornerRadius(12)
                            }
                        } else if course.isPublic {
                            Text("공개")
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }

                        Text(getCourseTag(course: course))
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(Color.orange)
                            .cornerRadius(12)

                        Spacer()

                        if course.isPublic {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 10))

                                Text("\(course.runCount)")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func calculateEstimatedTime(distance: Double) -> String {
        var pace = viewModel.getUserAveragePace()
        if pace <= 0 || pace > 15 * 60 {
            pace = 6 * 60
        }
        let seconds = (distance / 1000) * pace
        return Formatters.formatDuration(Int(seconds))
    }

    private func getCourseTag(course: Course) -> String {
        let distanceKm = course.distance / 1000
        if distanceKm < 3 { return "3km 미만" }
        else if distanceKm < 5 { return "5km 미만" }
        else if distanceKm < 10 { return "10km 미만" }
        else { return "장거리" }
    }
}

