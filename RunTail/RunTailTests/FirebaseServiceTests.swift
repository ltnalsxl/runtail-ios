import Testing
@testable import RunTail

final class MockAuthService: FirebaseAuthProtocol {
    var currentUserEmail: String?
    var currentUserId: String?
    var signOutCalled = false
    var shouldThrow = false

    func signOut() throws {
        signOutCalled = true
        if shouldThrow {
            struct ErrorStub: Error {}
            throw ErrorStub()
        }
    }
}

struct FirebaseServiceTests {
    @Test func getCurrentUserNil() async throws {
        let auth = MockAuthService()
        let service = FirebaseService(auth: auth)
        #expect(service.getCurrentUser() == nil)
    }

    @Test func logoutUserSuccess() async throws {
        let auth = MockAuthService()
        let service = FirebaseService(auth: auth)
        #expect(service.logoutUser())
        #expect(auth.signOutCalled)
    }

    @Test func logoutUserFailure() async throws {
        let auth = MockAuthService()
        auth.shouldThrow = true
        let service = FirebaseService(auth: auth)
        #expect(!service.logoutUser())
        #expect(auth.signOutCalled)
    }
}
