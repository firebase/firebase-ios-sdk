/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <XCTest/XCTest.h>

@import FirebaseAuth;
@import FirebaseCore;

/** @var kFakeAuthorizedDomain
    @brief A fake authorized domain for the app.
 */
static NSString *const kFakeAuthorizedDomain = @"test.firebaseapp.com";

/** @var kFakeBundleID
    @brief A fake bundle ID.
 */
static NSString *const kFakeBundleID = @"com.firebaseapp.example";

/** @var kFakeAccessToken
    @brief A fake access token for testing.
 */
static NSString *const kFakeAccessToken = @"fakeAccessToken";

/** @var kFakeIDToken
    @brief A fake ID token for testing.
 */
static NSString *const kFakeIDToken = @"fakeIDToken";

/** @var kFakeProviderID
    @brief A fake provider ID for testing.
 */
static NSString *const kFakeProviderID = @"fakeProviderID";

/** @var kFakeGivenName
    @brief A fake given name for testing.
 */
static NSString *const kFakeGivenName = @"fakeGivenName";

/** @var kFakeFamilyName
    @brief A fake family name for testing.
 */
static NSString *const kFakeFamilyName = @"fakeFamilyName";

/** @var kFakeAPIKey
    @brief A fake API key.
 */
static NSString *const kFakeAPIKey = @"asdfghjkl";

/** @var kFakeEmulatorHost
    @brief A fake emulator host.
 */
static NSString *const kFakeEmulatorHost = @"emulatorhost";

/** @var kFakeEmulatorPort
    @brief A fake emulator port.
 */
static NSString *const kFakeEmulatorPort = @"12345";

/** @var kFakeClientID
    @brief A fake client ID.
 */
static NSString *const kFakeClientID = @"123456.apps.googleusercontent.com";

/** @var kFakeReverseClientID
    @brief The dot-reversed version of the fake client ID.
 */
static NSString *const kFakeReverseClientID = @"com.googleusercontent.apps.123456";

/** @var kFakeFirebaseAppID
    @brief A fake Firebase app ID.
 */
static NSString *const kFakeFirebaseAppID = @"1:123456789:ios:123abc456def";

/** @var kFakeEncodedFirebaseAppID
    @brief A fake encoded Firebase app ID to be used as a custom URL scheme.
 */
static NSString *const kFakeEncodedFirebaseAppID = @"app-1-123456789-ios-123abc456def";

/** @var kFakeTenantID
    @brief A fake tenant ID.
 */
static NSString *const kFakeTenantID = @"tenantID";

/** @var kFakeOAuthResponseURL
    @brief A fake OAuth response URL used in test.
 */
static NSString *const kFakeOAuthResponseURL = @"fakeOAuthResponseURL";

/** @var kFakeRedirectURLResponseURL
    @brief A fake callback URL (minus the scheme) containing a fake response URL.
 */

@interface FIROAuthProviderTests : XCTestCase

@end

@implementation FIROAuthProviderTests

/** @fn testObtainingOAuthCredentialNoIDToken
    @brief Tests the correct creation of an OAuthCredential without an IDToken.
 */
- (void)testObtainingOAuthCredentialNoIDToken {
  FIRAuthCredential *credential = [FIROAuthProvider credentialWithProviderID:kFakeProviderID
                                                                 accessToken:kFakeAccessToken];
  XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
  FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
  XCTAssertEqualObjects(OAuthCredential.accessToken, kFakeAccessToken);
  XCTAssertEqualObjects(OAuthCredential.provider, kFakeProviderID);
  XCTAssertNil(OAuthCredential.IDToken);
}

/** @fn testObtainingOAuthCredentialWithFullName
    @brief Tests the correct creation of an OAuthCredential with a fullName.
 */
- (void)testObtainingOAuthCredentialWithFullName {
  NSPersonNameComponents *fullName = [[NSPersonNameComponents alloc] init];
  fullName.givenName = kFakeGivenName;
  fullName.familyName = kFakeFamilyName;
  FIRAuthCredential *credential = [FIROAuthProvider appleCredentialWithIDToken:kFakeIDToken
                                                                      rawNonce:nil
                                                                      fullName:fullName];

  XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
  FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
  XCTAssertEqualObjects(OAuthCredential.provider, @"apple.com");
  XCTAssertEqualObjects(OAuthCredential.IDToken, kFakeIDToken);
  XCTAssertNil(OAuthCredential.accessToken);
}

/** @fn testObtainingOAuthCredentialWithIDToken
    @brief Tests the correct creation of an OAuthCredential with an IDToken
 */
- (void)testObtainingOAuthCredentialWithIDToken {
  FIRAuthCredential *credential = [FIROAuthProvider credentialWithProviderID:kFakeProviderID
                                                                     IDToken:kFakeIDToken
                                                                 accessToken:kFakeAccessToken];
  XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
  FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
  XCTAssertEqualObjects(OAuthCredential.accessToken, kFakeAccessToken);
  XCTAssertEqualObjects(OAuthCredential.provider, kFakeProviderID);
  XCTAssertEqualObjects(OAuthCredential.IDToken, kFakeIDToken);
}

@end

#endif  // TARGET_OS_IOS
