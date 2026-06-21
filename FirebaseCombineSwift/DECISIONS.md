# Decisions

This file documents some of the decisions we made when developing Combine support for Firebase.

# Module structure

## Discussion
The general idea is to keep all Combine-related code in a separate module (`FirebaseCombineSwift`, to match the naming scheme used for `FirebaseFirestoreSwift` and `FirebaseStorage`).

By using the `#if canImport(moduleName)` directive, we can make sure to only enable the publishers for a module that developers have imported into a build target.


# Implementing Publishers

## Custom Publishers vs. wrapping in Futures / using PassthroughSubject

Instead of implementing [custom  publishers](https://thoughtbot.com/blog/lets-build-a-custom-publisher-in-combine), which [Apple discourages developers from doing](https://developer.apple.com/documentation/combine/publisher), we make use of [`PassthroughSubject`](https://developer.apple.com/documentation/combine/passthroughsubject) (for publishers that emit a stream of events), and [`Future`](https://developer.apple.com/documentation/combine/future) for one-shot calls that produce a single value.

## Using capture lists

After discussing internally, we came to the conclusion that the outer closure in the following piece of code is non-escaping, hence there is no benefit to weakly capture `self`. As the inner closure doesn't refer to `self`, the reference does not outlive the current call stack.

It is thus safe to not use `[weak self]` in this instance.

```swift
extension Auth {
    public func createUser(withEmail email: String,
                           password: String) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { /* [weak self]  <-- not required */ promise in
        self?.createUser(withEmail: email, password: password) { authDataResult, error in
          if let error {
            promise(.failure(error))
          } else if let authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }
}
```

# Method naming

## Discussion
* Methods that might send a **stream of events** over time will receive a `Publisher` suffix, in line with Apple's own APIs. Any `add` prefix will be removed. This helps to clarify that the user is not _adding_ something that they will have to remove later on ([as is required](https://firebase.google.com/docs/auth/ios/start#listen_for_authentication_state) in most of Firebase's existing APIs). Instead, the result of the publisher needs to be handled just like any other publisher (i.e. be kept in a set of `Cancellable`s).

    Examples:
    * `addStateDidChangeListener` -> `authStateDidChangePublisher`
    * `addSnapshotListener` -> `snapshotPublisher`

* Methods that **return a result once** will not receive a suffix. This effectively means that these methods are overloads to their existing counterparts that take a closure. To silence any `Result of call to xzy is unused` warnings, these methods need to be prefixed with `@discardableresult`. This shouldn't be a problem, since the Future that is created inside those functions is called immediately and will be disposed of by the runtime upon returning from the inner closure.

    Examples:
    * `signIn` -> `signIn`
    * `createUser` -> `createUser`

## Options considered
Using the same method and parameter names for one-shot asynchronous methods results in both methods to be shown in close proximity when invoking code completion

![image](https://user-images.githubusercontent.com/232107/99672274-76f05680-2a73-11eb-880a-3563f293de7d.png)

To achieve the same for methods that return a stream of events, we'd have to name those `addXzyListener`. This would be in contrast to Apple's naming scheme (e.g. `dataTask(with:completionHandler)` -> `dataTaskPublisher(for:)`
