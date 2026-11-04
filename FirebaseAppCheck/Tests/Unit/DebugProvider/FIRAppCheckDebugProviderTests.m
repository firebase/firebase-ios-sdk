/*
 * Copyright 2020 Google LLC
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
#import <objc/runtime.h>

#if __has_include(<AppCheckCore/AppCheckCore-Swift.h>)
#import <AppCheckCore/AppCheckCore-Swift.h>
#elif __has_include("AppCheckCore-Swift.h")
#import "AppCheckCore-Swift.h"
#else
@import AppCheckCore;
#endif
#import <GoogleUtilities/GULUserDefaults.h>
#import <OCMock/OCMock.h>

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProvider.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

static NSString *const kAppName = @"test_app_name";
static NSString *const kAppID = @"test_app_id";
static NSString *const kAPIKey = @"test_api_key";
static NSString *const kProjectID = @"test_project_id";
static NSString *const kProjectNumber = @"123456789";
static NSString *const kDebugTokenUserDefaultsKey = @"GACAppCheckDebugToken";
static NSString *const kInjectedDebugTokenClassName = @"FIRAppCheckInjectedDebugToken";

@interface FIRAppCheckDebugProvider (Tests)

- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider
                            projectID:(nullable NSString *)projectID
                          googleAppID:(NSString *)googleAppID;
- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider
                            projectID:(nullable NSString *)projectID
                          googleAppID:(NSString *)googleAppID
                   resolvedDebugToken:(nullable NSString *)resolvedDebugToken
                  resolvedTokenSource:(nullable NSString *)resolvedTokenSource;
@property(nonatomic, readonly) GACAppCheckDebugProvider *debugProvider;
@property(nonatomic, readonly, copy, nullable) NSString *projectID;
@property(nonatomic, readonly, copy) NSString *googleAppID;
@property(nonatomic, readonly, copy, nullable) NSString *resolvedDebugToken;
@property(nonatomic, readonly, copy, nullable) NSString *resolvedTokenSource;

+ (nullable NSString *)resolveDebugTokenForAppID:(NSString *)googleAppID
                                          source:(NSString *_Nullable *_Nullable)outSource;
+ (BOOL)isHTTP403Error:(nullable NSError *)error;
- (nullable NSString *)debugTokenMessageWithPrefix:(NSString *)prefix;

@end

@interface FIRAppCheckDebugProviderTests : XCTestCase

@property(nonatomic, copy) NSString *resourceName;
@property(nonatomic) id debugProviderMock;
@property(nonatomic) FIRAppCheckDebugProvider *provider;
@property(nonatomic, copy) NSString *tempHostHomeDir;
@property(nonatomic, copy, nullable) NSString *savedSimulatorHostHome;
@property(nonatomic) NSMutableArray<NSValue *> *injectedClassIMPs;

@end

@implementation FIRAppCheckDebugProviderTests

- (void)setUp {
  [super setUp];
  const char *existingSimHome = getenv("SIMULATOR_HOST_HOME");
  self.savedSimulatorHostHome = existingSimHome ? @(existingSimHome) : nil;
  self.tempHostHomeDir =
      [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.tempHostHomeDir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  setenv("SIMULATOR_HOST_HOME", self.tempHostHomeDir.UTF8String, 1);
  unsetenv("FIREBASE_APPCHECK_DEBUG_TOKEN");
  unsetenv("AppCheckDebugToken");
  unsetenv("FIRAAppCheckDebugToken");
  unsetenv("XDG_CONFIG_HOME");
  // Providers created with `initWithApp:` persist a locally generated token; start from a clean
  // state so that tests don't observe each other's tokens.
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kDebugTokenUserDefaultsKey];
  self.injectedClassIMPs = [NSMutableArray array];

  self.resourceName = [NSString stringWithFormat:@"projects/%@/apps/%@", kProjectID, kAppID];
  self.debugProviderMock = OCMStrictClassMock([GACAppCheckDebugProvider class]);
  self.provider = [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock
                                                                projectID:nil
                                                              googleAppID:kAppID];
}

- (void)tearDown {
  self.provider = nil;
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;

  unsetenv("FIREBASE_APPCHECK_DEBUG_TOKEN");
  unsetenv("AppCheckDebugToken");
  unsetenv("FIRAAppCheckDebugToken");
  unsetenv("XDG_CONFIG_HOME");
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kDebugTokenUserDefaultsKey];
  if (self.savedSimulatorHostHome) {
    setenv("SIMULATOR_HOST_HOME", self.savedSimulatorHostHome.UTF8String, 1);
  } else {
    unsetenv("SIMULATOR_HOST_HOME");
  }
  if (self.tempHostHomeDir) {
    [[NSFileManager defaultManager] removeItemAtPath:self.tempHostHomeDir error:nil];
    self.tempHostHomeDir = nil;
  }
  [super tearDown];
}

- (FIRApp *)createValidTestApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  app.dataCollectionDefaultEnabled = NO;
  return app;
}

- (void)writeConfigFileInDirectory:(NSString *)configDir contents:(NSString *)contents {
  [[NSFileManager defaultManager] createDirectoryAtPath:configDir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  NSString *configPath = [configDir stringByAppendingPathComponent:@"firebase-appcheck.json"];
  [contents writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)writeLocalConfigFileWithContents:(NSString *)contents {
  [self writeConfigFileInDirectory:[self.tempHostHomeDir
                                       stringByAppendingPathComponent:@".config/configstore"]
                          contents:contents];
}

/// Registers a `FIRAppCheckInjectedDebugToken` class that implements `+tokens` and/or `+token`, as
/// the build-time generated class does. Returns `Nil` if a class with that name already exists.
- (nullable Class)registerInjectedDebugTokenClassWithTokens:
                      (nullable NSDictionary<NSString *, NSString *> *)tokens
                                                      token:(nullable NSString *)token {
  Class injectedClass =
      objc_allocateClassPair([NSObject class], kInjectedDebugTokenClassName.UTF8String, 0);
  if (!injectedClass) {
    return Nil;
  }
  Class metaClass = object_getClass(injectedClass);
  if (tokens) {
    IMP tokensIMP = imp_implementationWithBlock(^NSDictionary *(id _self) {
      return tokens;
    });
    [self.injectedClassIMPs addObject:[NSValue valueWithPointer:(const void *)tokensIMP]];
    class_addMethod(metaClass, @selector(tokens), tokensIMP, "@@:");
  }
  if (token) {
    IMP tokenIMP = imp_implementationWithBlock(^NSString *(id _self) {
      return token;
    });
    [self.injectedClassIMPs addObject:[NSValue valueWithPointer:(const void *)tokenIMP]];
    class_addMethod(metaClass, @selector(token), tokenIMP, "@@:");
  }
  objc_registerClassPair(injectedClass);
  return injectedClass;
}

- (void)disposeInjectedDebugTokenClass:(Class)injectedClass {
  objc_disposeClassPair(injectedClass);
  for (NSValue *value in self.injectedClassIMPs) {
    imp_removeBlock((IMP)value.pointerValue);
  }
  [self.injectedClassIMPs removeAllObjects];
}

- (GACAppCheckHTTPError *)HTTPErrorWithStatusCode:(NSInteger)statusCode
                                        URLString:(NSString *)URLString
                                             body:(nullable NSString *)body {
  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:URLString]
                                  statusCode:statusCode
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];
  return [[GACAppCheckHTTPError alloc]
      initWithHTTPResponse:response
                      data:[body dataUsingEncoding:NSUTF8StringEncoding]];
}

#pragma mark - Initialization

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  app.dataCollectionDefaultEnabled = NO;

  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  XCTAssertNotNil(provider);
  XCTAssertEqualObjects(provider.projectID, kProjectID);
  XCTAssertEqualObjects(provider.googleAppID, kAppID);
}

- (void)testInitWithDebugProvider {
  XCTAssertNil(self.provider.projectID);
  XCTAssertEqualObjects(self.provider.googleAppID, kAppID);
}

- (void)testInitWithIncompleteApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.projectID = kProjectID;
  FIRApp *missingAPIKeyApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  missingAPIKeyApp.dataCollectionDefaultEnabled = NO;

  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingAPIKeyApp]);

  options.projectID = nil;
  options.APIKey = kAPIKey;
  FIRApp *missingProjectIDApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  missingProjectIDApp.dataCollectionDefaultEnabled = NO;
  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingProjectIDApp]);
}

#pragma mark - Current Debug token

- (void)testCurrentTokenShim {
  NSString *currentToken = @"debug_token";
  OCMExpect([self.debugProviderMock currentDebugToken]).andReturn(currentToken);

  XCTAssertEqualObjects([self.provider currentDebugToken], currentToken);

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Local Debug Token

- (void)testLocalDebugToken {
  NSString *localToken = @"TEST_LocalDebugToken";
  OCMExpect([self.debugProviderMock localDebugToken]).andReturn(localToken);

  XCTAssertEqualObjects([self.provider localDebugToken], localToken);

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Debug token to FAC token exchange

- (void)testGetTokenSuccess {
  // 1. Stub internal debug provider.
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg
                                 invokeBlockWithArgs:validInternalToken, [NSNull null], nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertEqualObjects(token.token, validInternalToken.token);
        XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
        XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
        XCTAssertNil(error);
      }];

  // 3. Verify mock debug provider.
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetTokenAPIError {
  // 1. Stub internal debug provider.
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  // 3. Verify mock debug provider.
  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Limited-Use Token

- (void)testGetLimitedUseTokenSuccess {
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"TEST_ValidToken"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.debugProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:validInternalToken,
                                                                    [NSNull null], nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertEqualObjects(token.token, validInternalToken.token);
    XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
    XCTAssertNil(error);
  }];

  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetLimitedUseTokenProviderError {
  NSError *expectedError = [NSError errorWithDomain:@"TEST_LimitedUseToken_Error"
                                               code:-1
                                           userInfo:nil];
  OCMExpect([self.debugProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError,
                                                                    nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertIdentical(error, expectedError);
  }];

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Debug Token Resolution Order

- (void)testResolveTokenFromFirebaseAppCheckDebugTokenEnvVarHasHighestPriority {
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;

  setenv("FIREBASE_APPCHECK_DEBUG_TOKEN", "firebase_env_token_111", 1);
  setenv("AppCheckDebugToken", "appcheck_env_token_222", 1);
  [self
      writeLocalConfigFileWithContents:@"{\"tokens\":{\"test_app_id\":\"configstore_token_333\"}}"];

  FIRApp *app = [self createValidTestApp];
  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssertEqualObjects([provider currentDebugToken], @"firebase_env_token_111");
  XCTAssertEqualObjects([provider.debugProvider currentDebugToken], @"firebase_env_token_111");
  XCTAssertEqualObjects(provider.resolvedTokenSource,
                        @"environment variable (FIREBASE_APPCHECK_DEBUG_TOKEN)");
  // Verify AppCheckDebugToken environment variable was restored after init.
  XCTAssertEqualObjects(@(getenv("AppCheckDebugToken")), @"appcheck_env_token_222");
}

- (void)testResolveTokenFromAppCheckDebugTokenEnvVarOverridesLocalConfigFile {
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;

  setenv("AppCheckDebugToken", "appcheck_env_token_222", 1);
  [self
      writeLocalConfigFileWithContents:@"{\"tokens\":{\"test_app_id\":\"configstore_token_333\"}}"];

  FIRApp *app = [self createValidTestApp];
  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssertEqualObjects([provider currentDebugToken], @"appcheck_env_token_222");
  XCTAssertEqualObjects([provider.debugProvider currentDebugToken], @"appcheck_env_token_222");
  XCTAssertEqualObjects(provider.resolvedTokenSource, @"environment variable (AppCheckDebugToken)");
  XCTAssertEqualObjects(@(getenv("AppCheckDebugToken")), @"appcheck_env_token_222");
}

- (void)testResolveTokenFromLegacyEnvironmentVariable {
  setenv("FIRAAppCheckDebugToken", "legacy_env_token_666", 1);

  NSString *source = nil;
  XCTAssertEqualObjects([FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID source:&source],
                        @"legacy_env_token_666");
  XCTAssertEqualObjects(source, @"environment variable (FIRAAppCheckDebugToken)");
}

// The local configuration file is only read on simulators and macOS.
#if TARGET_OS_SIMULATOR || TARGET_OS_OSX

- (void)testResolveTokenFromSimulatorHostHomeLocalConfigFile {
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;

  [self writeLocalConfigFileWithContents:
            @"{\"_comment\":\"secret\",\"tokens\":{\"test_app_id\":\"configstore_token_333\","
            @"\"other_app_id\":\"other_token_444\"}}"];

  FIRApp *app = [self createValidTestApp];
  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssertEqualObjects([provider currentDebugToken], @"configstore_token_333");
  XCTAssertEqualObjects([provider.debugProvider currentDebugToken], @"configstore_token_333");
  XCTAssertEqualObjects(provider.resolvedTokenSource,
                        @"~/.config/configstore/firebase-appcheck.json");
  // Verify AppCheckDebugToken environment variable was unset after init.
  XCTAssertTrue(getenv("AppCheckDebugToken") == NULL);
}

- (void)testResolveTokenPrefersXDGConfigHomeLikeTheFirebaseCLI {
  [self
      writeLocalConfigFileWithContents:@"{\"tokens\":{\"test_app_id\":\"home_config_token_888\"}}"];
  NSString *xdgConfigHome = [self.tempHostHomeDir stringByAppendingPathComponent:@"xdg"];
  NSString *xdgConfigDir = [xdgConfigHome stringByAppendingPathComponent:@"configstore"];
  [self writeConfigFileInDirectory:xdgConfigDir
                          contents:@"{\"tokens\":{\"test_app_id\":\"xdg_config_token_999\"}}"];
  setenv("XDG_CONFIG_HOME", xdgConfigHome.UTF8String, 1);

  NSString *source = nil;
  XCTAssertEqualObjects([FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID source:&source],
                        @"xdg_config_token_999");

  // Falls back to ~/.config when the XDG configuration has no token for the app.
  [self writeConfigFileInDirectory:xdgConfigDir contents:@"{\"tokens\":{}}"];
  XCTAssertEqualObjects([FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID source:&source],
                        @"home_config_token_888");
}

#endif  // TARGET_OS_SIMULATOR || TARGET_OS_OSX

- (void)testResolveTokenFromLocalConfigFileIgnoresMalformedOrUnmatchedJSON {
  // 1. Unmatched googleAppID.
  [self writeLocalConfigFileWithContents:@"{\"tokens\":{\"other_app_id\":\"other_token_444\"}}"];
  NSString *source = nil;
  NSString *token = [FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID source:&source];
  XCTAssertNil(token);
  XCTAssertNil(source);

  // 2. Malformed JSON.
  [self writeLocalConfigFileWithContents:@"{not valid json"];
  token = [FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID source:&source];
  XCTAssertNil(token);
  XCTAssertNil(source);

  // 3. Non-dictionary tokens field.
  [self writeLocalConfigFileWithContents:@"{\"tokens\":[\"not-a-dict\"]}"];
  token = [FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID source:&source];
  XCTAssertNil(token);
  XCTAssertNil(source);

  // 4. Non-string token entry.
  [self writeLocalConfigFileWithContents:@"{\"tokens\":{\"test_app_id\":12345}}"];
  token = [FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID source:&source];
  XCTAssertNil(token);
  XCTAssertNil(source);
}

- (void)testResolveTokenFromInjectedDebugTokenClassAndPrecedence {
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;

  Class injectedClass =
      [self registerInjectedDebugTokenClassWithTokens:nil token:@"injected_debug_token_444"];
  if (!injectedClass) {
    XCTFail(@"Failed to register %@.", kInjectedDebugTokenClassName);
    return;
  }

  @try {
    // 1. When no env var or configstore file is present, FIRAppCheckInjectedDebugToken wins over
    // NSUserDefaults.
    [[GULUserDefaults standardUserDefaults] setObject:@"stored_user_defaults_token_555"
                                               forKey:kDebugTokenUserDefaultsKey];

    FIRApp *app = [self createValidTestApp];
    FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
    XCTAssertNotNil(provider);
    XCTAssertEqualObjects([provider currentDebugToken], @"injected_debug_token_444");
    XCTAssertEqualObjects([provider.debugProvider currentDebugToken], @"injected_debug_token_444");
    XCTAssertEqualObjects(provider.resolvedTokenSource,
                          @"build-time injection (FIRAppCheckInjectedDebugToken)");

#if TARGET_OS_SIMULATOR || TARGET_OS_OSX
    // 2. When configstore file is present in SIMULATOR_HOST_HOME, it takes priority over
    // FIRAppCheckInjectedDebugToken.
    [self writeLocalConfigFileWithContents:
              @"{\"tokens\":{\"test_app_id\":\"configstore_token_333\"}}"];
    FIRAppCheckDebugProvider *providerWithConfigFile =
        [[FIRAppCheckDebugProvider alloc] initWithApp:app];
    XCTAssertEqualObjects([providerWithConfigFile currentDebugToken], @"configstore_token_333");
    XCTAssertEqualObjects(providerWithConfigFile.resolvedTokenSource,
                          @"~/.config/configstore/firebase-appcheck.json");
#endif  // TARGET_OS_SIMULATOR || TARGET_OS_OSX
  } @finally {
    [self disposeInjectedDebugTokenClass:injectedClass];
  }
}

- (void)testResolveTokenFromInjectedTokensDictionaryIsKeyedByAppID {
  Class injectedClass =
      [self registerInjectedDebugTokenClassWithTokens:@{kAppID : @"injected_tokens_777"} token:nil];
  if (!injectedClass) {
    XCTFail(@"Failed to register %@.", kInjectedDebugTokenClassName);
    return;
  }

  @try {
    NSString *source = nil;
    XCTAssertEqualObjects([FIRAppCheckDebugProvider resolveDebugTokenForAppID:kAppID
                                                                       source:&source],
                          @"injected_tokens_777");
    XCTAssertEqualObjects(source, @"build-time injection (FIRAppCheckInjectedDebugToken)");

    // A token injected for one app must not be used for another app.
    source = nil;
    XCTAssertNil([FIRAppCheckDebugProvider resolveDebugTokenForAppID:@"other_app_id"
                                                              source:&source]);
    XCTAssertNil(source);
  } @finally {
    [self disposeInjectedDebugTokenClass:injectedClass];
  }
}

- (void)testResolveTokenFallsBackToNSUserDefaultsAndAutoGeneratedUUID {
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;

  // 1. Pre-existing token in GULUserDefaults -> source is "NSUserDefaults".
  [[GULUserDefaults standardUserDefaults] setObject:@"cached_defaults_token_555"
                                             forKey:kDebugTokenUserDefaultsKey];
  FIRApp *app = [self createValidTestApp];
  FIRAppCheckDebugProvider *cachedProvider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  XCTAssertEqualObjects([cachedProvider currentDebugToken], @"cached_defaults_token_555");
  XCTAssertEqualObjects(cachedProvider.resolvedTokenSource, @"NSUserDefaults");

  // 2. No token in GULUserDefaults -> source is "auto-generated UUID".
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kDebugTokenUserDefaultsKey];
  FIRAppCheckDebugProvider *generatedProvider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  XCTAssertTrue([generatedProvider currentDebugToken].length > 0);
  XCTAssertEqualObjects(generatedProvider.resolvedTokenSource, @"auto-generated UUID");
}

#pragma mark - Logging

- (void)testDebugTokenMessageNeverIncludesExternallyProvidedToken {
  // The strict mock fails the test if the local token is queried.
  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc]
      initWithDebugProvider:self.debugProviderMock
                  projectID:kProjectID
                googleAppID:kAppID
         resolvedDebugToken:@"ci_secret_token_999"
        resolvedTokenSource:@"environment variable (FIREBASE_APPCHECK_DEBUG_TOKEN)"];

  NSString *message = [provider debugTokenMessageWithPrefix:@"Failed to exchange debug token. "];

  XCTAssertNotNil(message);
  XCTAssertFalse([message containsString:@"ci_secret_token_999"]);
  XCTAssertTrue([message containsString:@"environment variable (FIREBASE_APPCHECK_DEBUG_TOKEN)"]);
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testDebugTokenMessageIncludesLocallyGeneratedToken {
  OCMStub([self.debugProviderMock localDebugToken]).andReturn(@"local_debug_token_123");
  FIRAppCheckDebugProvider *provider =
      [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock
                                                    projectID:kProjectID
                                                  googleAppID:kAppID];

  NSString *message = [provider debugTokenMessageWithPrefix:@""];

  XCTAssertTrue([message containsString:@"local_debug_token_123"]);
}

#pragma mark - HTTP 403 Handling

- (void)testIsHTTP403ErrorOnlyMatchesHTTPStatusCode {
  NSString *URLString = @"https://firebaseappcheck.googleapis.com/v1/projects/p/apps/a";
  GACAppCheckHTTPError *http403Error = [self HTTPErrorWithStatusCode:403
                                                           URLString:URLString
                                                                body:@"Forbidden"];
  XCTAssertTrue([FIRAppCheckDebugProvider isHTTP403Error:http403Error]);

  GACAppCheckHTTPError *http500Error = [self HTTPErrorWithStatusCode:500
                                                           URLString:URLString
                                                                body:nil];
  XCTAssertFalse([FIRAppCheckDebugProvider isHTTP403Error:http500Error]);

  // The error description contains the request URL and body; "403" in either is not a 403.
  GACAppCheckHTTPError *http503ErrorMentioning403 =
      [self HTTPErrorWithStatusCode:503
                          URLString:@"https://firebaseappcheck.googleapis.com/v1/projects/proj-403/"
                                    @"apps/1:1403:ios:403abc:exchangeDebugToken"
                               body:@"{\"error\":{\"message\":\"retry after 403 ms\"}}"];
  XCTAssertFalse([FIRAppCheckDebugProvider isHTTP403Error:http503ErrorMentioning403]);

  // A non-HTTP error that happens to use code 403 is not an HTTP 403.
  NSError *otherDomainError =
      [NSError errorWithDomain:@"OtherDomain"
                          code:403
                      userInfo:@{NSLocalizedFailureReasonErrorKey : @"status code: 403"}];
  XCTAssertFalse([FIRAppCheckDebugProvider isHTTP403Error:otherDomainError]);

  // An HTTP 403 wrapped as an underlying error is detected.
  NSError *wrappedError = [NSError errorWithDomain:@"WrapperDomain"
                                              code:0
                                          userInfo:@{NSUnderlyingErrorKey : http403Error}];
  XCTAssertTrue([FIRAppCheckDebugProvider isHTTP403Error:wrappedError]);

  XCTAssertFalse([FIRAppCheckDebugProvider isHTTP403Error:nil]);
}

- (void)testGetTokenHTTP403ErrorWithExternallyProvidedToken {
  GACAppCheckHTTPError *http403Error =
      [self HTTPErrorWithStatusCode:403
                          URLString:@"https://firebaseappcheck.googleapis.com/v1/projects/p/apps/a"
                               body:@"Forbidden"];
  // The strict mock fails the test if the failure path falls back to querying the local token.
  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc]
      initWithDebugProvider:self.debugProviderMock
                  projectID:kProjectID
                googleAppID:kAppID
         resolvedDebugToken:@"configstore_token_333"
        resolvedTokenSource:@"~/.config/configstore/firebase-appcheck.json"];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], http403Error, nil])]);

  [provider getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertEqualObjects(error, http403Error);
  }];

  OCMVerifyAll(self.debugProviderMock);
}

@end
