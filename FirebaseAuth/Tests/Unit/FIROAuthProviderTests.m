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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthUIDelegate.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIROAuthProvider.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/AuthProvider/OAuth/FIROAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthRequestConfiguration.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthURLPresenter.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthWebUtils.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeAppCheck.h"
#import "FirebaseAuth/Tests/Unit/OCMStubRecorder+FIRAuthUnitTests.h"

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 1;

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
static NSString *const kFakeRedirectURLResponseURL =
    @"://firebaseauth/"
    @"link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3FauthType%"
    @"3DsignInWithRedirect%26link%3D";

/** @var kFakeRedirectURLBaseErrorString
    @brief The base for a fake redirect URL string that contains an error.
 */
static NSString *const kFakeRedirectURLBaseErrorString =
    @"com.googleusercontent.apps.123456://fire"
     "baseauth/link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3f";

/** @var kNetworkRequestFailedErrorString
    @brief The error message returned if a network request failure occurs within the web context.
 */
static NSString *const kNetworkRequestFailedErrorString =
    @"firebaseError%3D%257B%2522code%2"
     "522%253A%2522auth%252Fnetwork-request-failed%2522%252C%2522message%2522%253A%2522The%"
     "2520netwo"
     "rk%2520request%2520failed%2520.%2522%257D%26authType%3DsignInWithRedirect";

/** @var kInvalidClientIDString
    @brief The error message returned if the client ID used is invalid.
 */
static NSString *const kInvalidClientIDString =
    @"firebaseError%3D%257B%2522code%2522%253A%2522auth"
     "%252Finvalid-oauth-client-id%2522%252C%2522message%2522%253A%2522The%2520OAuth%2520client%"
     "2520"
     "ID%2520provided%2520is%2520either%2520invalid%2520or%2520does%2520not%2520match%2520the%"
     "2520sp"
     "ecified%2520API%2520key.%2522%257D%26authType%3DsignInWithRedirect";

/** @var kInternalErrorString
    @brief The error message returned if there is an internal error within the web context.
 */
static NSString *const kInternalErrorString =
    @"firebaseError%3D%257B%2522code%2522%253"
     "A%2522auth%252Finternal-error%2522%252C%2522message%2522%253A%2522Internal%2520error%2520.%"
     "252"
     "2%257D%26authType%3DsignInWithRedirect";

/** @var kUnknownErrorString
    @brief The error message returned if an unknown error is returned from the web context.
 */
static NSString *const kUnknownErrorString =
    @"firebaseError%3D%257B%2522code%2522%253A%2522auth%2"
     "52Funknown-error-id%2522%252C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%"
     "2520pr"
     "ovided%2520is%2520either%2520invalid%2520or%2520does%2520not%2520match%2520the%2520specified%"
     "2"
     "520API%2520key.%2522%257D%26authType%3DsignInWithRedirect";

@interface FIROAuthProviderTests : XCTestCase

@end

@implementation FIROAuthProviderTests {
  /** @var _mockBackend
      @brief The mock @c FIRAuthBackendImplementation.
   */
  id _mockBackend;

  /** @var _provider
      @brief The @c FIROAuthProvider instance under test.
   */
  FIROAuthProvider *_provider;

  /** @var _mockAuth
      @brief The mock @c FIRAuth instance associated with @c _provider.
   */
  id _mockAuth;

#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
  /** @var _mockURLPresenter
      @brief The mock @c FIRAuthURLPresenter instance associated with @c _mockAuth.
   */
  id _mockURLPresenter;
#endif  // !defined(TARGET_OS_VISION) || !TARGET_OS_VISION

  /** @var _mockApp
      @brief The mock @c FIRApp instance associated with @c _mockAuth.
   */
  id _mockApp;

  /** @var _mockOptions
      @brief The mock @c FIROptions instance associated with @c _mockApp.
   */
  id _mockOptions;

  /** @var _mockRequestConfiguration
      @brief The mock @c FIRAuthRequestConfiguration instance associated with @c _mockAuth.
   */
  id _mockRequestConfiguration;
}

- (void)setUp {
  [super setUp];
  _mockBackend = OCMProtocolMock(@protocol(FIRAuthBackendImplementation));
  [FIRAuthBackend setBackendImplementation:_mockBackend];
  _mockAuth = OCMClassMock([FIRAuth class]);
  _mockApp = OCMClassMock([FIRApp class]);
  OCMStub([_mockAuth app]).andReturn(_mockApp);
  _mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([(FIRApp *)_mockApp options]).andReturn(_mockOptions);
  OCMStub([_mockOptions googleAppID]).andReturn(kFakeFirebaseAppID);
#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
  _mockURLPresenter = OCMClassMock([FIRAuthURLPresenter class]);
  OCMStub([_mockAuth authURLPresenter]).andReturn(_mockURLPresenter);
#endif  // !defined(TARGET_OS_VISION) || !TARGET_OS_VISION
  _mockRequestConfiguration = OCMClassMock([FIRAuthRequestConfiguration class]);
  OCMStub([_mockAuth requestConfiguration]).andReturn(_mockRequestConfiguration);
  OCMStub([_mockRequestConfiguration APIKey]).andReturn(kFakeAPIKey);
}

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
  XCTAssertEqualObjects(OAuthCredential.fullName, fullName);
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

/** @fn testObtainingOAuthProvider
    @brief Tests the correct creation of an FIROAuthProvider instance.
 */
- (void)testObtainingOAuthProvider {
  id mockAuth = OCMClassMock([FIRAuth class]);
  id mockApp = OCMClassMock([FIRApp class]);
  OCMStub([mockAuth app]).andReturn(mockApp);
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions clientID]).andReturn(kFakeClientID);
  OCMStub([mockOptions googleAppID]).andReturn(kFakeFirebaseAppID);
  OCMStub([(FIRApp *)mockApp options]).andReturn(mockOptions);
  FIROAuthProvider *OAuthProvider = [FIROAuthProvider providerWithProviderID:kFakeProviderID
                                                                        auth:mockAuth];
  XCTAssertTrue([OAuthProvider isKindOfClass:[FIROAuthProvider class]]);
  XCTAssertEqualObjects(OAuthProvider.providerID, kFakeProviderID);
}

#if !defined(TARGET_OS_VISION) || !TARGET_OS_VISION

/** @fn testGetCredentialWithUIDelegateWithClientID
    @brief Tests a successful invocation of @c getCredentialWithUIDelegte:completion:
 */
- (void)testGetCredentialWithUIDelegateWithClientID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeReverseClientID
                                 stringByAppendingString:kFakeRedirectURLResponseURL]];
        // Add fake OAuthResponse to callback.
        [redirectURL appendString:kFakeOAuthResponseURL];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      getCredentialWithUIDelegate:mockUIDelegate
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         XCTAssertTrue([NSThread isMainThread]);
                         XCTAssertNil(error);
                         XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
                         FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
                         XCTAssertEqualObjects(kFakeOAuthResponseURL,
                                               OAuthCredential.OAuthResponseURLString);
                         [expectation fulfill];
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateWithTenantID
    @brief Tests a successful invocation of @c getCredentialWithUIDelegte:completion:
 */
- (void)testGetCredentialWithUIDelegateWithTenantID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);
  OCMStub([_mockAuth tenantID]).andReturn(kFakeTenantID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertEqualObjects(params[@"tid"], kFakeTenantID);
        XCTAssertNotNil(params[@"v"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeReverseClientID
                                 stringByAppendingString:kFakeRedirectURLResponseURL]];
        // Add fake OAuthResponse to callback.
        [redirectURL appendString:kFakeOAuthResponseURL];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      getCredentialWithUIDelegate:mockUIDelegate
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         XCTAssertTrue([NSThread isMainThread]);
                         XCTAssertNil(error);
                         XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
                         FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
                         XCTAssertEqualObjects(kFakeOAuthResponseURL,
                                               OAuthCredential.OAuthResponseURLString);
                         [expectation fulfill];
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateUserCancellationWithClientID
    @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegte:completion: due to user
        cancelation.
 */
- (void)testGetCredentialWithUIDelegateUserCancellationWithClientID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeReverseClientID
                                 stringByAppendingString:kFakeRedirectURLResponseURL]];
        // Add fake OAuthResponse to callback.
        [redirectURL appendString:kFakeOAuthResponseURL];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];

        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(nil, [FIRAuthErrorUtils webContextCancelledErrorWithMessage:nil]);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider getCredentialWithUIDelegate:mockUIDelegate
                              completion:^(FIRAuthCredential *_Nullable credential,
                                           NSError *_Nullable error) {
                                XCTAssertTrue([NSThread isMainThread]);
                                XCTAssertNil(credential);
                                XCTAssertEqual(FIRAuthErrorCodeWebContextCancelled, error.code);
                                [expectation fulfill];
                              }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateNetworkRequestFailedWithClientID
    @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegte:completion: due to a
        failed network request within the web context.
 */
- (void)testGetCredentialWithUIDelegateNetworkRequestFailedWithClientID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL =
            [NSMutableString stringWithString:kFakeRedirectURLBaseErrorString];
        [redirectURL appendString:kNetworkRequestFailedErrorString];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];

        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider getCredentialWithUIDelegate:mockUIDelegate
                              completion:^(FIRAuthCredential *_Nullable credential,
                                           NSError *_Nullable error) {
                                XCTAssertTrue([NSThread isMainThread]);
                                XCTAssertNil(credential);
                                XCTAssertEqual(FIRAuthErrorCodeWebNetworkRequestFailed, error.code);
                                [expectation fulfill];
                              }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateInternalErrorWithClientID
    @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegte:completion: due to an
        internal error within the web context.
 */
- (void)testGetCredentialWithUIDelegateInternalErrorWithClientID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL =
            [NSMutableString stringWithString:kFakeRedirectURLBaseErrorString];
        // Add internal error string to redirect URL.
        [redirectURL appendString:kInternalErrorString];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];

        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider getCredentialWithUIDelegate:mockUIDelegate
                              completion:^(FIRAuthCredential *_Nullable credential,
                                           NSError *_Nullable error) {
                                XCTAssertTrue([NSThread isMainThread]);
                                XCTAssertNil(credential);
                                XCTAssertEqual(FIRAuthErrorCodeWebInternalError, error.code);
                                [expectation fulfill];
                              }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateInvalidClientID
    @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegte:completion: due to an
        use of an invalid client ID.
 */
- (void)testGetCredentialWithUIDelegateInvalidClientID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL =
            [NSMutableString stringWithString:kFakeRedirectURLBaseErrorString];
        // Add invalid client ID error to redirect URL.
        [redirectURL appendString:kInvalidClientIDString];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];

        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider getCredentialWithUIDelegate:mockUIDelegate
                              completion:^(FIRAuthCredential *_Nullable credential,
                                           NSError *_Nullable error) {
                                XCTAssertTrue([NSThread isMainThread]);
                                XCTAssertNil(credential);
                                XCTAssertEqual(FIRAuthErrorCodeInvalidClientID, error.code);
                                [expectation fulfill];
                              }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateUnknownErrorWithClientID
    @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegte:completion: due to an
        unknown error.
 */
- (void)testGetCredentialWithUIDelegateUnknownErrorWithClientID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL =
            [NSMutableString stringWithString:kFakeRedirectURLBaseErrorString];
        // Add unknown error to redirect URL.
        [redirectURL appendString:kUnknownErrorString];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];

        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider getCredentialWithUIDelegate:mockUIDelegate
                              completion:^(FIRAuthCredential *_Nullable credential,
                                           NSError *_Nullable error) {
                                XCTAssertTrue([NSThread isMainThread]);
                                XCTAssertNil(credential);
                                XCTAssertEqual(FIRAuthErrorCodeWebSignInUserInteractionFailure,
                                               error.code);
                                [expectation fulfill];
                              }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateWithFirebaseAppID
    @brief Tests a successful invocation of @c getCredentialWithUIDelegte:completion:
 */
- (void)testGetCredentialWithUIDelegateWithFirebaseAppID {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeEncodedFirebaseAppID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"appId"], kFakeFirebaseAppID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeEncodedFirebaseAppID
                                 stringByAppendingString:kFakeRedirectURLResponseURL]];
        // Add fake OAuthResponse to callback.
        [redirectURL appendString:kFakeOAuthResponseURL];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      getCredentialWithUIDelegate:mockUIDelegate
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         XCTAssertTrue([NSThread isMainThread]);
                         XCTAssertNil(error);
                         XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
                         FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
                         XCTAssertEqualObjects(kFakeOAuthResponseURL,
                                               OAuthCredential.OAuthResponseURLString);
                         [expectation fulfill];
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateWithFirebaseAppIDWhileClientIdPresent
    @brief Tests a successful invocation of @c getCredentialWithUIDelegte:completion: when the
   client ID is present in the plist file, but the encoded app ID is the registered custom URL
   scheme.
 */
- (void)testGetCredentialWithUIDelegateWithFirebaseAppIDWhileClientIdPresent {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeEncodedFirebaseAppID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"appId"], kFakeFirebaseAppID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeEncodedFirebaseAppID
                                 stringByAppendingString:kFakeRedirectURLResponseURL]];
        // Add fake OAuthResponse to callback.
        [redirectURL appendString:kFakeOAuthResponseURL];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      getCredentialWithUIDelegate:mockUIDelegate
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         XCTAssertTrue([NSThread isMainThread]);
                         XCTAssertNil(error);
                         XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
                         FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
                         XCTAssertEqualObjects(kFakeOAuthResponseURL,
                                               OAuthCredential.OAuthResponseURLString);
                         [expectation fulfill];
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateUseEmulator
    @brief Tests a successful invocation of @c getCredentialWithUIDelegte:completion: when using the
   emulator.
 */
- (void)testGetCredentialWithUIDelegateUseEmulator {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  NSString *emulatorHostAndPort =
      [NSString stringWithFormat:@"%@:%@", kFakeEmulatorHost, kFakeEmulatorPort];
  OCMStub([_mockRequestConfiguration emulatorHostAndPort]).andReturn(emulatorHostAndPort);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"http");
        XCTAssertEqualObjects(presentURL.host, kFakeEmulatorHost);
        XCTAssertEqualObjects([presentURL.port stringValue], kFakeEmulatorPort);
        XCTAssertEqualObjects(presentURL.path, @"/emulator/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertNotNil(params[@"v"]);
        XCTAssertNil(params[@"tid"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertNil(appCheckToken);
        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeReverseClientID
                                 stringByAppendingString:kFakeRedirectURLResponseURL]];
        // Add fake OAuthResponse to callback.
        [redirectURL appendString:kFakeOAuthResponseURL];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      getCredentialWithUIDelegate:mockUIDelegate
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         XCTAssertTrue([NSThread isMainThread]);
                         XCTAssertNil(error);
                         XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
                         FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
                         XCTAssertEqualObjects(kFakeOAuthResponseURL,
                                               OAuthCredential.OAuthResponseURLString);
                         [expectation fulfill];
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testGetCredentialWithUIDelegateWithAppCheckToken
    @brief Tests a successful invocation of @c getCredentialWithUIDelegte:completion:
 */
- (void)testGetCredentialWithUIDelegateWithAppCheckToken {
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub(ClassMethod([mockBundle mainBundle])).andReturn(mockBundle);
  OCMStub([mockBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]).andReturn(@[
    @{@"CFBundleURLSchemes" : @[ kFakeReverseClientID ]}
  ]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(kFakeBundleID);
  OCMStub([_mockAuth tenantID]).andReturn(kFakeTenantID);

  OCMStub([_mockOptions clientID]).andReturn(kFakeClientID);
  _provider = [FIROAuthProvider providerWithProviderID:kFakeProviderID auth:_mockAuth];

  FIRFakeAppCheck *fakeAppCheck = [[FIRFakeAppCheck alloc] init];
  OCMStub([_mockRequestConfiguration appCheck]).andReturn(fakeAppCheck);

  OCMExpect([_mockBackend getProjectConfig:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(
          ^(FIRGetProjectConfigRequest *request, FIRGetProjectConfigResponseCallback callback) {
            XCTAssertNotNil(request);
            dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
              id mockGetProjectConfigResponse = OCMClassMock([FIRGetProjectConfigResponse class]);
              OCMStub([mockGetProjectConfigResponse authorizedDomains]).andReturn(@[
                kFakeAuthorizedDomain
              ]);
              callback(mockGetProjectConfigResponse, nil);
            });
          });

  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

  // Expect view controller presentation by UIDelegate.
  OCMExpect([_mockURLPresenter presentURL:OCMOCK_ANY
                               UIDelegate:mockUIDelegate
                          callbackMatcher:OCMOCK_ANY
                               completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentURL` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        NSURL *presentURL = unretainedArgument;
        XCTAssertEqualObjects(presentURL.scheme, @"https");
        XCTAssertEqualObjects(presentURL.host, kFakeAuthorizedDomain);
        XCTAssertEqualObjects(presentURL.path, @"/__/auth/handler");
        NSDictionary *params = [FIRAuthWebUtils dictionaryWithHttpArgumentsString:presentURL.query];
        XCTAssertEqualObjects(params[@"ibi"], kFakeBundleID);
        XCTAssertEqualObjects(params[@"clientId"], kFakeClientID);
        XCTAssertEqualObjects(params[@"apiKey"], kFakeAPIKey);
        XCTAssertEqualObjects(params[@"authType"], @"signInWithRedirect");
        XCTAssertEqualObjects(params[@"tid"], kFakeTenantID);
        XCTAssertNotNil(params[@"v"]);
        NSString *appCheckToken = presentURL.fragment;
        XCTAssertEqualObjects(appCheckToken, [@"fac=" stringByAppendingString:kFakeAppCheckToken]);

        // `callbackMatcher` is at index 4
        [invocation getArgument:&unretainedArgument atIndex:4];
        FIRAuthURLCallbackMatcher callbackMatcher = unretainedArgument;
        NSMutableString *redirectURL = [NSMutableString
            stringWithString:[kFakeReverseClientID
                                 stringByAppendingString:kFakeRedirectURLResponseURL]];
        // Add fake OAuthResponse to callback.
        [redirectURL appendString:kFakeOAuthResponseURL];
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher([NSURL URLWithString:redirectURL]));
        [redirectURL appendString:@"%26eventId%3D"];
        [redirectURL appendString:params[@"eventId"]];
        NSURLComponents *originalComponents = [[NSURLComponents alloc] initWithString:redirectURL];
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher([originalComponents URL]));
        NSURLComponents *components = [originalComponents copy];
        components.query = @"https";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.host = @"badhost";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.path = @"badpath";
        XCTAssertFalse(callbackMatcher([components URL]));
        components = [originalComponents copy];
        components.query = @"badquery";
        XCTAssertFalse(callbackMatcher([components URL]));

        // `completion` is at index 5
        [invocation getArgument:&unretainedArgument atIndex:5];
        FIRAuthURLPresentationCompletion completion = unretainedArgument;
        dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
          completion(originalComponents.URL, nil);
        });
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider
      getCredentialWithUIDelegate:mockUIDelegate
                       completion:^(FIRAuthCredential *_Nullable credential,
                                    NSError *_Nullable error) {
                         XCTAssertTrue([NSThread isMainThread]);
                         XCTAssertNil(error);
                         XCTAssertTrue([credential isKindOfClass:[FIROAuthCredential class]]);
                         FIROAuthCredential *OAuthCredential = (FIROAuthCredential *)credential;
                         XCTAssertEqualObjects(kFakeOAuthResponseURL,
                                               OAuthCredential.OAuthResponseURLString);
                         [expectation fulfill];
                       }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

#endif  // !defined(TARGET_OS_VISION) || !TARGET_OS_VISION

@end

#endif  // TARGET_OS_IOS
