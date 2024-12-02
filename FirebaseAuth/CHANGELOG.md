# 11.6.0
- [added] Added reCAPTCHA Enterprise support for app verification during phone
  authentication for Firebase Authentication (#14114)
- [fixed] Restore Firebase 10 behavior by synchronizing access to the
  `Auth.currentUser` API. This resolves some Firebase 11 issues where the
  current user is unexpectedly `nil` at startup.
- [fixed] Restore Firebase 10 decoding behavior to prevent user provider data
  from always being decoded as `nil` . Note that this fix was only needed for
  cases where Firebase 11 was reading data written by Firebase 10. (#14011)
- [fixed] Restore Firebase 10 decoding behavior to prevent user provider data
  from being decoded as `nil` when a user has multiple linked providers. Note
  that this fix was only needed for cases where Firebase 11 was reading data
  written by Firebase 10. Note that this fix will not be in the 11.6.0 zip and
  Carthage distributions, but will be included from 11.6.0 onwards. (#14011)

# 11.5.0
- [fixed] Restore pre-Firebase 11 decoding behavior to prevent users getting
  logged out when upgrading from Firebase 8.10.0 or earlier to Firebase 11.
  Note that this fix will not be in the 11.5.0 zip and Carthage
  distributions, but will be included from 11.6.0 onwards. (#14011)
- [fixed] Restore Firebase 10 keychain error handling behavior when retrieving
  Firebase Auth tokens, potentially causing user sign-out on Firebase 11. Note
  that this fix will not be in the 11.5.0 zip and Carthage distributions, but
  will be included from 11.6.0 onwards. (#14067)

# 11.4.0
- [fixed] Restore Firebase 10 behavior by ignoring `nil` display names used
  during multi factor enrollment. (#13856)
- [fixed] Fix crash when enrolling account with TOTP MFA. (#13880)

# 11.3.0
- [fixed] Restore Firebase 10 behavior by querying with the
  `kSecAttrSynchronizable` key when auth state is set to be shared across
  devices. (#13584)
- [fixed] Prevent a bad memory access crash by using non-ObjC, native Swift
  types in the SDK's networking layer, and moving synchronous work off of
  the shared Swift concurrency queue. (#13650)
- [fixed] Restore Firebase 10 behavior by forwarding errors from interrupted
  reCAPTCHA or OIDC login flows. (#13645)

# 11.2.0
- [fixed] Fixed crashes that could occur in Swift continuation blocks running in the Xcode 16
  betas. (#13480)
- [fixed] Fixed Phone Auth via Sandbox APNS tokens that broke in 11.0.0. (#13479)
- [fixed] Fixed crash when fetching sign in methods due to unexpected nil.
  Previously, fetching sign in methods could return both a `nil` array of sign
  in methods and a `nil` error. In such cases, an empty array is instead
  returned with the `nil` error. (#13550)
- [fixed] Fixed user session persistence in multi tenant projects. Introduced in 11.0.0. (#13565)
- [fixed] Fixed encoding crash that occurs when using TOTP multi-factor
  authentication. Note that this fix will not be in the 11.2.0 zip and Carthage
  distributions, but will be included from 11.3.0 onwards. (#13591)

# 11.1.0
- [fixed] Fixed `Swift.error` conformance for `AuthErrorCode`. (#13430)
- [added] Added custom provider support to `AuthProviderID`. Note that this change will be breaking
  to any code that implemented an exhaustive `switch` on `AuthProviderID` in 11.0.0 - the `switch`
  will need expansion. (#13429)
- [fixed] Fix crash introduced in 11.0.0 in phone authentication flow from
  implicitly unwrapping `nil` error after a token timeout. (#13470)
- [fixed] Objective-C only: `[OAuthProvider getCredentialWithUIDelegate]` was not calling its
  completion handler in the main thread. Regressed in 11.0.0. The fix is only for CocoaPods and
  Swift Package Manager. The zip and Carthage fix will roll out in 11.2.0.
  (https://github.com/firebase/FirebaseUI-iOS/issues/1199)

# 11.0.0
- [fixed] Fixed auth domain matching code to prioritize matching `firebaseapp.com` over `web.app`
  even if the server returns the `web.app` domain listed first. (#7992)
- [added] Introduced the Swift enum `AuthProviderID` for the Auth Provider IDs. (#9236)
- [deprecated] Swift APIs using `String`-typed `productID`s have been deprecated in favor
  of newly added API that leverages the `AuthProviderID` enum.
- [fixed] Breaking API: The `email` property in `ActionCodeInfo` is now non-optional.

# 10.21.0
- [fixed] Fixed multifactor resolver to use the correct Auth instance instead of
  always the default. (#12265)

# 10.19.0
- [changed] Deprecate `updateEmail(to email: String)` and `fetchSignInMethods(forEmail email: String)`. (#12081)

# 10.18.0
- [fixed] Fix a bug where anonymous account can't be linked with email password credential. (#11911)

# 10.16.0
- [added] Added custom auth domain support in recaptcha v2 authentication flows. (#7553)

# 10.14.0
- [added] Added reCAPTCHA verification support in email authentication flows. (#11231)

# 10.13.0
- [fixed] Fixed a compilation error regression introduced in 10.12.0 building iOS App Extensions. (#11537)

# 10.12.0
- [added] Added support to Firebase Auth to enroll and sign in a user with
  TOTP second factor. (#11261)

# 10.8.0
- [added] Added Firebase App Check support to Firebase Auth. (#11056)
- [added] Added Sign in with Apple token revocation support. (#9906)

# 10.7.0
- [added] Added an API for developers to pass the fullName from the Sign in with Apple credential to Firebase. (#10068)

# 10.6.0
- [fixed] Fixed a bug where user is created in a specific tenant although tenantID was not specified. (#10748)
- [fixed] Fixed a bug where the resolver exposed in MFA is not associated to the correct app. (#10690)

# 10.5.0
- [fixed] Use team player ID, game player ID and fetchItems for signature verification. (#10441)
- [fixed] Prevent keychain pop-up when accessing Auth keychain in a Mac
   app. Note that using Firebase Auth in a Mac app requires that the app
   is signed with a provisioning profile that has the Keychain Sharing
   capability enabled (see Firebase 9.6.0 release notes). (#10582)

# 10.4.0
- [fixed] Fix secure coding bugs in MFA. (#10632)
- [fixed] Added handling of error returned from a blocking cloud function. (#10628)

# 10.2.0
- [fixed] Fix a bug where the linking/reauth flows errors are not caught. (#10267)
- [fixed] Force to recaptcha verification flow for phone auth in simulators. (#10426)

# 10.1.0
- [fixed] Fix a bug where multi factor phone number returns `NULL`. (#10296)

# 9.5.0
- [fixed] Fix a bug where phone multi factor id is not correctly retrieved. (#10061)

# 9.2.0
- [fixed] Catch keychain errors instead of using the `isProtectedDataAvailable` API for handling prewarming issue. (#9869)

# 9.0.0
- [fixed] **Breaking change:** Fixed an ObjC-to-Swift API conversion error where `getStoredUser(forAccessGroup:)` returned a non-optional type. This change is breaking for Swift users only (#8599).
- [fixed] Fixed an iOS 15 keychain access issue related to prewarming. (#8695)

# 8.14.0
- [added] Started to collect the Firebase user agent for Firebase Auth. (#9066)

# 8.12.0
- [added] Added documentation note and error logging to `getStoredUser(forAccessGroup:)` regarding tvOS keychain sharing issues. (#8878)
- [fixed] Partial fix for expired ID token issue. (#6521)

# 8.11.0
- [changed] Added a `X-Firebase-GMPID` header to network requests. (#9046)
- [fixed] Added multi-tenancy support to generic OAuth providers. (#7990)
- [fixed] macOS Extension access to Shared Keychain by adding `kSecUseDataProtectionKeychain` recommended key. (#6876)

# 8.9.0
- [changed] Improved error logging. (#8704)
- [added] Added MFA support for email link sign-in. (#8705)

# 8.8.0
- [fixed] Fall back to reCAPTCHA for phone auth app verification if the push notification is not received before the timeout. (#8653)

# 8.6.0
- [fixed] Annotated platform-level availability using `API_UNAVAILABLE` instead of conditionally compiling certain methods with `#if` directives. (#8451)

# 8.5.0
- [fixed] Fixed an analyze issue introduced in Xcode 12.5. (#8411)

# 8.2.0
- [fixed] Fixed analyze issues introduced in Xcode 12.5. (#8210)
- [fixed] Fixed a bug in the link with email link, Game Center, and phone auth flows. (#8196)

# 8.0.0
- [fixed] Fixed a crash that occurred when assigning auth settings. (#7670)

# 7.8.0
- [fixed] Fixed auth state sharing during first app launch. (#7472)

# 7.6.0
- [fixed] Auth emulator now works across the local network. (#7350)
- [fixed] Fixed incorrect import for watchOS (#7425)

# 7.4.0
- [fixed] Check if the reverse client ID is configured as a custom URL scheme before setting it as the callback scheme. (#7211)
- [added] Add ability to sync auth state across devices. (#6924)
- [fixed] Add multi-tenancy support for email link sign-in. (#7246)

# 7.3.0
- [fixed] Catalyst browser issue with `verifyPhoneNumber` API. (#7049)

# 7.1.0
- [fixed] Fixed completion handler issue in `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` method. (#6863)

# 7.0.0
- [removed] Remove deprecated APIs `dataForKey`,`fetchProvidersForEmail:completion`, `signInAndRetrieveDataWithCredential:completion`, `reauthenticateAndRetrieveDataWithCredential:completion`, `linkAndRetrieveDataWithCredential:completion`. (#6607)
- [added] Add support for the auth emulator. (#6624)
- [changed] The global variables `FirebaseAuthVersionNum` and `FirebaseAuthVersionStr` are deleted.
  `FirebaseVersion()` or `FIRFirebaseVersion()` should be used instead.

# 6.9.1
- [fixed] Internal source documentation. (#6371)

# 6.9.0
- [added] Added support for multi-tenancy (#6142).
- [added] Added basic watchOS support. (#4621)
- [changed] Improved Xcode completion of public API completion handlers in Swift. (#6283)

# 6.8.0
- [fixed] Fix bug where multiple keychain entries would result in user persistence failure. (#5906)
- [changed] Added support for using GOOGLE_APP_ID in generic IDP and phone auth reCAPTCHA fallback flows. (#6121)

# 6.7.1
- [fixed] Fixed a multithreaded memory access issue on iOS. (#5979)

# 6.7.0
- [changed] Functionally neutral source reorganization for preliminary Swift Package Manager support. (#5856)

# 6.5.3
- [changed] Remove unused mfa request field "mfa_provider" (#5397)
- [fixed] Suppress deprecation warnings when targeting iOS versions up to iOS 13. (#5437)

# 6.5.2
- [fixed] Handle calls to `useUserAccessGroup` soon after configure. (#4175)

# 6.5.1
- [changed] File structure changes. No functional change.
- [changed] Code formatting changes.

# 6.5.0
- [feature] Added support of Multi-factor Authentication. (#4823)

# 6.4.1
- [fixed] Added support of UISceneDelegate for URL redirect. (#4380)
- [fixed] Fixed rawNonce in encoder. (#4337)

# 6.4.0
- [feature] Added support for Sign-in with Apple. (#4183)

# 6.3.1
- [fixed] Removed usage of a deprecated property on iOS 13. (#4066)

# 6.3.0
- [added] Added methods allowing developers to link and reauthenticate with federated providers. (#3971)

# 6.2.3
- [fixed] Make sure the first valid auth domain is retrieved. (#3493)
- [fixed] Add assertion for Facebook generic IDP flow. (#3208)
- [fixed] Build for Catalyst. (#3549)

# 6.2.2
- [fixed] Fixed an issue where unlinking an email auth provider raised an incorrect error stating the account was not linked to an email auth provider. (#3405)
- [changed] Renamed internal Keychain classes. (#3473)

# 6.2.1
- [added] Add new client error MISSING_CLIENT_IDENTIFIER. (#3341)

# 6.2.0
- [feature] Expose `secret` of OAuth credential in public header. (#3089)
- [fixed] Fix a keychain issue where API key is incorrectly set. (#3239)

# 6.1.2
- [fixed] Fix line limits and linter warnings in public documentation. (#3139)

# 6.1.1
- [fixed] Fix an issue where a user can't link with email provider by email link. (#3030)

# 6.1.0
- [added] Add support of web.app as an auth domain. (#2959)
- [fixed] Fix an issue where the return type of `getStoredUserForAccessGroup:error:` is nonnull. (#2879)

# 6.0.0
- [added] Add support of single sign on. (#2684)
- [deprecated] Deprecate `reauthenticateAndRetrieveDataWithCredential:completion:`, `signInAndRetrieveDataWithCredential:completion:`, `linkAndRetrieveDataWithCredential:completion:`, `fetchProvidersForEmail:completion:`. (#2723, #2756)
- [added] Returned oauth secret token in Generic IDP sign-in for Twitter. (#2663)
- [removed] Remove pendingToken from public API. (#2676)
- [changed] `GULAppDelegateSwizzler` is used for the app delegate swizzling. (#2591)

# 5.4.2
- [added] Support new error code ERROR_INVALID_PROVIDER_ID. (#2629)

# 5.4.1
- [deprecated] Deprecate Microsoft and Yahoo OAuth Provider ID (#2517)
- [fixed] Fix an issue where an exception was thrown when linking OAuth credentials. (#2521)
- [fixed] Fix an issue where a wrong error was thrown when handling error with
  FEDERATED_USER_ID_ALREADY_LINKED. (#2522)

# 5.4.0
- [added] Add support of Generic IDP (#2405).

# 5.3.0
- [changed] Use the new registerInternalLibrary API to register with FirebaseCore. (#2137)

# 5.2.0
- [added] Add support of Game Center sign in (#2127).

# 5.1.0
- [added] Add support of custom FDL domain link (#2121).

# 5.0.5
- [changed] Restore SafariServices framework dependency (#2002).

# 5.0.4
- [fixed] Fix analyzer issues (#1740).

# 5.0.3
- [added] Add `FIRAuthErrorCodeMalformedJWT`, which is raised on JWT token parsing.
  failures during auth operations (#1436).
- [changed] Migrate to use FirebaseAuthInterop interfaces to access FirebaseAuth (#1501).

# 5.0.2
- [fixed] Fix an issue where JWT date timestamps weren't parsed correctly. (#1319)
- [fixed] Fix an issue where anonymous accounts weren't correctly promoted to
  non-anonymous when linked with passwordless email auth accounts. (#1383)
- [fixed] Fix an exception from using an invalidated NSURLSession. (#1261)
- [fixed] Fix a data race issue caught by the sanitizer. (#1446)

# 5.0.1
- [fixed] Restore 4.x level of support for extensions (#1357).

# 5.0.0
- [added] Adds APIs for phone Auth testing to bypass the verification flow (#1192).
- [feature] Changes the callback block signature for sign in and create user methods
  to provide an AuthDataResult that includes the user and user info (#1123, #1186).
- [changed] Removes GoogleToolboxForMac dependency (#1175).
- [removed] Removes miscellaneous deprecated APIs (#1188, #1200).

# 4.6.1
- [fixed] Fixes crash which occurred when certain Firebase IDTokens were being parsed (#1076).

# 4.6.0
- [added] Adds `getIDTokenResultWithCompletion:` and `getIDTokenResultForcingRefresh:completion:` APIs which
  call back with an AuthTokenResult object. The Auth token result object contains the ID token JWT string and other properties associated with the token including the decoded available payload claims (#1004).
- [added] Adds the `updateCurrentUser:completion:` API which sets the currentUser on the calling Auth instance to the provided user object (#1018).
- [added] Adds client-side validation to prevent setting `handleCodeInApp` to false when performing
  email-link authentication. If `handleCodeInApp` is set to false an invalid argument exception
  is thrown (#931).
- [added] Adds support for passing the deep link (which is embedded in the sign-in link sent via email) to the
  `signInWithEmail:link:completion:` and `isSignInWithEmailLink:` methods during an
  email/link sign-in flow (#1023).

# 4.5.0
- [added] Adds new API which provides a way to determine the sign-in methods associated with an
  email address.
- [added] Adds new API which allows authentication using only an email link (Passwordless Authentication
  with email link).

# 4.4.4
- [fixed] Addresses CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF warnings that surface in newer versions of
  Xcode and CocoaPods.
- [fixed] Improves FIRUser documentation with clear message explaining when Firebase Auth attempts to validate
  users and what happens when an invalidated user is detected (#694) .

# 4.4.3
- [added] Adds an explicit dependency on CoreGraphics from Firebase Auth.

# 4.4.2
- [fixed] Fixes bug where the FIRAuthResult object returned following a Phone Number authentication
  always contained a nil FIRAdditionalUserInfo object. Now the FIRAdditionalUserInfo object is
  never nil and its newUser field is populated correctly.

# 4.4.0
- [fixed] Adds new APIs which return an AuthDataResult object after successfully creating an
  Email/Password user, signing in anonymously, signing in with Email/Password and signing
  in with Custom Token. The AuthDataResult object contains the new user and additional
  information pertaining to the new user.

# 4.3.2
- [fixed] Improves error handling for the phone number sign-in reCAPTCHA flow.
- [fixed] Improves error handling for phone number linking flow.
- [fixed] Fixes issue where after linking an anonymous user to a phone number the user remained
  anonymous.

# 4.3.1
- [changed] Internal clean up.

# 4.3.0
- [added] Provides account creation and last sign-in dates as metadata to the user
  object.
- [added] Returns more descriptive errors for some error cases of the phone number
  sign-in reCAPTCHA flow.
- [fixed] Fixes an issue that invalid users were not automatically signed out earlier.
- [fixed] Fixes an issue that ID token listeners were not fired in some cases.

# 4.2.1
- [fixed] Fixes a threading issue in phone number auth that completion block was not
  executed on the main thread in some error cases.

# 4.2.0
- [added] Adds new phone number verification API which makes use of an intelligent reCAPTCHA to verify the application.

# 4.1.1
- [changed] Improves some method documentation in headers.

# 4.1.0
- [added] Allows the app to handle continue URL natively, e.g., from password reset
  email.
- [added] Allows the app to set language code, e.g., for sending password reset email.
- [fixed] Fixes an issue that user's phone number did not persist on client.
- [fixed] Fixes an issue that recover email action code type was reported as unknown.
- [feature] Improves app start-up time by moving initialization off from the main
  thread.
- [fixed] Better reports missing email error when creating a new password user.
- [fixed] Changes console message logging levels to be more consistent with other
  Firebase products on the iOS platform.

# 4.0.0
- [added] Adds Phone Number Authentication.
- [added] Adds support for generic OAuth2 identity providers.
- [added] Adds methods that return additional user data from identity providers if
  available when authenticating users.
- [added] Improves session management by automatically refreshing tokens if possible
  and signing out users if the session is detected invalidated, for example,
  after the user changed password or deleted account from another device.
- [fixed] Fixes an issue that reauthentication creates new user account if the user
  credential is valid but does not match the currently signed in user.
- [fixed] Fixes an issue that the "password" provider is not immediately listed on the
  client side after adding a password to an account.
- [changed] Changes factory methods to return non-null FIRAuth instances or raises an
  exception, instead of returning nullable instances.
- [changed] Changes auth state change listener to only be triggered when the user changes.
- [added] Adds a new listener which is triggered whenever the ID token is changed.
- [changed] Switches ERROR_EMAIL_ALREADY_IN_USE to
  ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL when the email used in the
  signInWithCredential: call is already in use by another account.
- [deprecated] Deprecates FIREmailPasswordAuthProvider in favor of FIREmailAuthProvider.
- [deprecated] Deprecates getTokenWithCompletion in favor of getIDTokenWithCompletion on
  FIRUser.
- [fixed] Changes Swift API names to better align with Swift convention.

# 3.1.1
- [added] Allows handling of additional errors when sending OOB action emails. The
  server can respond with the following new error messages:
  INVALID_MESSAGE_PAYLOAD,INVALID_SENDER and INVALID_RECIPIENT_EMAIL.
- [fixed] Removes incorrect reference to FIRAuthErrorCodeCredentialTooOld in FIRUser.h.
- [added] Provides additional error information from server if available.

# 3.1.0
- [added] Adds FIRAuth methods that enable the app to follow up with user actions
  delivered by email, such as verifying email address or reset password.
- [fixed] No longer applies the keychain workaround introduced in v3.0.5 on iOS 10.2
  simulator or above since the issue has been fixed.
- [fixed] Fixes nullability compilation warnings when used in Swift.
- [fixed] Better reports missing password error.

# 3.0.6
- [changed] Switches to depend on open sourced GoogleToolboxForMac and GTMSessionFetcher.
- [fixed] Improves logging of keychain error when initializing.

# 3.0.5
- [fixed] Works around a keychain issue in iOS 10 simulator.
- [fixed] Reports the correct error for invalid email when signing in with email and
  password.

# 3.0.4
- [fixed] Fixes a race condition bug that could crash the app with an exception from
  NSURLSession on iOS 9.

# 3.0.3
- [added] Adds documentation for all possible errors returned by each method.
- [fixed] Improves error handling and messages for a variety of error conditions.
- [fixed] Whether or not a user is considered anonymous is now consistent with other
  platforms.
- [changed] A saved signed in user is now siloed between different Firebase projects
  within the same app.

# 3.0.2
- Initial public release.
