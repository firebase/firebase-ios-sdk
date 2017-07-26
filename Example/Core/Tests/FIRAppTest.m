// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FIRTestCase.h"

#import "FirebaseCommunity/FIRAppInternal.h"
#import "FirebaseCommunity/FIROptionsInternal.h"

NSString *const kFIRTestAppName1 = @"test_app_name_1";
NSString *const kFIRTestAppName2 = @"test-app-name-2";

@interface FIRApp (TestInternal)

@property(nonatomic) BOOL alreadySentConfigureNotification;
@property(nonatomic) BOOL alreadySentDeleteNotification;

+ (void)resetApps;
- (instancetype)initInstanceWithName:(NSString *)name options:(FIROptions *)options;
- (BOOL)configureCore;
+ (NSError *)errorForInvalidAppID;
- (BOOL)isAppIDValid;
+ (NSString *)actualBundleID;
+ (NSNumber *)mapFromServiceStringToTypeEnum:(NSString *)serviceString;
+ (NSString *)deviceModel;
+ (NSString *)installString;
+ (NSURL *)filePathURLWithName:(NSString *)fileName;
+ (NSString *)stringAtURL:(NSURL *)filePathURL;
+ (BOOL)writeString:(NSString *)string toURL:(NSURL *)filePathURL;
+ (void)logAppInfo:(NSNotification *)notification;
+ (BOOL)validateAppID:(NSString *)appID;
+ (BOOL)validateAppIDFormat:(NSString *)appID withVersion:(NSString *)version;
+ (BOOL)validateAppIDFingerprint:(NSString *)appID withVersion:(NSString *)version;

@end

@interface FIRAppTest : FIRTestCase

@property(nonatomic) id appClassMock;
@property(nonatomic) id optionsInstanceMock;
@property(nonatomic) id notificationCenterMock;
@property(nonatomic) FIRApp *app;

@end

@implementation FIRAppTest

- (void)setUp {
  [super setUp];
  [FIROptions resetDefaultOptions];
  [FIRApp resetApps];
  _appClassMock = OCMClassMock([FIRApp class]);
  _optionsInstanceMock = OCMPartialMock([FIROptions defaultOptions]);
  _notificationCenterMock = OCMPartialMock([NSNotificationCenter defaultCenter]);
}

- (void)tearDown {
  [_appClassMock stopMocking];
  [_optionsInstanceMock stopMocking];
  [_notificationCenterMock stopMocking];

  [super tearDown];
}

- (void)testConfigure {
  NSDictionary *expectedUserInfo =
      [self expectedUserInfoWithAppName:kFIRDefaultAppName isDefaultApp:YES];
  OCMExpect([self.notificationCenterMock postNotificationName:kFIRAppReadyToConfigureSDKNotification
                                                       object:[FIRApp class]
                                                     userInfo:expectedUserInfo]);
  XCTAssertNoThrow([FIRApp configure]);
  OCMVerifyAll(self.notificationCenterMock);

  self.app = [FIRApp defaultApp];
  XCTAssertNotNil(self.app);
  XCTAssertEqualObjects(self.app.name, kFIRDefaultAppName);
  XCTAssertEqualObjects(self.app.options.clientID, kClientID);
  XCTAssertTrue([FIRApp allApps].count == 1);
  XCTAssertTrue(self.app.alreadySentConfigureNotification);

  // Test if options is nil
  id optionsClassMock = OCMClassMock([FIROptions class]);
  OCMStub([optionsClassMock defaultOptions]).andReturn(nil);
  XCTAssertThrows([FIRApp configure]);
}

- (void)testConfigureWithOptions {
  // nil options
  XCTAssertThrows([FIRApp configureWithOptions:nil]);
  XCTAssertTrue([FIRApp allApps].count == 0);

  NSDictionary *expectedUserInfo =
      [self expectedUserInfoWithAppName:kFIRDefaultAppName isDefaultApp:YES];
  OCMExpect([self.notificationCenterMock postNotificationName:kFIRAppReadyToConfigureSDKNotification
                                                       object:[FIRApp class]
                                                     userInfo:expectedUserInfo]);
  // default options
  XCTAssertNoThrow([FIRApp configureWithOptions:[FIROptions defaultOptions]]);
  OCMVerifyAll(self.notificationCenterMock);

  self.app = [FIRApp defaultApp];
  XCTAssertNotNil(self.app);
  XCTAssertEqualObjects(self.app.name, kFIRDefaultAppName);
  XCTAssertEqualObjects(self.app.options.clientID, kClientID);
  XCTAssertTrue([FIRApp allApps].count == 1);
}

- (void)testConfigureWithCustomizedOptions {
  // valid customized options
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                       bundleID:kBundleID
                                                    GCMSenderID:kGCMSenderID
                                                         APIKey:kCustomizedAPIKey
                                                       clientID:nil
                                                     trackingID:nil
                                                androidClientID:nil
                                                    databaseURL:nil
                                                  storageBucket:nil
                                              deepLinkURLScheme:nil];

  NSDictionary *expectedUserInfo =
      [self expectedUserInfoWithAppName:kFIRDefaultAppName isDefaultApp:YES];
  OCMExpect([self.notificationCenterMock postNotificationName:kFIRAppReadyToConfigureSDKNotification
                                                       object:[FIRApp class]
                                                     userInfo:expectedUserInfo]);

  XCTAssertNoThrow([FIRApp configureWithOptions:options]);
  OCMVerifyAll(self.notificationCenterMock);

  self.app = [FIRApp defaultApp];
  XCTAssertNotNil(self.app);
  XCTAssertEqualObjects(self.app.name, kFIRDefaultAppName);
  XCTAssertEqualObjects(self.app.options.googleAppID, kGoogleAppID);
  XCTAssertEqualObjects(self.app.options.APIKey, kCustomizedAPIKey);
  XCTAssertTrue([FIRApp allApps].count == 1);
}

- (void)testConfigureWithNameAndOptions {
  XCTAssertThrows([FIRApp configureWithName:nil options:[FIROptions defaultOptions]]);
  XCTAssertThrows([FIRApp configureWithName:kFIRTestAppName1 options:nil]);
  XCTAssertThrows([FIRApp configureWithName:@"" options:[FIROptions defaultOptions]]);
  XCTAssertThrows(
      [FIRApp configureWithName:kFIRDefaultAppName options:[FIROptions defaultOptions]]);
  XCTAssertTrue([FIRApp allApps].count == 0);

  NSDictionary *expectedUserInfo =
      [self expectedUserInfoWithAppName:kFIRTestAppName1 isDefaultApp:NO];
  OCMExpect([self.notificationCenterMock postNotificationName:kFIRAppReadyToConfigureSDKNotification
                                                       object:[FIRApp class]
                                                     userInfo:expectedUserInfo]);
  XCTAssertNoThrow([FIRApp configureWithName:kFIRTestAppName1 options:[FIROptions defaultOptions]]);
  OCMVerifyAll(self.notificationCenterMock);

  XCTAssertTrue([FIRApp allApps].count == 1);
  self.app = [FIRApp appNamed:kFIRTestAppName1];
  XCTAssertNotNil(self.app);
  XCTAssertEqualObjects(self.app.name, kFIRTestAppName1);
  XCTAssertEqualObjects(self.app.options.clientID, kClientID);

  // Configure the same app again should throw an exception.
  XCTAssertThrows([FIRApp configureWithName:kFIRTestAppName1 options:[FIROptions defaultOptions]]);
}

- (void)testConfigureWithNameAndCustomizedOptions {
  FIROptions *options = [FIROptions defaultOptions];
  FIROptions *newOptions = [options copy];
  newOptions.deepLinkURLScheme = kDeepLinkURLScheme;

  NSDictionary *expectedUserInfo1 =
      [self expectedUserInfoWithAppName:kFIRTestAppName1 isDefaultApp:NO];
  OCMExpect([self.notificationCenterMock postNotificationName:kFIRAppReadyToConfigureSDKNotification
                                                       object:[FIRApp class]
                                                     userInfo:expectedUserInfo1]);
  XCTAssertNoThrow([FIRApp configureWithName:kFIRTestAppName1 options:newOptions]);
  XCTAssertTrue([FIRApp allApps].count == 1);
  self.app = [FIRApp appNamed:kFIRTestAppName1];

  // Configure a different app with valid customized options
  FIROptions *customizedOptions = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                                 bundleID:kBundleID
                                                              GCMSenderID:kGCMSenderID
                                                                   APIKey:kCustomizedAPIKey
                                                                 clientID:nil
                                                               trackingID:nil
                                                          androidClientID:nil
                                                              databaseURL:nil
                                                            storageBucket:nil
                                                        deepLinkURLScheme:nil];

  NSDictionary *expectedUserInfo2 =
      [self expectedUserInfoWithAppName:kFIRTestAppName2 isDefaultApp:NO];
  OCMExpect([self.notificationCenterMock postNotificationName:kFIRAppReadyToConfigureSDKNotification
                                                       object:[FIRApp class]
                                                     userInfo:expectedUserInfo2]);
  XCTAssertNoThrow([FIRApp configureWithName:kFIRTestAppName2 options:customizedOptions]);
  OCMVerifyAll(self.notificationCenterMock);

  XCTAssertTrue([FIRApp allApps].count == 2);
  self.app = [FIRApp appNamed:kFIRTestAppName2];
  XCTAssertNotNil(self.app);
  XCTAssertEqualObjects(self.app.name, kFIRTestAppName2);
  XCTAssertEqualObjects(self.app.options.googleAppID, kGoogleAppID);
  XCTAssertEqualObjects(self.app.options.APIKey, kCustomizedAPIKey);
}

- (void)testValidName {
  XCTAssertNoThrow([FIRApp configureWithName:@"aA1_" options:[FIROptions defaultOptions]]);
  XCTAssertThrows([FIRApp configureWithName:@"aA1%" options:[FIROptions defaultOptions]]);
  XCTAssertThrows([FIRApp configureWithName:@"aA1?" options:[FIROptions defaultOptions]]);
  XCTAssertThrows([FIRApp configureWithName:@"aA1!" options:[FIROptions defaultOptions]]);
}

- (void)testDefaultApp {
  self.app = [FIRApp defaultApp];
  XCTAssertNil(self.app);

  [FIRApp configure];
  self.app = [FIRApp defaultApp];
  XCTAssertEqualObjects(self.app.name, kFIRDefaultAppName);
  XCTAssertEqualObjects(self.app.options.clientID, kClientID);
}

- (void)testAppNamed {
  self.app = [FIRApp appNamed:kFIRTestAppName1];
  XCTAssertNil(self.app);

  [FIRApp configureWithName:kFIRTestAppName1 options:[FIROptions defaultOptions]];
  self.app = [FIRApp appNamed:kFIRTestAppName1];
  XCTAssertEqualObjects(self.app.name, kFIRTestAppName1);
  XCTAssertEqualObjects(self.app.options.clientID, kClientID);
}

- (void)testDeleteApp {
  [FIRApp configure];
  self.app = [FIRApp defaultApp];
  XCTAssertTrue([FIRApp allApps].count == 1);
  [self.app deleteApp:^(BOOL success) {
    XCTAssertTrue(success);
  }];
  OCMVerify([self.notificationCenterMock postNotificationName:kFIRAppDeleteNotification
                                                       object:[FIRApp class]
                                                     userInfo:[OCMArg any]]);
  XCTAssertTrue(self.app.alreadySentDeleteNotification);
  XCTAssertTrue([FIRApp allApps].count == 0);
}

- (void)testErrorForSubspecConfigurationFailure {
  NSError *error = [FIRApp errorForSubspecConfigurationFailureWithDomain:kFirebaseAdMobErrorDomain
                                                               errorCode:FIRErrorCodeAdMobFailed
                                                                 service:kFIRServiceAdMob
                                                                  reason:@"some reason"];
  XCTAssertNotNil(error);
  XCTAssert([error.domain isEqualToString:kFirebaseAdMobErrorDomain]);
  XCTAssert(error.code == FIRErrorCodeAdMobFailed);
  XCTAssert([error.description containsString:@"Configuration failed for"]);
}

- (void)testGetTokenWithCallback {
  [FIRApp configure];
  FIRApp *app = [FIRApp defaultApp];

  __block BOOL getTokenImplementationWasCalled = NO;
  __block BOOL getTokenCallbackWasCalled = NO;
  __block BOOL passedRefreshValue = NO;

  [app getTokenForcingRefresh:YES
                 withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                   getTokenCallbackWasCalled = YES;
                 }];

  XCTAssert(getTokenCallbackWasCalled,
            @"The callback should be invoked by the base implementation when no block for "
             "'getTokenImplementation' has been specified.");

  getTokenCallbackWasCalled = NO;

  app.getTokenImplementation = ^(BOOL refresh, FIRTokenCallback callback) {
    getTokenImplementationWasCalled = YES;
    passedRefreshValue = refresh;
    callback(nil, nil);
  };
  [app getTokenForcingRefresh:YES
                 withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                   getTokenCallbackWasCalled = YES;
                 }];

  XCTAssert(getTokenImplementationWasCalled,
            @"The 'getTokenImplementation' block was never called.");
  XCTAssert(passedRefreshValue,
            @"The value for the 'refresh' parameter wasn't passed to the 'getTokenImplementation' "
             "block correctly.");
  XCTAssert(getTokenCallbackWasCalled,
            @"The 'getTokenImplementation' should have invoked the callback. This could be an "
             "error in this test, or the callback parameter may not have been passed to the "
             "implementation correctly.");

  getTokenImplementationWasCalled = NO;
  getTokenCallbackWasCalled = NO;
  passedRefreshValue = NO;

  [app getTokenForcingRefresh:NO
                 withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                   getTokenCallbackWasCalled = YES;
                 }];

  XCTAssertFalse(passedRefreshValue, @"The value for the 'refresh' parameter wasn't passed to the "
                                      "'getTokenImplementation' block correctly.");
}

- (void)testModifyingOptionsThrows {
  [FIRApp configure];
  FIROptions *options = [[FIRApp defaultApp] options];
  XCTAssertTrue(options.isEditingLocked);

  // Modification to every property should result in an exception.
  XCTAssertThrows(options.androidClientID = @"should_throw");
  XCTAssertThrows(options.APIKey = @"should_throw");
  XCTAssertThrows(options.bundleID = @"should_throw");
  XCTAssertThrows(options.clientID = @"should_throw");
  XCTAssertThrows(options.databaseURL = @"should_throw");
  XCTAssertThrows(options.deepLinkURLScheme = @"should_throw");
  XCTAssertThrows(options.GCMSenderID = @"should_throw");
  XCTAssertThrows(options.googleAppID = @"should_throw");
  XCTAssertThrows(options.projectID = @"should_throw");
  XCTAssertThrows(options.storageBucket = @"should_throw");
  XCTAssertThrows(options.trackingID = @"should_throw");
}

- (void)testOptionsLocking {
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID GCMSenderID:kGCMSenderID];
  options.projectID = kProjectID;
  options.databaseURL = kDatabaseURL;

  // Options should not be locked before they are used to configure a `FIRApp`.
  XCTAssertFalse(options.isEditingLocked);

  // The options returned should be locked after configuring `FIRApp`.
  [FIRApp configureWithOptions:options];
  FIROptions *optionsCopy = [[FIRApp defaultApp] options];
  XCTAssertTrue(optionsCopy.isEditingLocked);
}

#pragma mark - App ID v1

- (void)testAppIDV1 {
  // Missing separator between platform:fingerprint.
  XCTAssertFalse([FIRApp validateAppID:@"1:1337:iosdeadbeef"]);

  // Wrong platform "android".
  XCTAssertFalse([FIRApp validateAppID:@"1:1337:android:deadbeef"]);

  // The fingerprint, aka 4th field, should only contain hex characters.
  XCTAssertFalse([FIRApp validateAppID:@"1:1337:ios:123abcxyz"]);

  // The fingerprint, aka 4th field, is not tested in V1, so a bad value shouldn't cause a failure.
  XCTAssertTrue([FIRApp validateAppID:@"1:1337:ios:deadbeef"]);
}

#pragma mark - App ID v2

- (void)testAppIDV2 {
  // Missing separator between platform:fingerprint.
  XCTAssertTrue([FIRApp validateAppID:@"2:1337:ios5e18052ab54fbfec"]);

  // Unknown versions may contain anything.
  XCTAssertTrue([FIRApp validateAppID:@"2:1337:ios:123abcxyz"]);
  XCTAssertTrue([FIRApp validateAppID:@"2:thisdoesn'teven_m:a:t:t:e:r_"]);

  // Known good fingerprint.
  XCTAssertTrue([FIRApp validateAppID:@"2:1337:ios:5e18052ab54fbfec"]);

  // Unknown fingerprint, not tested so shouldn't cause a failure.
  XCTAssertTrue([FIRApp validateAppID:@"2:1337:ios:deadbeef"]);
}

#pragma mark - App ID other

- (void)testAppIDV3 {
  // Currently there is no specification for v3, so we would not expect it to fail.
  XCTAssertTrue([FIRApp validateAppID:@"3:1337:ios:deadbeef"]);
}

- (void)testAppIDEmpty {
  XCTAssertFalse([FIRApp validateAppID:@""]);
}

- (void)testAppIDValidationTrue {
  // Ensure that isAppIDValid matches validateAppID.
  [FIRApp configure];
  OCMStub([self.appClassMock validateAppID:[OCMArg any]]).andReturn(YES);
  XCTAssertTrue([[FIRApp defaultApp] isAppIDValid]);
}

- (void)testAppIDValidationFalse {
  // Ensure that isAppIDValid matches validateAppID.
  [FIRApp configure];
  OCMStub([self.appClassMock validateAppID:[OCMArg any]]).andReturn(NO);
  XCTAssertFalse([[FIRApp defaultApp] isAppIDValid]);
}

- (void)testAppIDPrefix {
  // Unknown numeric-character prefixes should pass.
  XCTAssertTrue([FIRApp validateAppID:@"0:"]);
  XCTAssertTrue([FIRApp validateAppID:@"01:"]);
  XCTAssertTrue([FIRApp validateAppID:@"10:"]);
  XCTAssertTrue([FIRApp validateAppID:@"010:"]);
  XCTAssertTrue([FIRApp validateAppID:@"3:"]);
  XCTAssertTrue([FIRApp validateAppID:@"123:"]);
  XCTAssertTrue([FIRApp validateAppID:@"999999999:"]);

  // Non-numeric prefixes should not pass.
  XCTAssertFalse([FIRApp validateAppID:@"a:"]);
  XCTAssertFalse([FIRApp validateAppID:@"abcsdf0:"]);
  XCTAssertFalse([FIRApp validateAppID:@"0aaaa:"]);
  XCTAssertFalse([FIRApp validateAppID:@"0aaaa0450:"]);
  XCTAssertFalse([FIRApp validateAppID:@"-1:"]);
  XCTAssertFalse([FIRApp validateAppID:@"abcsdf:"]);
  XCTAssertFalse([FIRApp validateAppID:@"ABDCF:"]);
  XCTAssertFalse([FIRApp validateAppID:@" :"]);
  XCTAssertFalse([FIRApp validateAppID:@"1 :"]);
  XCTAssertFalse([FIRApp validateAppID:@" 1:"]);
  XCTAssertFalse([FIRApp validateAppID:@" 123 :"]);
  XCTAssertFalse([FIRApp validateAppID:@"1 23:"]);
  XCTAssertFalse([FIRApp validateAppID:@"&($*&%(*$&:"]);
  XCTAssertFalse([FIRApp validateAppID:@"abCDSF$%%df:"]);

  // Known version prefixes should never pass without the rest of the app ID string present.
  XCTAssertFalse([FIRApp validateAppID:@"1:"]);

  // Version must include ":".
  XCTAssertFalse([FIRApp validateAppID:@"0"]);
  XCTAssertFalse([FIRApp validateAppID:@"01"]);
  XCTAssertFalse([FIRApp validateAppID:@"10"]);
  XCTAssertFalse([FIRApp validateAppID:@"010"]);
  XCTAssertFalse([FIRApp validateAppID:@"3"]);
  XCTAssertFalse([FIRApp validateAppID:@"123"]);
  XCTAssertFalse([FIRApp validateAppID:@"999999999"]);
  XCTAssertFalse([FIRApp validateAppID:@"com.google.bundleID"]);
}

- (void)testAppIDFormatInvalid {
  OCMStub([self.appClassMock actualBundleID]).andReturn(@"com.google.bundleID");
  // Some direct tests of the validateAppIDFormat:withVersion: method.
  // Sanity checks first.
  NSString *const kGoodAppIDV1 = @"1:1337:ios:deadbeef";
  NSString *const kGoodVersionV1 = @"1:";
  XCTAssertTrue([FIRApp validateAppIDFormat:kGoodAppIDV1 withVersion:kGoodVersionV1]);

  NSString *const kGoodAppIDV2 = @"2:1337:ios:5e18052ab54fbfec";
  NSString *const kGoodVersionV2 = @"2:";
  XCTAssertTrue([FIRApp validateAppIDFormat:kGoodAppIDV2 withVersion:kGoodVersionV2]);

  // Version mismatch.
  XCTAssertFalse([FIRApp validateAppIDFormat:kGoodAppIDV2 withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:kGoodAppIDV1 withVersion:kGoodVersionV2]);
  XCTAssertFalse([FIRApp validateAppIDFormat:kGoodAppIDV1 withVersion:@"999:"]);

  // Nil or empty strings.
  XCTAssertFalse([FIRApp validateAppIDFormat:kGoodAppIDV1 withVersion:nil]);
  XCTAssertFalse([FIRApp validateAppIDFormat:kGoodAppIDV1 withVersion:@""]);
  XCTAssertFalse([FIRApp validateAppIDFormat:nil withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:nil withVersion:nil]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"" withVersion:@""]);

  // App ID contains only the version prefix.
  XCTAssertFalse([FIRApp validateAppIDFormat:kGoodVersionV1 withVersion:kGoodVersionV1]);
  // The version is the entire app ID.
  XCTAssertFalse([FIRApp validateAppIDFormat:kGoodAppIDV1 withVersion:kGoodAppIDV1]);

  // Versions digits that may make a partial match.
  XCTAssertFalse([FIRApp validateAppIDFormat:@"01:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"10:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"11:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFormat:@"21:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);
  XCTAssertFalse(
      [FIRApp validateAppIDFormat:@"22:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);
  XCTAssertFalse(
      [FIRApp validateAppIDFormat:@"02:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);
  XCTAssertFalse(
      [FIRApp validateAppIDFormat:@"20:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);

  // Extra fields.
  XCTAssertFalse([FIRApp validateAppIDFormat:@"ab:1:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"1:ab:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"1:1337:ab:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"1:1337:ios:ab:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"1:1337:ios:deadbeef:ab" withVersion:kGoodVersionV1]);
}

- (void)testAppIDFingerprintInvalid {
  OCMStub([self.appClassMock actualBundleID]).andReturn(@"com.google.bundleID");
  // Some direct tests of the validateAppIDFingerprint:withVersion: method.
  // Sanity checks first.
  NSString *const kGoodAppIDV1 = @"1:1337:ios:deadbeef";
  NSString *const kGoodVersionV1 = @"1:";
  XCTAssertTrue([FIRApp validateAppIDFingerprint:kGoodAppIDV1 withVersion:kGoodVersionV1]);

  NSString *const kGoodAppIDV2 = @"2:1337:ios:5e18052ab54fbfec";
  NSString *const kGoodVersionV2 = @"2:";
  XCTAssertTrue([FIRApp validateAppIDFormat:kGoodAppIDV2 withVersion:kGoodVersionV2]);

  // Version mismatch.
  XCTAssertFalse([FIRApp validateAppIDFingerprint:kGoodAppIDV2 withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFingerprint:kGoodAppIDV1 withVersion:kGoodVersionV2]);
  XCTAssertFalse([FIRApp validateAppIDFingerprint:kGoodAppIDV1 withVersion:@"999:"]);

  // Nil or empty strings.
  XCTAssertFalse([FIRApp validateAppIDFingerprint:kGoodAppIDV1 withVersion:nil]);
  XCTAssertFalse([FIRApp validateAppIDFingerprint:kGoodAppIDV1 withVersion:@""]);
  XCTAssertFalse([FIRApp validateAppIDFingerprint:nil withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFingerprint:@"" withVersion:kGoodVersionV1]);
  XCTAssertFalse([FIRApp validateAppIDFingerprint:nil withVersion:nil]);
  XCTAssertFalse([FIRApp validateAppIDFingerprint:@"" withVersion:@""]);

  // App ID contains only the version prefix.
  XCTAssertFalse([FIRApp validateAppIDFingerprint:kGoodVersionV1 withVersion:kGoodVersionV1]);
  // The version is the entire app ID.
  XCTAssertFalse([FIRApp validateAppIDFingerprint:kGoodAppIDV1 withVersion:kGoodAppIDV1]);

  // Versions digits that may make a partial match.
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"01:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"10:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"11:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"21:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"22:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"02:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"20:1337:ios:5e18052ab54fbfec" withVersion:kGoodVersionV2]);
  // Extra fields.
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"ab:1:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"1:ab:1337:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"1:1337:ab:ios:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"1:1337:ios:ab:deadbeef" withVersion:kGoodVersionV1]);
  XCTAssertFalse(
      [FIRApp validateAppIDFingerprint:@"1:1337:ios:deadbeef:ab" withVersion:kGoodVersionV1]);
}

#pragma mark - Internal Methods

- (void)testAuthGetUID {
  [FIRApp configure];

  [FIRApp defaultApp].getUIDImplementation = ^NSString * { return @"highlander"; };
  XCTAssertEqual([[FIRApp defaultApp] getUID], @"highlander");
}

- (void)testIsAppConfigured {
  // Ensure it's false before anything is configured.
  XCTAssertFalse([FIRApp isDefaultAppConfigured]);

  // Configure it and ensure it's configured.
  [FIRApp configure];
  XCTAssertTrue([FIRApp isDefaultAppConfigured]);

  // Reset the apps and ensure it's not configured anymore.
  [FIRApp resetApps];
  XCTAssertFalse([FIRApp isDefaultAppConfigured]);
}

#pragma mark - private

- (NSDictionary<NSString *, NSObject *> *)expectedUserInfoWithAppName:(NSString *)name
                                                         isDefaultApp:(BOOL)isDefaultApp {
  return @{
    kFIRAppNameKey : name,
    kFIRAppIsDefaultAppKey : [NSNumber numberWithBool:isDefaultApp],
    kFIRGoogleAppIDKey : kGoogleAppID
  };
}

@end
