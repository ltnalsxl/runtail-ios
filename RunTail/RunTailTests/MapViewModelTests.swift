import Testing
import CoreLocation
@testable import RunTail

final class MockAuth: FirebaseAuthProtocol {
    var currentUserEmail: String?
    var currentUserId: String?
    var signOutCalled = false
    var signOutError: Error?

    func signOut() throws {
        signOutCalled = true
        if let error = signOutError { throw error }
    }
}

struct MapViewModelTests {
    @Test func startAndStopRun() async throws {
        let auth = MockAuth()
        auth.currentUserId = "user"
        auth.currentUserEmail = "test@example.com"
        let vm = MapViewModel(authProvider: auth, loadData: false)

        vm.startRecording()
        #expect(vm.isRecording)
        #expect(!vm.isPaused)

        vm.addLocationToRecording(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        vm.addLocationToRecording(coordinate: CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001))

        var result: Bool? = nil
        vm.stopRecording { success, _ in
            result = success
        }

        #expect(result == true)
        #expect(!vm.isRecording)
        #expect(vm.showSaveAlert)
    }

    @Test func courseFollowingLogic() async throws {
        let auth = MockAuth()
        let vm = MapViewModel(authProvider: auth, loadData: false)

        let coords = [
            Coordinate(lat: 0, lng: 0, timestamp: 0),
            Coordinate(lat: 0, lng: 0.001, timestamp: 1),
            Coordinate(lat: 0, lng: 0.002, timestamp: 2)
        ]
        let course = Course(id: "c", title: "Test", distance: 200, coordinates: coords, createdAt: Date(), createdBy: "u", isPublic: true)

        vm.startFollowingCourse(course)
        #expect(vm.isFollowingCourse)
        #expect(vm.nextWaypoint != nil)

        vm.addLocationToRecordingWithCourseTracking(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0.001))
        #expect(vm.courseProgress > 0)
        #expect(!vm.isOffCourse)

        vm.updateCourseTracking(userLocation: CLLocationCoordinate2D(latitude: 10, longitude: 10))
        #expect(vm.isOffCourse)

        vm.stopFollowingCourse()
        #expect(!vm.isFollowingCourse)
    }
}
