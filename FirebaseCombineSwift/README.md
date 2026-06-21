# Combine Support for Firebase

This module contains Combine support for Firebase APIs.

**Note**: This feature is under development and is supported only on a community basis. You can follow
development on the [project tracker](https://github.com/firebase/firebase-ios-sdk/projects/3)

## Installation

<details><summary>CocoaPods</summary>

* Add `pod 'Firebase/FirebaseCombineSwift'` to your podfile:

```Ruby
platform :ios, '14.0'

target 'YourApp' do
  use_frameworks!

  pod 'Firebase/Auth'
  pod 'Firebase/Analytics'
  pod 'Firebase/FirebaseCombineSwift'
end
```

</details>

<details><summary>Swift Package Manager</summary>

* Follow the instructions in [Swift Package Manager for Firebase Beta
](../SwiftPackageManager.md) to add Firebase to your project
* Make sure to import all of the following packages you intend to use:
  * FirebaseAuthCombine-Community
  * FirebaseFirestoreCombine-Community
  * FirebaseFunctionsCombine-Community
  * FirebaseStorageCombine-Community
* In your code, import the respective module:
  * FirebaseAuthCombineSwift
  * FirebaseFirestoreCombineSwift
  * FirebaseFunctionsCombineSwift
  * FirebaseStorageCombineSwift
</details>

## Usage

### Auth

#### Sign in anonymously

```swift
  Auth.auth().signInAnonymously()
    .sink { completion in
      switch completion {
      case .finished:
        print("Finished")
      case let .failure(error):
        print("\(error.localizedDescription)")
      }
    } receiveValue: { authDataResult in
    }
    .store(in: &cancellables)
```

```swift
  Auth.auth().signInAnonymously()
    .map { result in
      result.user.uid
    }
    .replaceError(with: "(unable to sign in anonymously)")
    .assign(to: \.uid, on: self)
    .store(in: &cancellables)
```
#### Sign in with a given 3rd-party credentials


In the `sign(_:didSignInFor:withError:)` method, get a Google ID token and Google access token from the GIDAuthentication object and asynchronously exchange them for a Firebase credential:

```swift
  func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error?) {
    // ...
    if let error {
      // ...
      return
    }

    guard let authentication = user.authentication else { return }
    let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken,
                                                   accessToken: authentication.accessToken)
    Auth.auth()
      .signIn(withCredential: credential)
      .mapError { $0 as NSError }
      .tryCatch(handleError)
      .sink { /* ... */ } receiveValue: {  /* ... */  }
      .store(in: &subscriptions)
  }

  private func handleError(_ error: NSError) throws -> AnyPublisher<AuthDataResult, Error> {
    guard isMFAEnabled && error.code == AuthErrorCode.secondFactorRequired.rawValue
    else { throw error }

    // The user is a multi-factor user. Second factor challenge is required.
    let resolver = error.userInfo[AuthErrorUserInfoMultiFactorResolverKey] as! MultiFactorResolver
    let displayNameString = resolver.hints.compactMap(\.displayName).joined(separator: " ")

    return showTextInputPrompt(withMessage: "Select factor to sign in\n\(displayNameString)")
      .compactMap { displayName in
        resolver.hints.first(where: { displayName == $0.displayName }) as? PhoneMultiFactorInfo
      }
      .flatMap { [unowned self] factorInfo in
        PhoneAuthProvider.provider()
          .verifyPhoneNumber(withMultiFactorInfo: factorInfo, multiFactorSession: resolver.session)
          .zip(self.showTextInputPrompt(withMessage: "Verification code for \(factorInfo.displayName ?? "")"))
          .map { (verificationID, verificationCode) in
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID,
                                                                     verificationCode: verificationCode)
            return PhoneMultiFactorGenerator.assertion(with: credential)
          }
      }
      .flatMap { assertion in
        resolver.resolveSignIn(withAssertion: assertion)
      }
      .eraseToAnyPublisher()
  }
```

### Functions

```swift
let helloWorld = Functions.functions().httpsCallable("helloWorld")
helloWorld.call()
  .sink { completion in
    switch completion {
      case .finished:
        print("Finished")
      case let .failure(error):
        print("\(error.localizedDescription)")
    }
  } receiveValue: { functionResult in
    if let result = functionResult.data as? String {
      print("The function returned: \(result)")
    }
  }
  .store(in: &cancellables)
```

```swift
let helloWorld = Functions.functions().httpsCallable("helloWorld")
helloWorld.call("Peter")
  .sink { completion in
    switch completion {
      case .finished:
        print("Finished")
      case let .failure(error):
        print("\(error.localizedDescription)")
    }
  } receiveValue: { functionResult in
    if let result = functionResult.data as? String {
      print("The function returned: \(result)")
    }
  }
  .store(in: &cancellables)
```
