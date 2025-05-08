//
//  LocationService.swift
//  RunTail
//
//  Created by 이수민 on 5/6/25.
//

import Foundation
import MapKit
import CoreLocation
import SwiftUI  // SwiftUI import 추가 (withAnimation을 위해 필요)

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), // 서울
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var locationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        updateRegion(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    private func updateRegion(location: CLLocation) {
        withAnimation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: region.span
            )
        }
    }
}
