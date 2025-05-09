//
//  LocationService.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//  Updated with improved location tracking
//

import Foundation
import MapKit
import CoreLocation
import SwiftUI

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - 프로퍼티
    private let locationManager = CLLocationManager()
    
    // 지도 영역
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), // 서울
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // 위치 관련 상태
    @Published var locationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?
    @Published var isHighAccuracyMode = false
    @Published var gpsSignalStrength: Int = 0 // 0-4 사이의 값 (0: 신호 없음, 4: 최상)
    
    // 콜백
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    
    // MARK: - 초기화
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - 설정
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        // ⚠️ iOS 14 이상에서 정확도 제어도 가능 (필요시 추가)
        if #available(iOS 14.0, *) {
            locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "LocationPurpose")
        }

        // 약간 딜레이 후 항상 권한 요청 (시스템이 거절하지 않게 하기 위함)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.locationManager.requestAlwaysAuthorization()
            }

            locationManager.startUpdatingLocation()
        }
    
    // MARK: - 지도 조작 기능
    func zoomIn() {
        withAnimation {
            region.span = MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta * 0.5, 0.001),
                longitudeDelta: max(region.span.longitudeDelta * 0.5, 0.001)
            )
        }
    }
    
    func zoomOut() {
        withAnimation {
            region.span = MKCoordinateSpan(
                latitudeDelta: min(region.span.latitudeDelta * 2, 1),
                longitudeDelta: min(region.span.longitudeDelta * 2, 1)
            )
        }
    }
    
    func centerOnUserLocation() {
        if let location = lastLocation {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: region.span
                )
            }
        }
    }
    
    // MARK: - 위치 정확도 모드
    func startHighAccuracyLocationUpdates() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5 // 5미터마다 업데이트
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
        isHighAccuracyMode = true
    }
    
    func stopHighAccuracyLocationUpdates() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.startUpdatingLocation()
        isHighAccuracyMode = false
    }
    
    // MARK: - GPS 신호 강도 계산
    private func calculateGPSSignalStrength(accuracy: CLLocationAccuracy) -> Int {
        if accuracy <= 0 {
            return 0 // 신호 없음
        } else if accuracy < 5 {
            return 4 // 최상
        } else if accuracy < 10 {
            return 3 // 좋음
        } else if accuracy < 50 {
            return 2 // 보통
        } else if accuracy < 100 {
            return 1 // 약함
        } else {
            return 0 // 매우 약함
        }
    }
    
    // MARK: - CLLocationManagerDelegate 메서드
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 현재 위치 저장
        lastLocation = location
        
        // GPS 신호 강도 업데이트
        gpsSignalStrength = calculateGPSSignalStrength(accuracy: location.horizontalAccuracy)
        
        // 지도 영역 업데이트
        updateRegion(location: location)
        
        // 콜백으로 위치 전달
        onLocationUpdate?(location.coordinate)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationStatus = status
        
        // 권한 상태에 따른 처리
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            
        case .denied, .restricted:
            // 권한 거부 처리
            print("위치 권한이 거부되었습니다.")
            
        case .notDetermined:
            // 아직 결정되지 않음, 대기
            print("위치 권한이 아직 결정되지 않았습니다.")
            
        @unknown default:
            print("알 수 없는 위치 권한 상태")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 오류 처리
        print("위치 서비스 오류: \(error.localizedDescription)")
        
        // 오류 유형에 따른 처리
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                // 사용자가 위치 서비스를 거부함
                print("사용자가 위치 서비스를 거부했습니다.")
                
            case .network:
                // 네트워크 관련 오류
                print("네트워크 오류로 위치를 가져올 수 없습니다.")
                
            default:
                print("위치 서비스 오류: \(clError.localizedDescription)")
            }
        }
        
        // 신호가 약함을 표시
        gpsSignalStrength = 0
    }
    
    // MARK: - 헬퍼 메서드
    private func updateRegion(location: CLLocation) {
        withAnimation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: region.span
            )
        }
    }
    
    // 위치 서비스 상태 확인
    func checkLocationServicesStatus() -> Bool {
        if CLLocationManager.locationServicesEnabled() {
            switch locationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                return true
            default:
                return false
            }
        } else {
            return false
        }
    }
    
    // 위치 정확도 적합성 확인 (러닝 기록에 적합한지)
    func isLocationAccuracySufficientForRunning() -> Bool {
        guard let location = lastLocation else { return false }
        
        // 수평 정확도가 20미터 이내인 경우에만 적합
        return location.horizontalAccuracy <= 20
    }
    
    // GPS 상태 메시지 생성
    func gpsStatusMessage() -> String {
        guard checkLocationServicesStatus() else {
            return "위치 서비스가 비활성화되었습니다."
        }
        
        switch gpsSignalStrength {
        case 0:
            return "GPS 신호가 없습니다."
        case 1:
            return "GPS 신호가 약합니다."
        case 2:
            return "GPS 신호가 보통입니다."
        case 3:
            return "GPS 신호가 좋습니다."
        case 4:
            return "GPS 신호가 최상입니다."
        default:
            return "GPS 신호를 확인 중입니다."
        }
    }
}
