/*
 * Copyright 2019 Google
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

#import <XCTest/XCTest.h>

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <FirebaseInstanceID/FIRInstanceID_Private.h>
#import <OCMock/OCMock.h>

#import "Firebase/InstanceID/FIRInstanceIDAuthService.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences+Internal.h"
#import "Firebase/InstanceID/FIRInstanceIDConstants.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPair.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPairStore.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenInfo.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenManager.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"
#import "Firebase/InstanceID/NSError+FIRInstanceID.h"

static NSString *const kFakeIID = @"12345678";
static NSString *const kFakeAPNSToken = @"this is a fake apns token";
static NSString *const kAuthorizedEntity = @"test-audience";
static NSString *const kScope = @"test-scope";
static NSString *const kToken = @"test-token";
static FIRInstanceIDTokenInfo *sTokenInfo;
// Faking checkin calls
static NSString *const kDeviceAuthId = @"device-id";
static NSString *const kSecretToken = @"secret-token";
static NSString *const kVersionInfo = @"1.0";
// FIRApp configuration.
static NSString *const kGCMSenderID = @"correct_gcm_sender_id";
static NSString *const kGoogleAppID = @"1:123:ios:123abc";

@interface FIRInstanceID (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRInstanceIDTokenManager *tokenManager;
@property(nonatomic, readwrite, strong) FIRInstanceIDKeyPairStore *keyPairStore;
@property(nonatomic, readwrite, copy) NSString *fcmSenderID;

- (NSInteger)retryIntervalToFetchDefaultToken;
- (BOOL)isFCMAutoInitEnabled;
- (void)didCompleteConfigure;
- (NSString *)cachedTokenIfAvailable;
- (void)deleteIdentityWithHandler:(FIRInstanceIDDeleteHandler)handler;
+ (FIRInstanceID *)instanceIDForTests;
- (void)defaultTokenWithHandler:(FIRInstanceIDTokenHandler)handler;
- (instancetype)initPrivately;
- (void)start;
+ (int64_t)maxRetryCountForDefaultToken;
+ (int64_t)minIntervalForDefaultTokenRetry;
+ (int64_t)maxRetryIntervalForDefaultTokenInSeconds;

@end

@interface FIRInstanceIDTest : XCTestCase

@property(nonatomic, readwrite, assign) BOOL hasCheckinInfo;
@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;
@property(nonatomic, readwrite, strong) id mockInstanceID;
@property(nonatomic, readwrite, strong) id mockTokenManager;
@property(nonatomic, readwrite, strong) id mockKeyPairStore;
@property(nonatomic, readwrite, strong) id mockAuthService;
@property(nonatomic, readwrite, strong) id<NSObject> tokenRefreshNotificationObserver;

@property(nonatomic, readwrite, copy) FIRInstanceIDTokenHandler newTokenCompletion;
@property(nonatomic, readwrite, copy) FIRInstanceIDDeleteTokenHandler deleteTokenCompletion;

@end

@implementation FIRInstanceIDTest

- (void)setUp {
  [super setUp];
  _instanceID = [[FIRInstanceID alloc] initPrivately];
  [_instanceID start];
  if (!sTokenInfo) {
    sTokenInfo = [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                    scope:kScope
                                                                    token:kToken
                                                               appVersion:nil
                                                            firebaseAppID:nil];
    sTokenInfo.cacheTime = [NSDate date];
  }
  [self mockInstanceIDObjects];
}

- (void)tearDown {
  [[NSNotificationCenter defaultCenter] removeObserver:self.tokenRefreshNotificationObserver];
  self.instanceID = nil;
  self.mockTokenManager = nil;
  self.mockInstanceID = nil;
  [super tearDown];
}

- (void)mockInstanceIDObjects {
  // Mock that we have valid checkin info. Individual tests can override this.
  self.hasCheckinInfo = YES;
  self.mockAuthService = OCMClassMock([FIRInstanceIDAuthService class]);

  [[[self.mockAuthService stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&self->_hasCheckinInfo];
  }] hasValidCheckinInfo];

  self.mockTokenManager = OCMClassMock([FIRInstanceIDTokenManager class]);
  [[[self.mockTokenManager stub] andReturn:self.mockAuthService] authService];

  self.mockKeyPairStore = OCMClassMock([FIRInstanceIDKeyPairStore class]);
  _instanceID.fcmSenderID = kAuthorizedEntity;
  self.mockInstanceID = OCMPartialMock(_instanceID);
  [self.mockInstanceID setTokenManager:self.mockTokenManager];
  [self.mockInstanceID setKeyPairStore:self.mockKeyPairStore];

  id instanceIDClassMock = OCMClassMock([FIRInstanceID class]);
  OCMStub(ClassMethod([instanceIDClassMock minIntervalForDefaultTokenRetry])).andReturn(2);
  OCMStub(ClassMethod([instanceIDClassMock maxRetryIntervalForDefaultTokenInSeconds]))
      .andReturn(10);
}

/**
 *  Tests that the FIRInstanceID's sharedInstance class method produces an instance of
 *  FIRInstanceID with an associated FIRInstanceIDTokenManager.
 */
- (void)testSharedInstance {
  // The shared instance should be `nil` before the app is configured.
  XCTAssertNil([FIRInstanceID instanceID]);

  // The shared instance relies on the default app being configured. Configure it.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  [FIRApp configureWithName:kFIRDefaultAppName options:options];
  FIRInstanceID *instanceID = [FIRInstanceID instanceID];
  XCTAssertNotNil(instanceID);
  XCTAssertNotNil(instanceID.tokenManager);

  // Ensure a second call returns the same instance as the first.
  FIRInstanceID *secondInstanceID = [FIRInstanceID instanceID];
  XCTAssertEqualObjects(instanceID, secondInstanceID);

  // Reset the default app for the next test.
  [FIRApp resetApps];
}

- (void)testFCMAutoInitEnabled {
  XCTAssertFalse([_instanceID isFCMAutoInitEnabled],
                 @"When FCM is not available, FCM Auto Init Enabled should be NO.");
}

- (void)testTokenShouldBeRefreshedIfCacheTokenNeedsToBeRefreshed {
  [[[self.mockInstanceID stub] andReturn:kToken] cachedTokenIfAvailable];
  [[[self.mockTokenManager stub] andReturnValue:@(YES)] checkForTokenRefreshPolicy];
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation){
  }] tokenWithAuthorizedEntity:[OCMArg any]
                         scope:[OCMArg any]
                       options:[OCMArg any]
                       handler:[OCMArg any]];

  [self.mockInstanceID didCompleteConfigure];
  OCMVerify([self.mockInstanceID defaultTokenWithHandler:nil]);
  XCTAssertEqualObjects([self.mockInstanceID token], kToken);
}

- (void)testTokenShouldBeRefreshedIfNoCacheTokenButAutoInitAllowed {
  [[[self.mockInstanceID stub] andReturn:nil] cachedTokenIfAvailable];
  [[[self.mockInstanceID stub] andReturnValue:@(YES)] isFCMAutoInitEnabled];
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation){
  }] tokenWithAuthorizedEntity:[OCMArg any]
                         scope:[OCMArg any]
                       options:[OCMArg any]
                       handler:[OCMArg any]];

  [self.mockInstanceID didCompleteConfigure];

  OCMVerify([self.mockInstanceID defaultTokenWithHandler:nil]);
}

- (void)testTokenIsDeletedAlongWithIdentity {
  [[[self.mockInstanceID stub] andReturnValue:@(YES)] isFCMAutoInitEnabled];
  [[[self.mockInstanceID stub] andDo:^(NSInvocation *invocation){
  }] tokenWithAuthorizedEntity:[OCMArg any]
                         scope:[OCMArg any]
                       options:[OCMArg any]
                       handler:[OCMArg any]];

  [self.mockInstanceID deleteIdentityWithHandler:^(NSError *_Nullable error) {
    XCTAssertNil([self.mockInstanceID token]);
  }];
}

- (void)testTokenIsFetchedDuringIIDGeneration {
  XCTestExpectation *tokenExpectation = [self
      expectationWithDescription:@"Token is refreshed when getID is called to avoid IID conflict."];
  NSError *error = nil;
  [[[self.mockKeyPairStore stub] andReturn:kFakeIID] appIdentityWithError:[OCMArg setTo:error]];

  [self.mockInstanceID getIDWithHandler:^(NSString *identity, NSError *error) {
    XCTAssertNotNil(identity);
    XCTAssertEqual(identity, kFakeIID);
    OCMVerify([self.mockInstanceID token]);
    [tokenExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:0.1
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Tests that when a new InstanceID token is successfully produced,
 *  the callback is invoked with a token that is not an empty string and with no error.
 */
- (void)testNewTokenSuccess {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  NSString *APNSKey = kFIRInstanceIDTokenOptionsAPNSKey;
  NSString *serverKey = kFIRInstanceIDTokenOptionsAPNSIsSandboxKey;

  [self stubKeyPairStoreToReturnValidKeypair];
  [self mockAuthServiceToAlwaysReturnValidCheckin];

  NSData *fakeAPNSDeviceToken = [kFakeAPNSToken dataUsingEncoding:NSUTF8StringEncoding];
  BOOL isSandbox = YES;
  NSDictionary *tokenOptions = @{
    APNSKey : fakeAPNSDeviceToken,
    serverKey : @(isSandbox),
  };

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    self.newTokenCompletion(kToken, nil);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kScope
                               keyPair:[OCMArg any]
                               options:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 NSDictionary *options = (NSDictionary *)obj;
                                 XCTAssertTrue([options[APNSKey] isEqual:fakeAPNSDeviceToken]);
                                 XCTAssertTrue([options[serverKey] isEqual:@(isSandbox)]);
                                 return YES;
                               }]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  [self.instanceID tokenWithAuthorizedEntity:kAuthorizedEntity
                                       scope:kScope
                                     options:tokenOptions
                                     handler:^(NSString *token, NSError *error) {
                                       XCTAssertNotNil(token);
                                       XCTAssertGreaterThan(token.length, 0);
                                       XCTAssertNil(error);
                                       [tokenExpectation fulfill];
                                     }];

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Get Token should fail if we do not have valid checkin info and are unable to
 *  retreive one.
 */
- (void)testNewTokenCheckinFailure {
  self.hasCheckinInfo = NO;

  __block FIRInstanceIDDeviceCheckinCompletion checkinHandler;
  [[[self.mockAuthService stub] andDo:^(NSInvocation *invocation) {
    if (checkinHandler) {
      FIRInstanceIDErrorCode code = kFIRInstanceIDErrorCodeUnknown;
      NSError *error = [NSError errorWithFIRInstanceIDErrorCode:code];
      checkinHandler(nil, error);
    }
  }] fetchCheckinInfoWithHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
       return (checkinHandler = obj) != nil;
     }]];

  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  NSDictionary *tokenOptions = @{
    kFIRInstanceIDTokenOptionsAPNSKey : [kFakeAPNSToken dataUsingEncoding:NSUTF8StringEncoding],
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(YES),
  };

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    self.newTokenCompletion(kToken, nil);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  [self.instanceID tokenWithAuthorizedEntity:kAuthorizedEntity
                                       scope:kScope
                                     options:tokenOptions
                                     handler:^(NSString *token, NSError *error) {
                                       XCTAssertNil(token);
                                       XCTAssertNotNil(error);
                                       [tokenExpectation fulfill];
                                     }];

  [self waitForExpectationsWithTimeout:60.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Get token with no valid checkin should wait for any existing checkin operation to finish.
 *  If the checkin succeeds within a stipulated amount of time period getting the token should
 *  also succeed.
 */
- (void)testNewTokenSuccessAfterWaiting {
  self.hasCheckinInfo = NO;

  __block FIRInstanceIDDeviceCheckinCompletion checkinHandler;
  [[[self.mockAuthService stub] andDo:^(NSInvocation *invocation) {
    if (checkinHandler) {
      FIRInstanceIDErrorCode code = kFIRInstanceIDErrorCodeUnknown;
      NSError *error = [NSError errorWithFIRInstanceIDErrorCode:code];
      checkinHandler(nil, error);
    }
  }] fetchCheckinInfoWithHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
       return (checkinHandler = obj) != nil;
     }]];

  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  NSDictionary *tokenOptions = @{
    kFIRInstanceIDTokenOptionsAPNSKey : [kFakeAPNSToken dataUsingEncoding:NSUTF8StringEncoding],
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(YES),
  };

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    self.newTokenCompletion(kToken, nil);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  [self.instanceID tokenWithAuthorizedEntity:kAuthorizedEntity
                                       scope:kScope
                                     options:tokenOptions
                                     handler:^(NSString *token, NSError *error) {
                                       XCTAssertNil(token);
                                       XCTAssertNotNil(error);
                                       [tokenExpectation fulfill];
                                     }];

  [self waitForExpectationsWithTimeout:60.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Test that the prod APNS token is correctly prefixed with "prod".
 */
- (void)testAPNSTokenIsPrefixedCorrectlyForServerType {
  NSString *APNSKey = kFIRInstanceIDTokenOptionsAPNSKey;
  NSString *serverTypeKey = kFIRInstanceIDTokenOptionsAPNSIsSandboxKey;
  NSDictionary *prodTokenOptions = @{
    APNSKey : [kFakeAPNSToken dataUsingEncoding:NSUTF8StringEncoding],
    serverTypeKey : @(NO),
  };

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation){
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kScope
                               keyPair:[OCMArg any]
                               options:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 NSDictionary *options = (NSDictionary *)obj;
                                 XCTAssertTrue([options[APNSKey] hasPrefix:@"p_"]);
                                 XCTAssertFalse([options[serverTypeKey] boolValue]);
                                 return YES;
                               }]
                               handler:OCMOCK_ANY];

  [self.instanceID tokenWithAuthorizedEntity:kAuthorizedEntity
                                       scope:kScope
                                     options:prodTokenOptions
                                     handler:^(NSString *token, NSError *error){
                                     }];
}

/**
 *  Tests that when there is a failure in producing a new InstanceID token,
 *  the callback is invoked with an error and a nil token.
 */
- (void)testNewTokenFailure {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  NSDictionary *tokenOptions = [NSDictionary dictionary];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    NSError *someError = [[NSError alloc] initWithDomain:@"InstanceIDUnitTest" code:0 userInfo:nil];
    self.newTokenCompletion(nil, someError);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kScope
                               keyPair:[OCMArg any]
                               options:tokenOptions
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  [self.instanceID tokenWithAuthorizedEntity:kAuthorizedEntity
                                       scope:kScope
                                     options:tokenOptions
                                     handler:^(NSString *token, NSError *error) {
                                       XCTAssertNil(token);
                                       XCTAssertNotNil(error);
                                       [tokenExpectation fulfill];
                                     }];

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Tests that when a token is deleted successfully, the callback is invoked with no error.
 */
- (void)testDeleteTokenSuccess {
  XCTestExpectation *deleteExpectation =
      [self expectationWithDescription:@"Delete handler invoked."];

  [self stubKeyPairStoreToReturnValidKeypair];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    self.deleteTokenCompletion(nil);
#pragma clang diagnostic pop
  }] deleteTokenWithAuthorizedEntity:kAuthorizedEntity
                               scope:kScope
                             keyPair:[OCMArg any]
                             handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                               self.deleteTokenCompletion = obj;
                               return obj != nil;
                             }]];

  [self.instanceID deleteTokenWithAuthorizedEntity:kAuthorizedEntity
                                             scope:kScope
                                           handler:^(NSError *error) {
                                             XCTAssertNil(error);
                                             [deleteExpectation fulfill];
                                           }];

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Tests that when a token deletion fails, the callback is invoked with an error.
 */
- (void)testDeleteTokenFailure {
  XCTestExpectation *deleteExpectation =
      [self expectationWithDescription:@"Delete handler invoked."];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    NSError *someError = [[NSError alloc] initWithDomain:@"InstanceIDUnitTest" code:0 userInfo:nil];
    self.deleteTokenCompletion(someError);
  }] deleteTokenWithAuthorizedEntity:kAuthorizedEntity
                               scope:kScope
                             keyPair:[OCMArg any]
                             handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                               self.deleteTokenCompletion = obj;
                               return obj != nil;
                             }]];

  [self.instanceID deleteTokenWithAuthorizedEntity:kAuthorizedEntity
                                             scope:kScope
                                           handler:^(NSError *error) {
                                             XCTAssertNotNil(error);
                                             [deleteExpectation fulfill];
                                           }];

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Tests that not having a senderID will fetch a `nil` default token.
 */
- (void)testDefaultToken_noSenderID {
  _instanceID.fcmSenderID = nil;
  XCTAssertNil([self.mockInstanceID token]);
}

/**
 *  Tests that not having a cached token results in trying to fetch a new default token.
 */
- (void)testDefaultToken_noCachedToken {
  [[[self.mockTokenManager stub] andReturn:nil]
      cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                    scope:@"*"];

  OCMExpect([self.mockInstanceID defaultTokenWithHandler:nil]);
  XCTAssertNil([self.mockInstanceID token]);
  [self.mockInstanceID stopMocking];
  OCMVerify([self.mockInstanceID defaultTokenWithHandler:nil]);
}

/**
 *  Tests that when we have a cached default token, calling `getToken` returns that token
 *  without hitting the network.
 */
- (void)testDefaultToken_validCachedToken {
  [[[self.mockTokenManager stub] andReturn:sTokenInfo]
      cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                    scope:@"*"];
  [[self.mockInstanceID reject] defaultTokenWithHandler:nil];
  XCTAssertEqualObjects([self.mockInstanceID token], kToken);
}

/**
 *  Tests that the callback handler will be invoked when the default token is fetched
 *  despite the token being unchanged.
 */
- (void)testDefaultToken_callbackInvokedForUnchangedToken {
  XCTestExpectation *defaultTokenExpectation =
      [self expectationWithDescription:@"Token fetch was successful."];

  __block FIRInstanceIDTokenInfo *cachedTokenInfo = nil;

  [self stubKeyPairStoreToReturnValidKeypair];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Mock Token manager to always succeed the token fetch, and return
  // a particular cached value.

  // Return a dynamic cachedToken variable whenever the cached is checked.
  // This uses an invocation-based mock because the |cachedToken| pointer
  // will change. Normal stubbing will always return the initial pointer,
  // which in this case is 0x0 (nil).
  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&cachedTokenInfo];
  }] cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kFIRInstanceIDDefaultTokenScope];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    self.newTokenCompletion(kToken, nil);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  __block NSInteger notificationPostCount = 0;
  __block NSString *notificationToken = nil;

  // Fetch token once to store token state
  NSString *notificationName = kFIRInstanceIDTokenRefreshNotification;
  self.tokenRefreshNotificationObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:notificationName
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification *_Nonnull note) {
                // Should have saved token to cache
                cachedTokenInfo = sTokenInfo;

                notificationPostCount++;
                notificationToken = [[self.instanceID token] copy];
                [defaultTokenExpectation fulfill];
              }];
  XCTAssertNil([self.mockInstanceID token]);
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self.tokenRefreshNotificationObserver];

  XCTAssertEqualObjects(notificationToken, kToken);

  // Fetch default handler again without any token changes
  XCTestExpectation *tokenCallback = [self expectationWithDescription:@"Callback was invoked."];

  [self.mockInstanceID defaultTokenWithHandler:^(NSString *token, NSError *error) {
    notificationToken = token;
    [tokenCallback fulfill];
  }];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  XCTAssertEqualObjects(notificationToken, kToken);
}

/**
 *  Test that when we fetch a new default token and cache it successfully we post a
 *  tokenRefresh notification which allows to fetch the cached token.
 */
- (void)testDefaultTokenFetch_returnValidToken {
  XCTestExpectation *defaultTokenExpectation =
      [self expectationWithDescription:@"Successfully got default token."];

  __block FIRInstanceIDTokenInfo *cachedTokenInfo = nil;

  [self stubKeyPairStoreToReturnValidKeypair];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Mock Token manager to always succeed the token fetch, and return
  // a particular cached value.

  // Return a dynamic cachedToken variable whenever the cached is checked.
  // This uses an invocation-based mock because the |cachedToken| pointer
  // will change. Normal stubbing will always return the initial pointer,
  // which in this case is 0x0 (nil).
  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&cachedTokenInfo];
  }] cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kFIRInstanceIDDefaultTokenScope];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    self.newTokenCompletion(kToken, nil);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  __block int notificationPostCount = 0;
  __block NSString *notificationToken = nil;

  NSString *notificationName = kFIRInstanceIDTokenRefreshNotification;
  self.tokenRefreshNotificationObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:notificationName
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification *_Nonnull note) {
                // Should have saved token to cache
                cachedTokenInfo = sTokenInfo;

                notificationPostCount++;
                notificationToken = [[self.instanceID token] copy];
                [defaultTokenExpectation fulfill];
              }];
  XCTAssertNil([self.mockInstanceID token]);
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self.tokenRefreshNotificationObserver];

  XCTAssertEqualObjects(notificationToken, kToken);
}

/**
 *  Tests that if we fail to fetch the token from the server for the first time we retry again
 *  later with exponential backoff unless we succeed.
 */
- (void)testDefaultTokenFetch_retryFetchToken {
  const int trialsBeforeSuccess = 3;
  __block int newTokenFetchCount = 0;
  __block int64_t lastFetchTimestampInSeconds;

  XCTestExpectation *defaultTokenExpectation =
      [self expectationWithDescription:@"Successfully got default token."];

  __block FIRInstanceIDTokenInfo *cachedTokenInfo = nil;

  [self stubKeyPairStoreToReturnValidKeypair];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Mock Token manager.
  // Return a dynamic cachedToken variable whenever the cached is checked.
  // This uses an invocation-based mock because the |cachedToken| pointer
  // will change. Normal stubbing will always return the initial pointer,
  // which in this case is 0x0 (nil).
  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&cachedTokenInfo];
  }] cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kFIRInstanceIDDefaultTokenScope];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    newTokenFetchCount++;
    int64_t delaySinceLastFetchInSeconds =
        FIRInstanceIDCurrentTimestampInSeconds() - lastFetchTimestampInSeconds;
    // Test exponential backoff.
    if (newTokenFetchCount > 1) {
      XCTAssertLessThanOrEqual(1 << (newTokenFetchCount - 1), delaySinceLastFetchInSeconds);
    }
    lastFetchTimestampInSeconds = FIRInstanceIDCurrentTimestampInSeconds();

    if (newTokenFetchCount < trialsBeforeSuccess) {
      NSError *error = [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeTimeout];
      self.newTokenCompletion(nil, error);
    } else {
      self.newTokenCompletion(kToken, nil);
    }
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  __block int notificationPostCount = 0;
  __block NSString *notificationToken = nil;

  NSString *notificationName = kFIRInstanceIDTokenRefreshNotification;
  self.tokenRefreshNotificationObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:notificationName
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification *_Nonnull note) {
                // Should have saved token to cache
                cachedTokenInfo = sTokenInfo;

                notificationPostCount++;
                notificationToken = [[self.instanceID token] copy];
                [defaultTokenExpectation fulfill];
              }];
  XCTAssertNil([self.mockInstanceID token]);

  [self waitForExpectationsWithTimeout:20.0 handler:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self.tokenRefreshNotificationObserver];

  XCTAssertEqualObjects(notificationToken, kToken);
  XCTAssertEqual(notificationPostCount, 1);
  XCTAssertEqual(newTokenFetchCount, trialsBeforeSuccess);
}

/**
 *  Tests that when we don't have a cached default token multiple invocations to `getToken`
 *  lead to a single networking call to fetch the token. Also verify that we post one unique
 *  TokenRefresh notification for multiple invocations.
 */
- (void)testDefaultToken_multipleInvocations {
  __block int newTokenFetchCount = 0;
  XCTestExpectation *defaultTokenExpectation =
      [self expectationWithDescription:@"Successfully got default token."];

  __block FIRInstanceIDTokenInfo *cachedTokenInfo = nil;

  [self stubKeyPairStoreToReturnValidKeypair];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Mock Token manager.
  // Return a dynamic cachedToken variable whenever the cached is checked.
  // This uses an invocation-based mock because the |cachedToken| pointer
  // will change. Normal stubbing will always return the initial pointer,
  // which in this case is 0x0 (nil).
  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&cachedTokenInfo];
  }] cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kFIRInstanceIDDefaultTokenScope];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    // Invoke callback after some delay (network delay)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     self.newTokenCompletion(kToken, nil);
                   });
    newTokenFetchCount++;
    XCTAssertEqual(newTokenFetchCount, 1);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  __block int notificationPostCount = 0;
  __block NSString *notificationToken = nil;
  NSString *notificationName = kFIRInstanceIDTokenRefreshNotification;
  self.tokenRefreshNotificationObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:notificationName
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification *_Nonnull note) {
                // Should have saved token to cache
                cachedTokenInfo = sTokenInfo;

                notificationPostCount++;
                notificationToken = [[self.instanceID token] copy];
                [defaultTokenExpectation fulfill];
              }];

  XCTAssertNil([self.mockInstanceID token]);
  // Invoke get token again with some delay. Our initial request to getToken hasn't yet
  // returned from the server.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   XCTAssertNil([self.mockInstanceID token]);
                 });
  // Invoke again after further delay.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   XCTAssertNil([self.mockInstanceID token]);
                 });

  [self waitForExpectationsWithTimeout:15.0 handler:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self.tokenRefreshNotificationObserver];

  XCTAssertEqualObjects(notificationToken, kToken);
  XCTAssertEqual(notificationPostCount, 1);
  XCTAssertEqual(newTokenFetchCount, 1);
}

- (void)testDefaultToken_maxRetries {
  __block int newTokenFetchCount = 0;
  XCTestExpectation *defaultTokenExpectation =
      [self expectationWithDescription:@"Did retry maximum times to fetch default token."];

  [self stubKeyPairStoreToReturnValidKeypair];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Mock Token manager.
  [[[self.mockTokenManager stub] andReturn:nil]
      cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                    scope:kFIRInstanceIDDefaultTokenScope];

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    newTokenFetchCount++;
    NSError *error = [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeNetwork];
    self.newTokenCompletion(nil, error);
    if (newTokenFetchCount == [FIRInstanceID maxRetryCountForDefaultToken]) {
      [defaultTokenExpectation fulfill];
    }
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  // Mock Instance ID's retry interval to 0, to vastly speed up this test.
  [[[self.mockInstanceID stub] andReturnValue:@(0)] retryIntervalToFetchDefaultToken];

  // Try to fetch token once. It should set off retries since we mock failure.
  XCTAssertNil([self.mockInstanceID token]);

  [self waitForExpectationsWithTimeout:1.0 handler:nil];

  XCTAssertEqual(newTokenFetchCount, [FIRInstanceID maxRetryCountForDefaultToken]);
}

- (void)testInstanceIDWithHandler_WhileRequesting_Success {
  [self stubKeyPairStoreToReturnValidKeypair];
  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Expect `fetchNewTokenWithAuthorizedEntity` to be called once
  XCTestExpectation *fetchNewTokenExpectation =
      [self expectationWithDescription:@"fetchNewTokenExpectation"];
  __block FIRInstanceIDTokenHandler tokenHandler;

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation getArgument:&tokenHandler atIndex:6];
    [fetchNewTokenExpectation fulfill];
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg any]];

  // Make 1st call
  XCTestExpectation *handlerExpectation1 = [self expectationWithDescription:@"handlerExpectation1"];
  FIRInstanceIDResultHandler handler1 =
      ^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        [handlerExpectation1 fulfill];
        XCTAssertNotNil(result);
        XCTAssertEqual(result.token, kToken);
        XCTAssertNil(error);
      };

  [self.mockInstanceID instanceIDWithHandler:handler1];

  // Make 2nd call
  XCTestExpectation *handlerExpectation2 = [self expectationWithDescription:@"handlerExpectation1"];
  FIRInstanceIDResultHandler handler2 =
      ^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        [handlerExpectation2 fulfill];
        XCTAssertNotNil(result);
        XCTAssertEqual(result.token, kToken);
        XCTAssertNil(error);
      };

  [self.mockInstanceID instanceIDWithHandler:handler2];

  // Wait for `fetchNewTokenWithAuthorizedEntity` to be performed
  [self waitForExpectations:@[ fetchNewTokenExpectation ] timeout:1 enforceOrder:false];
  // Finish token fetch request
  tokenHandler(kToken, nil);

  // Wait for completion handlers for both calls to be performed
  [self waitForExpectationsWithTimeout:1 handler:NULL];
}

- (void)testInstanceIDWithHandler_WhileRequesting_RetrySuccess {
  [self stubKeyPairStoreToReturnValidKeypair];
  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Expect `fetchNewTokenWithAuthorizedEntity` to be called twice
  XCTestExpectation *fetchNewTokenExpectation1 =
      [self expectationWithDescription:@"fetchNewTokenExpectation1"];
  XCTestExpectation *fetchNewTokenExpectation2 =
      [self expectationWithDescription:@"fetchNewTokenExpectation2"];
  NSArray *fetchNewTokenExpectations = @[ fetchNewTokenExpectation1, fetchNewTokenExpectation2 ];

  __block NSInteger fetchNewTokenCallCount = 0;
  __block FIRInstanceIDTokenHandler tokenHandler;

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation getArgument:&tokenHandler atIndex:6];
    [fetchNewTokenExpectations[fetchNewTokenCallCount] fulfill];
    fetchNewTokenCallCount += 1;
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg any]];

  // Mock Instance ID's retry interval to 0, to vastly speed up this test.
  [[[self.mockInstanceID stub] andReturnValue:@(0)] retryIntervalToFetchDefaultToken];

  // Make 1st call
  XCTestExpectation *handlerExpectation1 = [self expectationWithDescription:@"handlerExpectation1"];
  FIRInstanceIDResultHandler handler1 =
      ^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        [handlerExpectation1 fulfill];
        XCTAssertNotNil(result);
        XCTAssertEqual(result.token, kToken);
        XCTAssertNil(error);
      };

  [self.mockInstanceID instanceIDWithHandler:handler1];

  // Make 2nd call
  XCTestExpectation *handlerExpectation2 = [self expectationWithDescription:@"handlerExpectation1"];
  FIRInstanceIDResultHandler handler2 =
      ^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        [handlerExpectation2 fulfill];
        XCTAssertNotNil(result);
        XCTAssertEqual(result.token, kToken);
        XCTAssertNil(error);
      };

  [self.mockInstanceID instanceIDWithHandler:handler2];

  // Wait for the 1st `fetchNewTokenWithAuthorizedEntity` to be performed
  [self waitForExpectations:@[ fetchNewTokenExpectation1 ] timeout:1 enforceOrder:false];
  // Fail for the 1st time
  tokenHandler(nil, [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeUnknown]);

  // Wait for the 2nd token feth
  [self waitForExpectations:@[ fetchNewTokenExpectation2 ] timeout:1 enforceOrder:false];
  // Finish with success
  tokenHandler(kToken, nil);

  // Wait for completion handlers for both calls to be performed
  [self waitForExpectationsWithTimeout:1 handler:NULL];
}

- (void)testInstanceIDWithHandler_WhileRequesting_RetryFailure {
  [self stubKeyPairStoreToReturnValidKeypair];
  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Expect `fetchNewTokenWithAuthorizedEntity` to be called once
  NSMutableArray<XCTestExpectation *> *fetchNewTokenExpectations = [NSMutableArray array];
  for (NSInteger i = 0; i < [[self.instanceID class] maxRetryCountForDefaultToken]; ++i) {
    NSString *name = [NSString stringWithFormat:@"fetchNewTokenExpectation-%ld", (long)i];
    [fetchNewTokenExpectations addObject:[self expectationWithDescription:name]];
  }

  __block NSInteger fetchNewTokenCallCount = 0;
  __block FIRInstanceIDTokenHandler tokenHandler;

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation getArgument:&tokenHandler atIndex:6];
    [fetchNewTokenExpectations[fetchNewTokenCallCount] fulfill];
    fetchNewTokenCallCount += 1;
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg any]];

  // Mock Instance ID's retry interval to 0, to vastly speed up this test.
  [[[self.mockInstanceID stub] andReturnValue:@(0)] retryIntervalToFetchDefaultToken];

  // Make 1st call
  XCTestExpectation *handlerExpectation1 = [self expectationWithDescription:@"handlerExpectation1"];
  FIRInstanceIDResultHandler handler1 =
      ^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        [handlerExpectation1 fulfill];
        XCTAssertNil(result);
        XCTAssertNotNil(error);
      };

  [self.mockInstanceID instanceIDWithHandler:handler1];

  // Make 2nd call
  XCTestExpectation *handlerExpectation2 = [self expectationWithDescription:@"handlerExpectation1"];
  FIRInstanceIDResultHandler handler2 =
      ^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        [handlerExpectation2 fulfill];
        XCTAssertNil(result);
        XCTAssertNotNil(error);
      };

  [self.mockInstanceID instanceIDWithHandler:handler2];

  for (NSInteger i = 0; i < [[self.instanceID class] maxRetryCountForDefaultToken]; ++i) {
    // Wait for the i `fetchNewTokenWithAuthorizedEntity` to be performed
    [self waitForExpectations:@[ fetchNewTokenExpectations[i] ] timeout:1 enforceOrder:false];
    // Fail for the i time
    tokenHandler(nil, [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeUnknown]);
  }

  // Wait for completion handlers for both calls to be performed
  [self waitForExpectationsWithTimeout:1 handler:NULL];
}

/**
 *  Tests a Keychain read failure while we try to fetch a new InstanceID token. If the Keychain
 *  read fails we won't be able to fetch the public key which is required while fetching a new
 *  token. In such a case we should return KeyPair failure.
 */
- (void)testNewTokenFetch_keyChainError {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // Simulate keypair fetch/generation failure.
  [[[self.mockKeyPairStore stub] andReturn:nil] loadKeyPairWithError:[OCMArg anyObjectRef]];

  [[self.mockTokenManager reject] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                                              scope:kScope
                                                            keyPair:[OCMArg any]
                                                            options:[OCMArg any]
                                                            handler:[OCMArg any]];

  [self.instanceID tokenWithAuthorizedEntity:kAuthorizedEntity
                                       scope:kScope
                                     options:nil
                                     handler:^(NSString *token, NSError *error) {
                                       XCTAssertNil(token);
                                       XCTAssertNotNil(error);
                                       [tokenExpectation fulfill];
                                     }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
  OCMVerifyAll(self.mockTokenManager);
}

/**
 *  If a token fetch includes in its options an "apns_token" object, but not a "apns_sandbox" key,
 *  ensure that an "apns_sandbox" key is added to the token options (via automatic detection).
 */
- (void)testTokenFetchAPNSServerTypeIsIncludedIfAPNSTokenProvided {
  XCTestExpectation *apnsServerTypeExpectation =
      [self expectationWithDescription:@"apns_sandbox key was included in token options"];

  [self stubKeyPairStoreToReturnValidKeypair];
  [self mockAuthServiceToAlwaysReturnValidCheckin];

  NSData *apnsToken = [kFakeAPNSToken dataUsingEncoding:NSUTF8StringEncoding];
  // Option is purposefully missing the apns_sandbox key
  NSDictionary *tokenOptions = @{kFIRInstanceIDTokenOptionsAPNSKey : apnsToken};

  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    // Inspect
    NSDictionary *options;
    [invocation getArgument:&options atIndex:5];
    if (options[kFIRInstanceIDTokenOptionsAPNSIsSandboxKey] != nil) {
      [apnsServerTypeExpectation fulfill];
    }
    self.newTokenCompletion(kToken, nil);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  [self.instanceID tokenWithAuthorizedEntity:kAuthorizedEntity
                                       scope:kScope
                                     options:tokenOptions
                                     handler:^(NSString *token, NSError *error){
                                     }];

  [self waitForExpectationsWithTimeout:60.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/**
 *  Tests that if a token was fetched, but during the fetch the APNs data was set, that a new
 *  token is fetched to associate the APNs data, and is not returned from the cache.
 */
- (void)testTokenFetch_ignoresCacheIfAPNSInfoDifferent {
  XCTestExpectation *tokenRequestExpectation =
      [self expectationWithDescription:@"Token was fetched from the network"];

  // Initialize a token in the cache *WITHOUT* APNSInfo
  // This token is |kToken|, but we will simulate that a fetch will return another token
  NSString *oldCachedToken = kToken;
  NSString *fetchedToken = @"abcd123_newtoken";
  __block FIRInstanceIDTokenInfo *cachedTokenInfo =
      [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                         scope:kFIRInstanceIDDefaultTokenScope
                                                         token:oldCachedToken
                                                    appVersion:@"1.0"
                                                 firebaseAppID:@"firebaseAppID"];

  [self stubKeyPairStoreToReturnValidKeypair];

  [self mockAuthServiceToAlwaysReturnValidCheckin];

  // During this test use the default scope ("*") to simulate the default token behavior.

  // Return a dynamic cachedToken variable whenever the cached is checked.
  // This uses an invocation-based mock because the |cachedToken| pointer
  // will change. Normal stubbing will always return the initial pointer,
  // which in this case is 0x0 (nil).
  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&cachedTokenInfo];
  }] cachedTokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kFIRInstanceIDDefaultTokenScope];

  // Mock the network request to return |fetchedToken|, so we can clearly see if the token is
  // is different than what was cached.
  [[[self.mockTokenManager stub] andDo:^(NSInvocation *invocation) {
    [tokenRequestExpectation fulfill];
    self.newTokenCompletion(fetchedToken, nil);
  }] fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                 scope:kFIRInstanceIDDefaultTokenScope
                               keyPair:[OCMArg any]
                               options:[OCMArg any]
                               handler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                 self.newTokenCompletion = obj;
                                 return obj != nil;
                               }]];

  // Begin request
  // Token options has APNS data, which is not associated with the cached token
  NSDictionary *tokenOptions = @{
    kFIRInstanceIDTokenOptionsAPNSKey : [@"apns" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(NO)
  };
  [self.instanceID
      tokenWithAuthorizedEntity:kAuthorizedEntity
                          scope:kFIRInstanceIDDefaultTokenScope
                        options:tokenOptions
                        handler:^(NSString *_Nullable token, NSError *_Nullable error) {
                          XCTAssertEqualObjects(token, fetchedToken);
                        }];

  [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

/**
 *  Tests that if there is a keychain failure while fetching the InstanceID of the token we should
 *  return nil for the identity.
 */
- (void)testInstanceIDFetch_keyChainError {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"InstanceID fetch handler invoked."];

  // Simulate keypair fetch/generation failure.
  NSError *error = [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeInvalidKeyPair];
  [[[self.mockKeyPairStore stub] andReturn:nil] appIdentityWithError:[OCMArg setTo:error]];

  [self.instanceID getIDWithHandler:^(NSString *_Nullable identity, NSError *_Nullable error) {
    XCTAssertNil(identity);
    XCTAssertNotNil(error);
    [tokenExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInstanceIDDelete_keyChainError {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"InstanceID deleteID handler invoked."];

  // Simulate keypair fetch/generation failure.
  NSError *error = [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeInvalidKeyPair];
  [[[self.mockKeyPairStore stub] andReturn:nil] appIdentityWithError:[OCMArg setTo:error]];

  [self.instanceID deleteIDWithHandler:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    [tokenExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Private Helpers

- (void)stubKeyPairStoreToReturnValidKeypair {
  [[[self.mockKeyPairStore stub] andReturn:[self createValidMockKeypair]]
      loadKeyPairWithError:[OCMArg anyObjectRef]];
}

- (id)createValidMockKeypair {
  id mockKeypair = OCMClassMock([FIRInstanceIDKeyPair class]);
  [[[mockKeypair stub] andReturnValue:@YES] isValid];
  return mockKeypair;
}

- (FIRInstanceIDCheckinPreferences *)validCheckinPreferences {
  NSDictionary *gservicesData = @{
    kFIRInstanceIDVersionInfoStringKey : kVersionInfo,
    kFIRInstanceIDLastCheckinTimeKey : @(FIRInstanceIDCurrentTimestampInMilliseconds())
  };
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                    secretToken:kSecretToken];
  [checkinPreferences updateWithCheckinPlistContents:gservicesData];
  return checkinPreferences;
}

- (void)mockAuthServiceToAlwaysReturnValidCheckin {
  FIRInstanceIDCheckinPreferences *validCheckin = [self validCheckinPreferences];
  __block FIRInstanceIDDeviceCheckinCompletion checkinHandler;
  [[[self.mockAuthService stub] andDo:^(NSInvocation *invocation) {
    if (checkinHandler) {
      checkinHandler(validCheckin, nil);
    }
  }] fetchCheckinInfoWithHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
       return (checkinHandler = obj) != nil;
     }]];
}

@end
