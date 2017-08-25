# v4.1.1
- Improves some method documentation in headers.

# v4.1.0
- Allows the app to handle continue URL natively, e.g., from password reset
  email.
- Allows the app to set language code, e.g., for sending password reset email.
- Fixes an issue that user's phone number did not persist on client.
- Fixes an issue that recover email action code type was reported as unknown.
- Improves app start-up time by moving initialization off from the main
  thread.
- Better reports missing email error when creating a new password user.
- Changes console message logging levels to be more consistent with other
  Firebase products on the iOS platform.

# 2017-05-17 -- v4.0.0
- Adds Phone Number Authentication.
- Adds support for generic OAuth2 identity providers.
- Adds methods that return additional user data from identity providers if
  available when authenticating users.
- Improves session management by automatically refreshing tokens if possible
  and signing out users if the session is detected invalidated, for example,
  after the user changed password or deleted account from another device.
- Fixes an issue that reauthentication creates new user account if the user
  credential is valid but does not match the currently signed in user.
- Fixes an issue that the "password" provider is not immediately listed on the
  client side after adding a password to an account.
- Changes factory methods to return non-null FIRAuth instances or raises an
  exception, instead of returning nullable instances.
- Changes auth state change listener to only be triggered when the user changes.
- Adds a new listener which is triggered whenever the ID token is changed.
- Switches ERROR_EMAIL_ALREADY_IN_USE to
  ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL when the email used in the
  signInWithCredential: call is already in use by another account.
- Deprecates FIREmailPasswordAuthProvider in favor of FIREmailAuthProvider.
- Deprecates getTokenWithCompletion in favor of getIDTokenWithCompletion on
  FIRUser.
- Changes Swift API names to better align with Swift convention.

# 2017-02-06 -- v3.1.1
- Allows handling of additional errors when sending OOB action emails. The
  server can respond with the following new error messages:
  INVALID_MESSAGE_PAYLOAD,INVALID_SENDER and INVALID_RECIPIENT_EMAIL.
- Removes incorrect reference to FIRAuthErrorCodeCredentialTooOld in FIRUser.h.
- Provides additional error information from server if available.

# 2016-12-13 -- v3.1.0
- Adds FIRAuth methods that enable the app to follow up with user actions
  delivered by email, such as verifying email address or reset password.
- No longer applies the keychain workaround introduced in v3.0.5 on iOS 10.2
  simulator or above since the issue has been fixed.
- Fixes nullability compilation warnings when used in Swift.
- Better reports missing password error.

# 2016-10-24 -- v3.0.6
- Switches to depend on open sourced GoogleToolboxForMac and GTMSessionFetcher.
- Improves logging of keychain error when initializing.

# 2016-09-14 -- v3.0.5
- Works around a keychain issue in iOS 10 simulator.
- Reports the correct error for invalid email when signing in with email and
  password.

# 2016-07-18 -- v3.0.4
- Fixes a race condition bug that could crash the app with an exception from
  NSURLSession on iOS 9.

# 2016-06-20 -- v3.0.3
- Adds documentation for all possible errors returned by each method.
- Improves error handling and messages for a variety of error conditions.
- Whether or not an user is considered anonymous is now consistent with other
  platforms.
- A saved signed in user is now siloed between different Firebase projects
  within the same app.

# 2016-05-18 -- v3.0.2
- Initial public release.
