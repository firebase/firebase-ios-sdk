# Combine Support for Firebase

This module contains Combine support for Firebase APIs. 

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
](../SwiftPackageManager.md)
* Make sure to import the package `FirebaseCombineSwift-Beta`

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