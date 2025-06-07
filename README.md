# 🐾 RunTail – On Your Mark!

![iOS CI](https://github.com/yourname/runtail-ios/actions/workflows/ios.yml/badge.svg)

> **Create, share, and follow custom running routes — your personal running journey.**  
> **나만의 러닝 루트를 만들고, 공유하고, 함께 달리는 커뮤니티 앱.**

---

## 📱 Features / 기능 요약

| Feature | 설명 |
|--------|------|
| 🏃 Create your own running course | GPS 기반으로 코스 기록 및 저장 |
| 🌐 Share & discover routes | 다른 User 코스 탐색 |
| 📍 Follow a route in real-time | 실시간 지도 기반 ‘따라 달리기’ 기능 |
| 🧑‍🤝‍🧑 Pace maker mode | 자신의 기록 혹은 친구 기록을 기준으로 페이스 설정 |
| 🗺️ Nearby course finder | 내 위치 기반 주변 러닝 코스 탐색 |
| 🏆 Leaderboard & finishers | 코스별 리더보드 / 최근 완주자 리스트 표시 |

---

## 🛠️ Tech Stack / 기술 스택

| 영역 | 사용 기술 |
|------|-----------|
| **Frontend** | Swift (UIKit), MapKit |
| **Backend** | Firebase (Auth, Firestore, Storage) |
| **Database** | Firestore |
| **Design Tool** | Figma, Uizard |
| **Version Control** | Git + GitHub |
| **Docs** | Notion 기반 기획 문서화 |

---

## 🧭 Setup / 프로젝트 설정 방법

### 🔗 Clone the repository / 저장소 클론
```bash
git clone https://github.com/yourname/runtail-ios.git
cd runtail-ios
open RunTail.xcodeproj
```

### ⚙️ Requirements / 요구 사항

- macOS Monterey 이상
- Xcode 15+
- Firebase `GoogleService-Info.plist` 등록 필요
- iOS 시뮬레이터 or 실기기

### 📦 Install dependencies / 의존성 설치

RunTail uses **Swift Package Manager** to manage dependencies such as Firebase.\
Open `RunTail.xcodeproj` in Xcode and it will automatically resolve the packages.\
If the packages fail to download select **File > Packages > Reset Package Caches**
followed by **File > Packages > Resolve Package Versions**.

### 🔐 Firebase Setup / Firebase 설정

1. [Firebase console](https://console.firebase.google.com/)에서 프로젝트를 생성합니다.
2. iOS 앱을 등록한 뒤 `GoogleService-Info.plist` 파일을 다운로드합니다.
3. 이 파일을 프로젝트 루트의 `RunTail` 디렉터리에 추가합니다. `Info.plist`와
   같은 위치에 두면 빌드 시 자동으로 포함됩니다.

---

## 📁 Folder Structure / 폴더 구조

```
RunTail/
├── Views/
├── Models/
├── Services/
├── Resources/
├── GoogleService-Info.plist  # gitignore로 제외됨
```

---

## 🧪 Running Tests / 테스트 실행

Open the project in Xcode and select the **RunTail** scheme.\
Choose **Product > Test** or press <kbd>⌘U</kbd> to execute the unit tests.\
Alternatively, from the command line run:

```bash
xcodebuild test -scheme RunTail -destination 'platform=iOS Simulator,name=iPhone 15'
```

If any CI status badges are configured for this repository they will appear at the top of this document.

---

## 📄 License / 라이선스

MIT License.  
자세한 내용은 [LICENSE](./LICENSE)를 참고하세요.
