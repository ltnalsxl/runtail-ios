import SwiftUI

struct LineupView: View {
    @State private var lineupAvailable: Bool? = nil
    @State private var showLatestLineup = false
    @State private var cancelled = false

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 20) {
            if let available = lineupAvailable {
                if available {
                    Text("오늘의 라인업")
                        .font(.title3)
                    Text("라인업 상세 정보가 여기에 표시됩니다.")
                        .foregroundColor(.gray)
                } else {
                    Text(unavailableMessage)
                        .multilineTextAlignment(.center)
                        .padding()

                    HStack(spacing: 24) {
                        Button("최근 라인업 보기") {
                            showLatestLineup = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("취소") {
                            cancelled = true
                        }
                        .buttonStyle(.bordered)
                    }

                    if cancelled {
                        Text("취소되었습니다.")
                            .foregroundColor(.gray)
                    }
                }
            } else {
                ProgressView()
                    .onAppear(perform: loadLineup)
            }
        }
        .padding()
        .navigationTitle("오늘의 라인업")
        .sheet(isPresented: $showLatestLineup) {
            LatestLineupView()
        }
    }

    private var unavailableMessage: String {
        if isMonday {
            return "월요일은 야구가 없는 날입니다. 최근 라인업을 보러가실래요?"
        } else {
            return "오늘 라인업이 아직 공개되지 않았습니다. 최근 라인업을 보러가실래요?"
        }
    }

    private var isMonday: Bool {
        calendar.component(.weekday, from: Date()) == 2
    }

    private func loadLineup() {
        // 실제 앱에서는 API에서 라인업 정보를 불러옵니다.
        lineupAvailable = false
    }
}

struct LatestLineupView: View {
    var body: some View {
        Text("최근 라인업 (예시 화면)")
            .font(.title3)
            .padding()
    }
}
