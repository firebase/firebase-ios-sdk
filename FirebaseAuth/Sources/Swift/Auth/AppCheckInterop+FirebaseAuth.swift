import Foundation
#if SWIFT_PACKAGE
  @preconcurrency import FirebaseAppCheckInterop
#endif

extension AppCheckInterop {
  func getTokenResult(forcingRefresh: Bool) async -> (token: String, error: Error?) {
    await withCheckedContinuation { continuation in
      self.getToken(forcingRefresh: forcingRefresh) { result in
        let token = result?.token ?? ""
        let error = result?.error
        continuation.resume(returning: (token, error))
      }
    }
  }
}
