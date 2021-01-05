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

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"
#import "FirebaseCore/Tests/Unit/FIRTestComponents.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import "FirebaseCore/Sources/FIRAnalyticsConfiguration.h"
#import "FirebaseCore/Sources/Private/FIRAppInternal.h"
#import "FirebaseCore/Sources/Private/FIRComponentType.h"
#import "FirebaseCore/Sources/Private/FIRCoreDiagnosticsConnector.h"
#import "FirebaseCore/Sources/Private/FIROptionsInternal.h"
#import "SharedTestUtilities/FIROptionsMock.h"

NSString *const kFIRTestAppName1 = @"test_app_name_1";
NSString *const kFIRTestAppName2 = @"test-app-name-2";

@interface FIRApp (TestInternal)

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

+ (nullable NSNumber *)readDataCollectionSwitchFromPlist;
+ (nullable NSNumber *)readDataCollectionSwitchFromUserDefaultsForApp:(FIRApp *)app;

@end

@interface FIRAppTest : FIRTestCase

@property(nonatomic) id appClassMock;
@property(nonatomic) id observerMock;
@property(nonatomic) id mockCoreDiagnosticsConnector;
@property(nonatomic) NSNotificationCenter *notificationCenter;

@end

@implementation FIRAppTest

- (void)setUp {
  [super setUp];
  [FIROptions resetDefaultOptions];
  [FIRApp resetApps];
  _appClassMock = OCMClassMock([FIRApp class]);
  _observerMock = OCMObserverMock();
  _mockCoreDiagnosticsConnector = OCMClassMock([FIRCoreDiagnosticsConnector class]);

  [FIROptionsMock mockFIROptions];

  OCMStub(ClassMethod([self.mockCoreDiagnosticsConnector logCoreTelemetryWithOptions:[OCMArg any]]))
      .andDo(^(NSInvocation *invocation){
      });

  // TODO: Remove all usages of defaultCenter in Core, then we can instantiate an instance here to
  //       inject instead of using defaultCenter.
  _notificationCenter = [NSNotificationCenter defaultCenter];
}

- (void)tearDown {
  [_appClassMock stopMocking];
  [_notificationCenter removeObserver:_observerMock];
  _observerMock = nil;
  _notificationCenter = nil;
  _mockCoreDiagnosticsConnector = nil;

  [super tearDown];
}

- (void)testConfigure {
  [self registerLibrariesWithClasses:@[
    [FIRTestClassCached class], [FIRTestClassEagerCached class]
  ]];

  NSDictionary *expectedUserInfo = [self expectedUserInfoWithAppName:kFIRDefaultAppName
                                                        isDefaultApp:YES];
  [self expectNotificationForObserver:self.observerMock
                     notificationName:kFIRAppReadyToConfigureSDKNotification
                               object:[FIRApp class]
                             userInfo:expectedUserInfo];
  XCTAssertNoThrow([FIRApp configure]);
  OCMVerifyAll(self.observerMock);

  FIRApp *app = [FIRApp defaultApp];
  XCTAssertNotNil(app);
  XCTAssertEqualObjects(app.name, kFIRDefaultAppName);
  XCTAssertEqualObjects(app.options.clientID, kClientID);
  XCTAssertTrue([FIRApp allApps].count == 1);

  // Check the registered libraries instances available.
  XCTAssertNotNil(FIR_COMPONENT(FIRTestProtocolCached, app.container));
  XCTAssertNotNil(FIR_COMPONENT(FIRTestProtocolEagerCached, app.container));
  XCTAssertNil(FIR_COMPONENT(FIRTestProtocol, app.container));
}

- (void)testConfigureWithNoDefaultOptions {
  id optionsClassMock = OCMClassMock([FIROptions class]);
  OCMStub([optionsClassMock defaultOptions]).andReturn(nil);
  XCTAssertThrows([FIRApp configure]);
}

- (void)testConfigureWithOptions {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  // Test `nil` options.
  XCTAssertThrows([FIRApp configureWithOptions:nil]);
#pragma clang diagnostic pop
  XCTAssertTrue([FIRApp allApps].count == 0);

  NSDictionary *expectedUserInfo = [self expectedUserInfoWithAppName:kFIRDefaultAppName
                                                        isDefaultApp:YES];
  [self expectNotificationForObserver:self.observerMock
                     notificationName:kFIRAppReadyToConfigureSDKNotification
                               object:[FIRApp class]
                             userInfo:expectedUserInfo];

  // Use a valid instance of options.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  options.clientID = kClientID;
  XCTAssertNoThrow([FIRApp configureWithOptions:options]);
  OCMVerifyAll(self.observerMock);

  // Verify the default app instance is created.
  FIRApp *app = [FIRApp defaultApp];
  XCTAssertNotNil(app);
  XCTAssertEqualObjects(app.name, kFIRDefaultAppName);
  XCTAssertEqualObjects(app.options.googleAppID, kGoogleAppID);
  XCTAssertEqualObjects(app.options.GCMSenderID, kGCMSenderID);
  XCTAssertEqualObjects(app.options.clientID, kClientID);
  XCTAssertTrue([FIRApp allApps].count == 1);
}

- (void)testConfigureWithNameAndOptions {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  options.clientID = kClientID;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertThrows([FIRApp configureWithName:nil options:options]);
  XCTAssertThrows([FIRApp configureWithName:kFIRTestAppName1 options:nil]);
#pragma clang diagnostic pop
  XCTAssertThrows([FIRApp configureWithName:@"" options:options]);
  XCTAssertTrue([FIRApp allApps].count == 0);

  NSDictionary *expectedUserInfo = [self expectedUserInfoWithAppName:kFIRTestAppName1
                                                        isDefaultApp:NO];
  [self expectNotificationForObserver:self.observerMock
                     notificationName:kFIRAppReadyToConfigureSDKNotification
                               object:[FIRApp class]
                             userInfo:expectedUserInfo];
  XCTAssertNoThrow([FIRApp configureWithName:kFIRTestAppName1 options:options]);
  OCMVerifyAll(self.observerMock);

  XCTAssertTrue([FIRApp allApps].count == 1);
  FIRApp *app = [FIRApp appNamed:kFIRTestAppName1];
  XCTAssertNotNil(app);
  XCTAssertEqualObjects(app.name, kFIRTestAppName1);
  XCTAssertEqualObjects(app.options.clientID, kClientID);

  // Configure the same app again should throw an exception.
  XCTAssertThrows([FIRApp configureWithName:kFIRTestAppName1 options:options]);
}

- (void)testConfigureWithMultipleApps {
  FIROptions *options1 = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                     GCMSenderID:kGCMSenderID];
  options1.deepLinkURLScheme = kDeepLinkURLScheme;

  // Set up notification center observer for verifying notifications.
  [self.notificationCenter addMockObserver:self.observerMock
                                      name:kFIRAppReadyToConfigureSDKNotification
                                    object:[FIRApp class]];

  NSDictionary *expectedUserInfo1 = [self expectedUserInfoWithAppName:kFIRTestAppName1
                                                         isDefaultApp:NO];
  [[self.observerMock expect] notificationWithName:kFIRAppReadyToConfigureSDKNotification
                                            object:[FIRApp class]
                                          userInfo:expectedUserInfo1];
  XCTAssertNoThrow([FIRApp configureWithName:kFIRTestAppName1 options:options1]);
  XCTAssertTrue([FIRApp allApps].count == 1);

  // Configure a different app with valid customized options.
  FIROptions *options2 = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                     GCMSenderID:kGCMSenderID];
  options2.bundleID = kBundleID;
  options2.APIKey = kCustomizedAPIKey;

  NSDictionary *expectedUserInfo2 = [self expectedUserInfoWithAppName:kFIRTestAppName2
                                                         isDefaultApp:NO];
  [[self.observerMock expect] notificationWithName:kFIRAppReadyToConfigureSDKNotification
                                            object:[FIRApp class]
                                          userInfo:expectedUserInfo2];

  [self.observerMock setExpectationOrderMatters:YES];
  XCTAssertNoThrow([FIRApp configureWithName:kFIRTestAppName2 options:options2]);
  OCMVerifyAll(self.observerMock);

  XCTAssertTrue([FIRApp allApps].count == 2);
  FIRApp *app = [FIRApp appNamed:kFIRTestAppName2];
  XCTAssertNotNil(app);
  XCTAssertEqualObjects(app.name, kFIRTestAppName2);
  XCTAssertEqualObjects(app.options.googleAppID, kGoogleAppID);
  XCTAssertEqualObjects(app.options.APIKey, kCustomizedAPIKey);
}

- (void)testConfigureThrowsAfterConfigured {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  [FIRApp configureWithOptions:options];
  XCTAssertNotNil([FIRApp defaultApp]);

  // A second configure call should throw, since Firebase is already configured.
  XCTAssertThrows([FIRApp configureWithOptions:options]);

  // Test the same with a custom named app.
  [FIRApp configureWithName:kFIRTestAppName1 options:options];
  XCTAssertNotNil([FIRApp appNamed:kFIRTestAppName1]);

  // A second configure call should throw, since Firebase is already configured.
  XCTAssertThrows([FIRApp configureWithName:kFIRTestAppName1 options:options]);
}

- (void)testConfigureDefaultAppInExtension {
  id environmentMock = OCMClassMock([GULAppEnvironmentUtil class]);
  OCMStub([environmentMock isAppExtension]).andReturn(YES);

  // Set up the default app like a standard app.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  [FIRApp configureWithOptions:options];
  XCTAssertNotNil([FIRApp defaultApp]);
  XCTAssertEqual([FIRApp allApps].count, 1);

  // Configuring with the same set of options shouldn't throw.
  XCTAssertNoThrow([FIRApp configureWithOptions:options]);

  // Only 1 app should have been configured still, the default app.
  XCTAssertNotNil([FIRApp defaultApp]);
  XCTAssertEqual([FIRApp allApps].count, 1);

  // Use a set of a different options to call configure again, which should throw.
  FIROptions *differentOptions = [[FIROptions alloc] initWithGoogleAppID:@"1:789:ios:789XYZ"
                                                             GCMSenderID:kGCMSenderID];
  XCTAssertThrows([FIRApp configureWithOptions:differentOptions]);
  XCTAssertEqual([FIRApp allApps].count, 1);

  // Explicily stop the environmentMock.
  [environmentMock stopMocking];
  environmentMock = nil;
}

- (void)testConfigureCustomAppInExtension {
  id environmentMock = OCMClassMock([GULAppEnvironmentUtil class]);
  OCMStub([environmentMock isAppExtension]).andReturn(YES);

  // Set up a custom named app like a standard app.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  [FIRApp configureWithName:kFIRTestAppName1 options:options];
  XCTAssertNotNil([FIRApp appNamed:kFIRTestAppName1]);
  XCTAssertEqual([FIRApp allApps].count, 1);

  // Configuring with the same set of options shouldn't throw.
  XCTAssertNoThrow([FIRApp configureWithName:kFIRTestAppName1 options:options]);

  // Only 1 app should have been configured still.
  XCTAssertNotNil([FIRApp appNamed:kFIRTestAppName1]);
  XCTAssertEqual([FIRApp allApps].count, 1);

  // Use a set of a different options to call configure again, which should throw.
  FIROptions *differentOptions = [[FIROptions alloc] initWithGoogleAppID:@"1:789:ios:789XYZ"
                                                             GCMSenderID:kGCMSenderID];
  XCTAssertThrows([FIRApp configureWithName:kFIRTestAppName1 options:differentOptions]);
  XCTAssertEqual([FIRApp allApps].count, 1);

  // Explicily stop the environmentMock.
  [environmentMock stopMocking];
  environmentMock = nil;
}

- (void)testValidName {
  XCTAssertNoThrow([FIRApp configureWithName:@"aA1_" options:[FIROptions defaultOptions]]);
  XCTAssertNoThrow([FIRApp configureWithName:@"aA1-" options:[FIROptions defaultOptions]]);
  XCTAssertNoThrow([FIRApp configureWithName:@"aAē1_" options:[FIROptions defaultOptions]]);
  XCTAssertThrows([FIRApp configureWithName:@"aA1%" options:[FIROptions defaultOptions]]);
  XCTAssertThrows([FIRApp configureWithName:@"aA1?" options:[FIROptions defaultOptions]]);
  XCTAssertThrows([FIRApp configureWithName:@"aA1!" options:[FIROptions defaultOptions]]);
}

- (void)testDefaultApp {
  FIRApp *app = [FIRApp defaultApp];
  XCTAssertNil(app);

  [FIRApp configure];
  app = [FIRApp defaultApp];
  XCTAssertEqualObjects(app.name, kFIRDefaultAppName);
  XCTAssertEqualObjects(app.options.clientID, kClientID);
}

- (void)testAppNamed {
  FIRApp *app = [FIRApp appNamed:kFIRTestAppName1];
  XCTAssertNil(app);

  [FIRApp configureWithName:kFIRTestAppName1 options:[FIROptions defaultOptions]];
  app = [FIRApp appNamed:kFIRTestAppName1];
  XCTAssertEqualObjects(app.name, kFIRTestAppName1);
  XCTAssertEqualObjects(app.options.clientID, kClientID);
}

- (void)testDeleteApp {
  [self registerLibrariesWithClasses:@[
    [FIRTestClassCached class], [FIRTestClassEagerCached class]
  ]];

  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  [FIRApp configureWithName:name options:options];
  FIRApp *app = [FIRApp appNamed:name];
  XCTAssertNotNil(app);
  XCTAssertTrue([FIRApp allApps].count == 1);

  // Check the registered libraries instances available.
  XCTAssertNotNil(FIR_COMPONENT(FIRTestProtocolCached, app.container));
  XCTAssertNotNil(FIR_COMPONENT(FIRTestProtocolEagerCached, app.container));
  XCTAssertNil(FIR_COMPONENT(FIRTestProtocol, app.container));

  [self expectNotificationForObserver:self.observerMock
                     notificationName:kFIRAppDeleteNotification
                               object:[FIRApp class]
                             userInfo:[OCMArg any]];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Deleting the app should succeed."];
  [app deleteApp:^(BOOL success) {
    XCTAssertTrue(success);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:1];
  OCMVerifyAll(self.observerMock);
  XCTAssertTrue([FIRApp allApps].count == 0);

  // Check no new library instances created after the app delete.
  XCTAssertNil(FIR_COMPONENT(FIRTestProtocolCached, app.container));
  XCTAssertNil(FIR_COMPONENT(FIRTestProtocolEagerCached, app.container));
}

- (void)testOptionsLocking {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  options.projectID = kProjectID;
  options.databaseURL = kDatabaseURL;

  // Options should not be locked before they are used to configure a `FIRApp`.
  XCTAssertFalse(options.isEditingLocked);

  // The options returned should be locked after configuring `FIRApp`.
  NSString *name = NSStringFromSelector(_cmd);
  [FIRApp configureWithName:name options:options];
  FIROptions *optionsCopy = [[FIRApp appNamed:name] options];
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
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"" GCMSenderID:@""];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:NSStringFromSelector(_cmd) options:options];
  OCMStub([self.appClassMock validateAppID:[OCMArg any]]).andReturn(YES);
  XCTAssertTrue([app isAppIDValid]);
}

- (void)testAppIDValidationFalse {
  // Ensure that isAppIDValid matches validateAppID.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"" GCMSenderID:@""];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:NSStringFromSelector(_cmd) options:options];
  OCMStub([self.appClassMock validateAppID:[OCMArg any]]).andReturn(NO);
  XCTAssertFalse([app isAppIDValid]);
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
  NSString *const kGoodVersionV1 = @"1";
  XCTAssertTrue([FIRApp validateAppIDFormat:kGoodAppIDV1 withVersion:kGoodVersionV1]);

  NSString *const kGoodAppIDV2 = @"2:1337:ios:5e18052ab54fbfec";
  NSString *const kGoodVersionV2 = @"2";
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
  XCTAssertFalse([FIRApp validateAppIDFormat:@"21:1337:ios:5e18052ab54fbfec"
                                 withVersion:kGoodVersionV2]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"22:1337:ios:5e18052ab54fbfec"
                                 withVersion:kGoodVersionV2]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"02:1337:ios:5e18052ab54fbfec"
                                 withVersion:kGoodVersionV2]);
  XCTAssertFalse([FIRApp validateAppIDFormat:@"20:1337:ios:5e18052ab54fbfec"
                                 withVersion:kGoodVersionV2]);

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
  NSString *const kGoodVersionV1 = @"1";
  XCTAssertTrue([FIRApp validateAppIDFingerprint:kGoodAppIDV1 withVersion:kGoodVersionV1]);

  NSString *const kGoodAppIDV2 = @"2:1337:ios:5e18052ab54fbfec";
  NSString *const kGoodVersionV2 = @"2";
  XCTAssertTrue([FIRApp validateAppIDFormat:kGoodAppIDV2 withVersion:kGoodVersionV2]);

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
}

// Uncomment if you need to measure performance of [FIRApp validateAppID:].
// It is commented because measures are heavily dependent on a build agent configuration,
// so it cannot produce reliable resault on CI
//- (void)testAppIDFingerprintPerfomance {
//  [self measureBlock:^{
//    for (NSInteger i = 0; i < 100; ++i) {
//      [self testAppIDPrefix];
//    }
//  }];
//}

#pragma mark - Automatic Data Collection Tests

- (void)testGlobalDataCollectionNoFlags {
  // Test: No flags set.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  OCMStub([self.appClassMock readDataCollectionSwitchFromPlist]).andReturn(nil);
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(nil);

  XCTAssertTrue(app.isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionPlistSetEnabled {
  // Test: Plist set to enabled, no override.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  OCMStub([self.appClassMock readDataCollectionSwitchFromPlist]).andReturn(@YES);
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(nil);

  XCTAssertTrue(app.isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionPlistSetDisabled {
  // Test: Plist set to disabled, no override.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  OCMStub([self.appClassMock readDataCollectionSwitchFromPlist]).andReturn(@NO);
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(nil);

  XCTAssertFalse(app.isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionUserSpecifiedEnabled {
  // Test: User specified as enabled, no plist value.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  OCMStub([self.appClassMock readDataCollectionSwitchFromPlist]).andReturn(nil);
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(@YES);

  XCTAssertTrue(app.isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionUserSpecifiedDisabled {
  // Test: User specified as disabled, no plist value.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  OCMStub([self.appClassMock readDataCollectionSwitchFromPlist]).andReturn(nil);
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(@NO);

  XCTAssertFalse(app.isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionUserOverriddenEnabled {
  // Test: User specified as enabled, with plist set as disabled.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  OCMStub([self.appClassMock readDataCollectionSwitchFromPlist]).andReturn(@NO);
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(@YES);

  XCTAssertTrue(app.isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionUserOverriddenDisabled {
  // Test: User specified as disabled, with plist set as enabled.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  OCMStub([self.appClassMock readDataCollectionSwitchFromPlist]).andReturn(@YES);
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(@NO);

  XCTAssertFalse(app.isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionWriteToDefaults {
  id defaultsMock = OCMPartialMock([NSUserDefaults standardUserDefaults]);
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  [FIRApp configureWithName:name options:options];
  FIRApp *app = [FIRApp appNamed:name];
  app.dataCollectionDefaultEnabled = YES;
  NSString *key =
      [NSString stringWithFormat:kFIRGlobalAppDataCollectionEnabledDefaultsKeyFormat, app.name];
  OCMVerify([defaultsMock setObject:@YES forKey:key]);

  app.dataCollectionDefaultEnabled = NO;
  OCMVerify([defaultsMock setObject:@NO forKey:key]);

  [defaultsMock stopMocking];
}

- (void)testGlobalDataCollectionClearedAfterDelete {
  // Configure and disable data collection for the default FIRApp.
  NSString *name = NSStringFromSelector(_cmd);
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  [FIRApp configureWithName:name options:options];
  FIRApp *app = [FIRApp appNamed:name];
  app.dataCollectionDefaultEnabled = NO;
  XCTAssertFalse(app.isDataCollectionDefaultEnabled);

  // Delete the app, and verify that the switch was reset.
  XCTestExpectation *deleteFinished =
      [self expectationWithDescription:@"The app should successfully delete."];
  [app deleteApp:^(BOOL success) {
    XCTAssertTrue(success);
    [deleteFinished fulfill];
  }];

  // Wait for the delete to complete.
  [self waitForExpectations:@[ deleteFinished ] timeout:1];

  // Set up an app with the same name again, and check the data collection flag.
  [FIRApp configureWithName:name options:options];
  XCTAssertTrue([FIRApp appNamed:name].isDataCollectionDefaultEnabled);
}

- (void)testGlobalDataCollectionNoDiagnosticsSent {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:NSStringFromSelector(_cmd) options:options];
  app.dataCollectionDefaultEnabled = NO;

  // Add an observer for the diagnostics notification. Currently no object is sent, but in the
  // future that could change so leave it as OCMOCK_ANY.
  [self.notificationCenter addMockObserver:self.observerMock
                                      name:kFIRAppDiagnosticsNotification
                                    object:OCMOCK_ANY];

  // Stub out reading from user defaults since stubbing out the BOOL has issues. If the data
  // collection switch is disabled, the `sendLogs` call should return immediately and not fire a
  // notification.
  OCMStub([self.appClassMock readDataCollectionSwitchFromUserDefaultsForApp:OCMOCK_ANY])
      .andReturn(@NO);

  // Ensure configure doesn't fire a notification.
  [FIRApp configure];

  // The observer mock is strict and will raise an exception when an unexpected notification is
  // received.
  OCMVerifyAll(self.observerMock);
}

#pragma mark - Analytics Flag Tests

- (void)testAnalyticsSetByGlobalDataCollectionSwitch {
  // Test that the global data collection switch triggers setting Analytics when no explicit flag is
  // set.
  id optionsMock = OCMClassMock([FIROptions class]);
  OCMStub([optionsMock isAnalyticsCollectionExplicitlySet]).andReturn(NO);

  // We need to use the default app name since Analytics only associates with the default app.
  FIRApp *defaultApp = [[FIRApp alloc] initInstanceWithName:kFIRDefaultAppName options:optionsMock];

  id configurationMock = OCMClassMock([FIRAnalyticsConfiguration class]);
  OCMStub([configurationMock sharedInstance]).andReturn(configurationMock);

  // Ensure Analytics is set after the global flag is set. It needs to
  [defaultApp setDataCollectionDefaultEnabled:YES];
  OCMVerify([configurationMock setAnalyticsCollectionEnabled:YES persistSetting:NO]);

  [defaultApp setDataCollectionDefaultEnabled:NO];
  OCMVerify([configurationMock setAnalyticsCollectionEnabled:NO persistSetting:NO]);
}

- (void)testAnalyticsNotSetByGlobalDataCollectionSwitch {
  // Test that the global data collection switch doesn't override an explicitly set Analytics flag.
  id optionsMock = OCMClassMock([FIROptions class]);
  OCMStub([optionsMock isAnalyticsCollectionExplicitlySet]).andReturn(YES);
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testAnalyticsNotSet" options:optionsMock];

  id configurationMock = OCMClassMock([FIRAnalyticsConfiguration class]);
  OCMStub([configurationMock sharedInstance]).andReturn(configurationMock);

  // Reject any changes to Analytics when the data collection changes.
  OCMReject([configurationMock setAnalyticsCollectionEnabled:YES persistSetting:YES]);
  OCMReject([configurationMock setAnalyticsCollectionEnabled:YES persistSetting:NO]);
  [app setDataCollectionDefaultEnabled:YES];

  OCMReject([configurationMock setAnalyticsCollectionEnabled:NO persistSetting:YES]);
  OCMReject([configurationMock setAnalyticsCollectionEnabled:NO persistSetting:NO]);
  [app setDataCollectionDefaultEnabled:NO];
}

#pragma mark - Internal Methods

- (void)testIsDefaultAppConfigured {
  // Ensure it's false before anything is configured.
  XCTAssertFalse([FIRApp isDefaultAppConfigured]);

  // Configure it and ensure it's configured.
  [FIRApp configure];
  XCTAssertTrue([FIRApp isDefaultAppConfigured]);

  // Reset the apps and ensure it's not configured anymore.
  [FIRApp resetApps];
  XCTAssertFalse([FIRApp isDefaultAppConfigured]);
}

- (void)testRegisterLibrary_InvalidLibraryName {
  NSString *originalFirebaseUserAgent = [FIRApp firebaseUserAgent];
  [FIRApp registerLibrary:@"Oops>" withVersion:@"1.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] isEqualToString:originalFirebaseUserAgent]);
}

- (void)testRegisterLibrary_InvalidLibraryVersion {
  NSString *originalFirebaseUserAgent = [FIRApp firebaseUserAgent];
  [FIRApp registerLibrary:@"ValidName" withVersion:@"1.0.0+"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] isEqualToString:originalFirebaseUserAgent]);
}

- (void)testRegisterLibrary_SingleLibrary {
  [FIRApp registerLibrary:@"ValidName" withVersion:@"1.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"ValidName/1.0.0"]);
}

- (void)testRegisterLibrary_MultipleLibraries {
  [FIRApp registerLibrary:@"ValidName" withVersion:@"1.0.0"];
  [FIRApp registerLibrary:@"ValidName2" withVersion:@"2.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"ValidName/1.0.0 ValidName2/2.0.0"]);
}

- (void)testRegisterLibrary_RegisteringConformingLibrary {
  Class testClass = [FIRTestClass class];
  [FIRApp registerInternalLibrary:testClass withName:@"ValidName" withVersion:@"1.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"ValidName/1.0.0"]);
}

- (void)testRegisterLibrary_RegisteringNonConformingLibrary {
  XCTAssertThrows([FIRApp registerInternalLibrary:[NSString class]
                                         withName:@"InvalidLibrary"
                                      withVersion:@"1.0.0"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"InvalidLibrary`/1.0.0"]);
}

- (void)testFirebaseUserAgent_SwiftFlagWithNoSwift {
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"swift/false"]);
}

- (void)testFirebaseUserAgent_ApplePlatformFlag {
  // When a Catalyst app is run on macOS then both `TARGET_OS_MACCATALYST` and `TARGET_OS_IOS` are
  // `true`.
#if TARGET_OS_MACCATALYST
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#elif TARGET_OS_IOS
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_MACCATALYST

#if TARGET_OS_TV
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_TV

#if TARGET_OS_OSX
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_OSX

#if TARGET_OS_WATCH
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_WATCH
}

- (void)testFirebaseUserAgent_DeploymentType {
#if SWIFT_PACKAGE
  NSString *deploymentType = @"swiftpm";
#elif FIREBASE_BUILD_CARTHAGE
  NSString *deploymentType = @"carthage";
#elif FIREBASE_BUILD_ZIP_FILE
  NSString *deploymentType = @"zip";
#else
  NSString *deploymentType = @"cocoapods";
#endif

  NSString *expectedComponent = [NSString stringWithFormat:@"deploy/%@", deploymentType];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

- (void)testFirebaseUserAgent_DeviceModel {
  NSString *expectedComponent =
      [NSString stringWithFormat:@"device/%@", [GULAppEnvironmentUtil deviceModel]];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

- (void)testFirebaseUserAgent_OSVersion {
  NSString *expectedComponent =
      [NSString stringWithFormat:@"os-version/%@", [GULAppEnvironmentUtil systemVersion]];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

- (void)testFirebaseUserAgent_IsFromAppStore {
  NSString *appStoreValue = [GULAppEnvironmentUtil isFromAppStore] ? @"true" : @"false";
  NSString *expectedComponent = [NSString stringWithFormat:@"appstore/%@", appStoreValue];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

#pragma mark - Core Diagnostics

- (void)testCoreDiagnosticsLoggedWhenAppDidBecomeActive {
  FIRApp *app = [self createConfiguredAppWithName:NSStringFromSelector(_cmd)];
  [self expectCoreDiagnosticsDataLogWithOptions:app.options];

  [self.notificationCenter postNotificationName:[self appDidBecomeActiveNotificationName]
                                         object:nil];

  OCMVerifyAllWithDelay(self.mockCoreDiagnosticsConnector, 0.5);
}

#pragma mark - private

- (void)expectNotificationForObserver:(id)observer
                     notificationName:(NSNotificationName)name
                               object:(nullable id)object
                             userInfo:(nullable NSDictionary *)userInfo {
  [self.notificationCenter addMockObserver:observer name:name object:object];
  [[observer expect] notificationWithName:name object:object userInfo:userInfo];
}

- (NSDictionary<NSString *, NSObject *> *)expectedUserInfoWithAppName:(NSString *)name
                                                         isDefaultApp:(BOOL)isDefaultApp {
  return @{
    kFIRAppNameKey : name,
    kFIRAppIsDefaultAppKey : [NSNumber numberWithBool:isDefaultApp],
    kFIRGoogleAppIDKey : kGoogleAppID
  };
}

- (void)expectCoreDiagnosticsDataLogWithOptions:(nullable FIROptions *)expectedOptions {
  [self.mockCoreDiagnosticsConnector stopMocking];
  self.mockCoreDiagnosticsConnector = nil;
  self.mockCoreDiagnosticsConnector = OCMClassMock([FIRCoreDiagnosticsConnector class]);

  OCMExpect(ClassMethod([self.mockCoreDiagnosticsConnector
      logCoreTelemetryWithOptions:[OCMArg checkWithBlock:^BOOL(FIROptions *options) {
        if (!expectedOptions) {
          return YES;
        }
        return [options.googleAppID isEqualToString:expectedOptions.googleAppID] &&
               [options.GCMSenderID isEqualToString:expectedOptions.GCMSenderID];
      }]]));
}

- (NSNotificationName)appDidBecomeActiveNotificationName {
#if TARGET_OS_IOS || TARGET_OS_TV
  return UIApplicationDidBecomeActiveNotification;
#endif

#if TARGET_OS_OSX
  return NSApplicationDidBecomeActiveNotification;
#endif
}

- (FIRApp *)createConfiguredAppWithName:(NSString *)name {
  FIROptions *options = [self appOptions];
  [FIRApp configureWithName:name options:options];
  return [FIRApp appNamed:name];
}

- (FIROptions *)appOptions {
  return [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID GCMSenderID:kGCMSenderID];
}

- (void)registerLibrariesWithClasses:(NSArray<Class> *)classes {
  for (Class klass in classes) {
    [FIRApp registerInternalLibrary:klass withName:NSStringFromClass(klass) withVersion:@"1.0"];
  }
}

@end
