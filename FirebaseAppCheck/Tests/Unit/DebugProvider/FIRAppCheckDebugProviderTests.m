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

@interface FIRAppCheckDebugProvider (Tests)

- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider
                            projectID:(nullable NSString *)projectID
                          googleAppID:(NSString *)googleAppID;
@property(nonatomic, readonly) GACAppCheckDebugProvider *debugProvider;
@property(nonatomic, readonly, copy, nullable) NSString *projectID;
@property(nonatomic, readonly, copy) NSString *googleAppID;
@property(nonatomic, readonly, copy, nullable) NSString *resolvedDebugToken;
@property(nonatomic, readonly, copy, nullable) NSString *resolvedTokenSource;

+ (nullable NSString *)resolveDebugTokenForAppID:(NSString *)googleAppID
                                          source:(NSString *_Nullable *_Nullable)outSource;
+ (nullable NSString *)tokenFromInjectedClass:(nullable Class)injectedClass
                                     forAppID:(NSString *)googleAppID
                               isReleaseBuild:(BOOL)isReleaseBuild
                                       source:(NSString *_Nullable *_Nullable)outSource;
+ (BOOL)isHTTP403Error:(nullable NSError *)error;

@end

@interface FIRAppCheckDebugProviderTests : XCTestCase

@property(nonatomic, copy) NSString *resourceName;
@property(nonatomic) id debugProviderMock;
@property(nonatomic) FIRAppCheckDebugProvider *provider;
@property(nonatomic, copy) NSString *tempHostHomeDir;
@property(nonatomic, copy, nullable) NSString *savedSimulatorHostHome;

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

- (void)writeLocalConfigFileWithContents:(NSString *)contents {
  NSString *configDir =
      [self.tempHostHomeDir stringByAppendingPathComponent:@".config/configstore"];
  [[NSFileManager defaultManager] createDirectoryAtPath:configDir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  NSString *configPath = [configDir stringByAppendingPathComponent:@"firebase-appcheck.json"];
  [contents writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
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

#pragma mark - Debug Token Resolution Order & HTTP 403 Handling

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
}

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

  // Dynamically register FIRAppCheckInjectedDebugToken in the Objective-C runtime for this test.
  Class injectedClass =
      objc_allocateClassPair([NSObject class], "FIRAppCheckInjectedDebugToken", 0);
  XCTAssertNotNil(injectedClass);
  Class metaClass = object_getClass(injectedClass);
  IMP tokenIMP = imp_implementationWithBlock(^NSString *(id _self) {
    return @"injected_debug_token_444";
  });
  class_addMethod(metaClass, @selector(token), tokenIMP, "@@:");
  objc_registerClassPair(injectedClass);

  @try {
    // 1. When no env var or configstore file is present, FIRAppCheckInjectedDebugToken wins over
    // NSUserDefaults.
    [[GULUserDefaults standardUserDefaults] setObject:@"stored_user_defaults_token_555"
                                               forKey:@"GACAppCheckDebugToken"];

    FIRApp *app = [self createValidTestApp];
    FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
    XCTAssertNotNil(provider);
    XCTAssertEqualObjects([provider currentDebugToken], @"injected_debug_token_444");
    XCTAssertEqualObjects([provider.debugProvider currentDebugToken], @"injected_debug_token_444");
    XCTAssertEqualObjects(provider.resolvedTokenSource,
                          @"build-time injection (FIRAppCheckInjectedDebugToken)");

    // 2. When configstore file is present in SIMULATOR_HOST_HOME, it takes priority over
    // FIRAppCheckInjectedDebugToken.
    [self writeLocalConfigFileWithContents:
              @"{\"tokens\":{\"test_app_id\":\"configstore_token_333\"}}"];
    FIRAppCheckDebugProvider *providerWithConfigFile =
        [[FIRAppCheckDebugProvider alloc] initWithApp:app];
    XCTAssertEqualObjects([providerWithConfigFile currentDebugToken], @"configstore_token_333");
    XCTAssertEqualObjects(providerWithConfigFile.resolvedTokenSource,
                          @"~/.config/configstore/firebase-appcheck.json");

    // 3. In a Release build (isReleaseBuild = YES), the injected token is ignored with a warning.
    NSString *releaseSource = nil;
    NSString *releaseToken = [FIRAppCheckDebugProvider tokenFromInjectedClass:injectedClass
                                                                     forAppID:kAppID
                                                               isReleaseBuild:YES
                                                                       source:&releaseSource];
    XCTAssertNil(releaseToken);
    XCTAssertNil(releaseSource);
  } @finally {
    objc_disposeClassPair(injectedClass);
  }
}

- (void)testResolveTokenFallsBackToNSUserDefaultsAndAutoGeneratedUUID {
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;

  // 1. Pre-existing token in GULUserDefaults -> source is "NSUserDefaults".
  [[GULUserDefaults standardUserDefaults] setObject:@"cached_defaults_token_555"
                                             forKey:@"GACAppCheckDebugToken"];
  FIRApp *app = [self createValidTestApp];
  FIRAppCheckDebugProvider *cachedProvider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  XCTAssertEqualObjects([cachedProvider currentDebugToken], @"cached_defaults_token_555");
  XCTAssertEqualObjects(cachedProvider.resolvedTokenSource, @"NSUserDefaults");

  // 2. No token in GULUserDefaults -> source is "auto-generated UUID".
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:@"GACAppCheckDebugToken"];
  FIRAppCheckDebugProvider *generatedProvider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  XCTAssertTrue([generatedProvider currentDebugToken].length > 0);
  XCTAssertEqualObjects(generatedProvider.resolvedTokenSource, @"auto-generated UUID");
}

- (void)testGetTokenHTTP403ErrorDetectionAndHandling {
  NSURL *url =
      [NSURL URLWithString:@"https://firebaseappcheck.googleapis.com/v1/projects/p/apps/a"];
  NSHTTPURLResponse *http403Response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                                   statusCode:403
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:nil];
  GACAppCheckHTTPError *http403Error = [[GACAppCheckHTTPError alloc]
      initWithHTTPResponse:http403Response
                      data:[@"Forbidden" dataUsingEncoding:NSUTF8StringEncoding]];
  XCTAssertTrue([FIRAppCheckDebugProvider isHTTP403Error:http403Error]);

  NSHTTPURLResponse *http500Response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                                   statusCode:500
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:nil];
  GACAppCheckHTTPError *http500Error =
      [[GACAppCheckHTTPError alloc] initWithHTTPResponse:http500Response data:nil];
  XCTAssertFalse([FIRAppCheckDebugProvider isHTTP403Error:http500Error]);

  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], http403Error, nil])]);

  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, http403Error);
      }];

  OCMVerifyAll(self.debugProviderMock);
}

@end
