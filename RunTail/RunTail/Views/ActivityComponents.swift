import SwiftUI

// Individual day cell used in ActivityTabView calendar
struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isActive: Bool
    let isSelected: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(Color.rtPrimary)
                    .frame(width: 36, height: 36)
            } else if isActive {
                Circle()
                    .fill(Color.rtPrimary.opacity(0.2))
                    .frame(width: 36, height: 36)
            } else if isSelected {
                Circle()
                    .stroke(Color.rtPrimary, lineWidth: 1)
                    .frame(width: 36, height: 36)
            }

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14))
                .foregroundColor(
                    isToday ? .white : (calendar.component(.weekday, from: date) == 1 ? .red : .primary)
                )
        }
        .frame(height: 36)
    }
}

// Running history list item used in ActivityTabView
struct RunningHistoryItem: View {
    let run: Run
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(monthString(from: run.runAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Text("\(Calendar.current.component(.day, from: run.runAt))")
                        .font(.system(size: 18, weight: .bold))

                    Text(yearString(from: run.runAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(width: 50)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(getDayOfWeek(date: run.runAt))
                        .font(.system(size: 16, weight: .medium))

                    let distance = run.trail.count > 0 ? 150 * Double(run.trail.count) : 0
                    Text("\(Formatters.formatDistance(distance)) · \(Formatters.formatDuration(run.duration))")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("페이스")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Text(run.paceStr)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.rtPrimary)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func getDayOfWeek(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월"
        return formatter.string(from: date)
    }

    private func yearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}

