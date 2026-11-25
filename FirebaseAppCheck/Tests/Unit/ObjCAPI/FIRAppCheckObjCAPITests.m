/*
 * Copyright 2026 Google LLC
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

// This file pins the Objective-C API of App Check, both at compile time and at runtime.
//
// It was written against the Objective-C implementation of the SDK and must keep compiling,
// without changes or new warnings, and passing against any other implementation.

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

@import FirebaseAppCheck;
@import FirebaseCore;

#pragma mark - Compile-time API usage

typedef void (^FIRAppCheckObjCAPITestsTokenHandler)(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error);

@interface FIRAppCheckObjCAPITestsProvider : NSObject <FIRAppCheckProvider>
@end

@implementation FIRAppCheckObjCAPITestsProvider
- (void)getTokenWithCompletion:(FIRAppCheckObjCAPITestsTokenHandler)handler {
  handler([[FIRAppCheckToken alloc] initWithToken:@"token" expirationDate:[NSDate distantFuture]],
          nil);
}
@end

@interface FIRAppCheckObjCAPITestsFactory : NSObject <FIRAppCheckProviderFactory>
@end

@implementation FIRAppCheckObjCAPITestsFactory
- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  return [[FIRAppCheckObjCAPITestsProvider alloc] init];
}
@end

// Subclasses can override the public methods and declare their own instance variables alongside
// the superclass's stored properties.
@interface FIRAppCheckObjCAPITestsAppCheck : FIRAppCheck
@end

@implementation FIRAppCheckObjCAPITestsAppCheck
@end

@interface FIRAppCheckObjCAPITestsTokenSubclass : FIRAppCheckToken
@property(nonatomic, copy, readonly) NSString *prefix;
@property(nonatomic, assign, readonly) NSInteger tag;
- (instancetype)initWithToken:(NSString *)token
               expirationDate:(NSDate *)expirationDate
                       prefix:(NSString *)prefix
                          tag:(NSInteger)tag;
@end

@implementation FIRAppCheckObjCAPITestsTokenSubclass
- (instancetype)initWithToken:(NSString *)token
               expirationDate:(NSDate *)expirationDate
                       prefix:(NSString *)prefix
                          tag:(NSInteger)tag {
  _prefix = [prefix copy];
  self = [super initWithToken:token expirationDate:expirationDate];
  if (self) {
    _tag = tag;
  }
  return self;
}
- (NSString *)token {
  return [NSString stringWithFormat:@"%@:%@", _prefix, [super token]];
}
- (NSDate *)expirationDate {
  return [super expirationDate];
}
@end

@interface FIRAppCheckObjCAPITestsDebugProvider : FIRAppCheckDebugProvider
@property(nonatomic, copy) NSString *customTag;
@property(nonatomic, assign) NSInteger overrideCallCount;
@end

@implementation FIRAppCheckObjCAPITestsDebugProvider
- (nullable instancetype)initWithApp:(FIRApp *)app {
  _customTag = @"before-super";
  self = [super initWithApp:app];
  if (self) {
    _overrideCallCount = 10;
  }
  return self;
}
- (NSString *)localDebugToken {
  self.overrideCallCount += 1;
  return [super localDebugToken];
}
- (NSString *)currentDebugToken {
  self.overrideCallCount += 1;
  return [super currentDebugToken];
}
- (void)getTokenWithCompletion:(FIRAppCheckObjCAPITestsTokenHandler)handler {
  self.overrideCallCount += 1;
  [super getTokenWithCompletion:handler];
}
- (void)getLimitedUseTokenWithCompletion:(FIRAppCheckObjCAPITestsTokenHandler)handler {
  self.overrideCallCount += 1;
  [super getLimitedUseTokenWithCompletion:handler];
}
@end

@interface FIRAppCheckObjCAPITestsDebugProviderFactory : FIRAppCheckDebugProviderFactory
@property(nonatomic, assign) NSInteger createdCount;
@end

@implementation FIRAppCheckObjCAPITestsDebugProviderFactory
- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  self.createdCount += 1;
  return [super createProviderWithApp:app];
}
@end

FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface FIRAppCheckObjCAPITestsDeviceCheckProvider : FIRDeviceCheckProvider
@property(nonatomic, copy) NSString *label;
@end

@implementation FIRAppCheckObjCAPITestsDeviceCheckProvider
- (nullable instancetype)initWithApp:(FIRApp *)app {
  _label = @"device-check-subclass";
  return [super initWithApp:app];
}
- (void)getTokenWithCompletion:(FIRAppCheckObjCAPITestsTokenHandler)handler {
  [super getTokenWithCompletion:handler];
}
- (void)getLimitedUseTokenWithCompletion:(FIRAppCheckObjCAPITestsTokenHandler)handler {
  [super getLimitedUseTokenWithCompletion:handler];
}
@end

FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface FIRAppCheckObjCAPITestsDeviceCheckProviderFactory : FIRDeviceCheckProviderFactory
@property(nonatomic, assign) NSInteger createdCount;
@end

@implementation FIRAppCheckObjCAPITestsDeviceCheckProviderFactory
- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  self.createdCount += 1;
  return [super createProviderWithApp:app];
}
@end

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
@interface FIRAppCheckObjCAPITestsAppAttestProvider : FIRAppAttestProvider
@property(nonatomic, copy) NSString *label;
@end

@implementation FIRAppCheckObjCAPITestsAppAttestProvider
- (nullable instancetype)initWithApp:(FIRApp *)app {
  _label = @"app-attest-subclass";
  return [super initWithApp:app];
}
- (void)getTokenWithCompletion:(FIRAppCheckObjCAPITestsTokenHandler)handler {
  [super getTokenWithCompletion:handler];
}
- (void)getLimitedUseTokenWithCompletion:(FIRAppCheckObjCAPITestsTokenHandler)handler {
  [super getLimitedUseTokenWithCompletion:handler];
}
@end

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
@interface FIRAppCheckObjCAPITestsAppAttestProviderFactory : FIRAppAttestProviderFactory
@property(nonatomic, assign) NSInteger createdCount;
@end

@implementation FIRAppCheckObjCAPITestsAppAttestProviderFactory
- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  self.createdCount += 1;
  return [super createProviderWithApp:app];
}
@end

#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
@interface FIRAppCheckObjCAPITestsRecaptchaProvider : FIRRecaptchaProvider
@property(nonatomic, copy) NSString *label;
@end

@implementation FIRAppCheckObjCAPITestsRecaptchaProvider
- (nullable instancetype)initWithApp:(FIRApp *)app siteKey:(NSString *)siteKey {
  _label = @"recaptcha-subclass";
  return [super initWithApp:app siteKey:siteKey];
}
@end

@interface FIRAppCheckObjCAPITestsRecaptchaProviderFactory : FIRRecaptchaProviderFactory
@property(nonatomic, copy) NSString *note;
@end

@implementation FIRAppCheckObjCAPITestsRecaptchaProviderFactory
- (instancetype)initWithSiteKey:(NSString *)siteKey {
  _note = @"recaptcha-factory-subclass";
  return [super initWithSiteKey:siteKey];
}
- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  return [super createProviderWithApp:app];
}
@end
#endif

/// Never called. Each statement fails to compile, or warns, if the API changes.
__attribute__((unused)) static void FIRAppCheckObjCAPIUsage(FIRApp *app) {
  // FIRAppCheck
  FIRAppCheck *appCheck = [FIRAppCheck appCheck];
  FIRAppCheck *_Nullable appCheckForApp = [FIRAppCheck appCheckWithApp:app];
  (void)appCheckForApp;
  [FIRAppCheck setAppCheckProviderFactory:[[FIRAppCheckObjCAPITestsFactory alloc] init]];
  [FIRAppCheck setAppCheckProviderFactory:nil];
  BOOL isTokenAutoRefreshEnabled = appCheck.isTokenAutoRefreshEnabled;
  appCheck.isTokenAutoRefreshEnabled = !isTokenAutoRefreshEnabled;
  [appCheck setIsTokenAutoRefreshEnabled:YES];
  [appCheck tokenForcingRefresh:NO
                     completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                       NSString *tokenString = token.token;
                       NSDate *expirationDate = token.expirationDate;
                       (void)tokenString;
                       (void)expirationDate;
                       (void)error;
                     }];
  [appCheck
      limitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error){
      }];

  // FIRAppCheckToken
  FIRAppCheckToken *token = [[FIRAppCheckToken alloc] initWithToken:@"token"
                                                     expirationDate:[NSDate date]];
  (void)token;

  // Notifications
  NSNotificationName notificationName = FIRAppCheckAppCheckTokenDidChangeNotification;
  NSString *tokenKey = kFIRAppCheckTokenNotificationKey;
  NSString *appNameKey = kFIRAppCheckAppNameNotificationKey;
  (void)notificationName;
  (void)tokenKey;
  (void)appNameKey;

  // Errors
  NSErrorDomain errorDomain = FIRAppCheckErrorDomain;
  (void)errorDomain;
  FIRAppCheckErrorCode code = FIRAppCheckErrorCodeUnknown;
  switch (code) {
    case FIRAppCheckErrorCodeUnknown:
    case FIRAppCheckErrorCodeServerUnreachable:
    case FIRAppCheckErrorCodeInvalidConfiguration:
    case FIRAppCheckErrorCodeKeychain:
    case FIRAppCheckErrorCodeUnsupported:
      break;
  }

  // Debug provider
  FIRAppCheckDebugProvider *_Nullable debugProvider =
      [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  NSString *localDebugToken = [debugProvider localDebugToken];
  NSString *currentDebugToken = [debugProvider currentDebugToken];
  (void)localDebugToken;
  (void)currentDebugToken;
  [debugProvider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error){
      }];
  [debugProvider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error){
  }];
  id<FIRAppCheckProviderFactory> debugFactory = [[FIRAppCheckDebugProviderFactory alloc] init];
  id<FIRAppCheckProvider> _Nullable createdProvider = [debugFactory createProviderWithApp:app];
  (void)createdProvider;

  // DeviceCheck provider
  if (@available(watchOS 9.0, *)) {
    FIRDeviceCheckProvider *_Nullable deviceCheckProvider =
        [[FIRDeviceCheckProvider alloc] initWithApp:app];
    [deviceCheckProvider
        getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error){
        }];
    [deviceCheckProvider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                            NSError *_Nullable error){
    }];
    FIRDeviceCheckProviderFactory *deviceCheckFactory =
        [[FIRDeviceCheckProviderFactory alloc] init];
    (void)[deviceCheckFactory createProviderWithApp:app];
  }

  // App Attest provider
  if (@available(macOS 11.3, watchOS 9.0, *)) {
    FIRAppAttestProvider *_Nullable appAttestProvider =
        [[FIRAppAttestProvider alloc] initWithApp:app];
    [appAttestProvider
        getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error){
        }];
    [appAttestProvider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                          NSError *_Nullable error){
    }];
    FIRAppAttestProviderFactory *appAttestFactory = [[FIRAppAttestProviderFactory alloc] init];
    (void)[appAttestFactory createProviderWithApp:app];
  }

  // reCAPTCHA Enterprise provider
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  FIRRecaptchaProvider *_Nullable recaptchaProvider =
      [[FIRRecaptchaProvider alloc] initWithApp:app siteKey:@"site_key"];
  [recaptchaProvider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error){
      }];
  [recaptchaProvider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                        NSError *_Nullable error){
  }];
  FIRRecaptchaProviderFactory *recaptchaFactory =
      [[FIRRecaptchaProviderFactory alloc] initWithSiteKey:@"site_key"];
  (void)[recaptchaFactory createProviderWithApp:app];
#endif

  // Availability macros
#if FIR_DEVICE_CHECK_SUPPORTED_TARGETS && FIR_APP_ATTEST_SUPPORTED_TARGETS
  (void)0;
#endif
}

FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface FIRAppCheckObjCAPITestsDeviceCheckAvailability : NSObject
@end
@implementation FIRAppCheckObjCAPITestsDeviceCheckAvailability
@end

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
@interface FIRAppCheckObjCAPITestsAppAttestAvailability : NSObject
@end
@implementation FIRAppCheckObjCAPITestsAppAttestAvailability
@end

#pragma mark - Runtime API checks

@interface FIRAppCheckObjCAPITests : XCTestCase
@end

@implementation FIRAppCheckObjCAPITests

/// Returns the public classes of App Check that exist on the current platform.
- (NSArray<NSString *> *)publicClassNames {
  NSMutableArray<NSString *> *names = [@[
    @"FIRAppCheck", @"FIRAppCheckToken", @"FIRAppCheckDebugProvider",
    @"FIRAppCheckDebugProviderFactory", @"FIRDeviceCheckProvider", @"FIRDeviceCheckProviderFactory",
    @"FIRAppAttestProvider", @"FIRAppAttestProviderFactory"
  ] mutableCopy];
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  [names addObjectsFromArray:@[ @"FIRRecaptchaProvider", @"FIRRecaptchaProviderFactory" ]];
#endif
  return names;
}

- (void)testPublicClassesExistWithObjectiveCNames {
  for (NSString *name in [self publicClassNames]) {
    Class klass = NSClassFromString(name);
    XCTAssertNotNil(klass, @"%@", name);
    XCTAssertEqual(class_getSuperclass(klass), [NSObject class], @"%@", name);
  }
}

- (void)testProtocolsExistWithObjectiveCNames {
  XCTAssertNotNil(NSProtocolFromString(@"FIRAppCheckProvider"));
  XCTAssertNotNil(NSProtocolFromString(@"FIRAppCheckProviderFactory"));
}

- (void)testProtocolConformances {
  NSDictionary<NSString *, NSString *> *conformances = @{
    @"FIRAppCheckDebugProvider" : @"FIRAppCheckProvider",
    @"FIRAppCheckDebugProviderFactory" : @"FIRAppCheckProviderFactory",
    @"FIRDeviceCheckProvider" : @"FIRAppCheckProvider",
    @"FIRDeviceCheckProviderFactory" : @"FIRAppCheckProviderFactory",
    @"FIRAppAttestProvider" : @"FIRAppCheckProvider",
    @"FIRAppAttestProviderFactory" : @"FIRAppCheckProviderFactory",
    @"FIRAppCheck" : @"FIRAppCheckInterop",
  };
  for (NSString *className in conformances) {
    Protocol *protocol = NSProtocolFromString(conformances[className]);
    XCTAssertNotNil(protocol, @"%@", conformances[className]);
    XCTAssertTrue([NSClassFromString(className) conformsToProtocol:protocol], @"%@ %@", className,
                  conformances[className]);
  }
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  XCTAssertTrue([NSClassFromString(@"FIRRecaptchaProvider")
      conformsToProtocol:@protocol(FIRAppCheckProvider)]);
  XCTAssertTrue([NSClassFromString(@"FIRRecaptchaProviderFactory")
      conformsToProtocol:@protocol(FIRAppCheckProviderFactory)]);
#endif
}

/// Selectors and Objective-C type encodings of the public methods. Type encodings are the same
/// on all 64-bit Apple platforms, except for `BOOL`: it's `bool` (`B`) on arm64 and
/// `signed char` (`c`) on x86_64, for example in macOS tests that run under Rosetta.
- (NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)instanceMethods {
  NSString *const b = @(@encode(BOOL));
  NSString *const kTokenMethod = @"v24@0:8@?16";
  NSString *const kFactoryMethod = @"@24@0:8@16";
  NSString *const kInitWithApp = @"@24@0:8@16";
  NSMutableDictionary *methods = [@{
    @"FIRAppCheck" : @{
      @"tokenForcingRefresh:completion:" : [NSString stringWithFormat:@"v28@0:8%@16@?20", b],
      @"limitedUseTokenWithCompletion:" : kTokenMethod,
      @"isTokenAutoRefreshEnabled" : [NSString stringWithFormat:@"%@16@0:8", b],
      @"setIsTokenAutoRefreshEnabled:" : [NSString stringWithFormat:@"v20@0:8%@16", b],
    },
    @"FIRAppCheckToken" : @{
      @"initWithToken:expirationDate:" : @"@32@0:8@16@24",
      @"token" : @"@16@0:8",
      @"expirationDate" : @"@16@0:8",
    },
    @"FIRAppCheckDebugProvider" : @{
      @"initWithApp:" : kInitWithApp,
      @"localDebugToken" : @"@16@0:8",
      @"currentDebugToken" : @"@16@0:8",
      @"getTokenWithCompletion:" : kTokenMethod,
      @"getLimitedUseTokenWithCompletion:" : kTokenMethod,
    },
    @"FIRAppCheckDebugProviderFactory" : @{@"createProviderWithApp:" : kFactoryMethod},
    @"FIRDeviceCheckProvider" : @{
      @"initWithApp:" : kInitWithApp,
      @"getTokenWithCompletion:" : kTokenMethod,
      @"getLimitedUseTokenWithCompletion:" : kTokenMethod,
    },
    @"FIRDeviceCheckProviderFactory" : @{@"createProviderWithApp:" : kFactoryMethod},
    @"FIRAppAttestProvider" : @{
      @"initWithApp:" : kInitWithApp,
      @"getTokenWithCompletion:" : kTokenMethod,
      @"getLimitedUseTokenWithCompletion:" : kTokenMethod,
    },
    @"FIRAppAttestProviderFactory" : @{@"createProviderWithApp:" : kFactoryMethod},
  } mutableCopy];
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  methods[@"FIRRecaptchaProvider"] = @{
    @"initWithApp:siteKey:" : @"@32@0:8@16@24",
    @"getTokenWithCompletion:" : kTokenMethod,
    @"getLimitedUseTokenWithCompletion:" : kTokenMethod,
  };
  methods[@"FIRRecaptchaProviderFactory"] = @{
    @"initWithSiteKey:" : @"@24@0:8@16",
    @"createProviderWithApp:" : kFactoryMethod,
  };
#endif
  return methods;
}

- (void)testInstanceMethodsAndTypeEncodings {
  NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *methods =
      [self instanceMethods];
  for (NSString *className in methods) {
    Class klass = NSClassFromString(className);
    for (NSString *selectorName in methods[className]) {
      SEL selector = NSSelectorFromString(selectorName);
      Method method = class_getInstanceMethod(klass, selector);
      XCTAssertTrue(method != NULL, @"-[%@ %@]", className, selectorName);
#if __LP64__
      if (method) {
        XCTAssertEqualObjects(@(method_getTypeEncoding(method)), methods[className][selectorName],
                              @"-[%@ %@]", className, selectorName);
      }
#endif
    }
  }
}

- (void)testClassMethodsAndTypeEncodings {
  NSDictionary<NSString *, NSString *> *methods = @{
    @"appCheck" : @"@16@0:8",
    @"appCheckWithApp:" : @"@24@0:8@16",
    @"setAppCheckProviderFactory:" : @"v24@0:8@16",
  };
  for (NSString *selectorName in methods) {
    Method method =
        class_getClassMethod(NSClassFromString(@"FIRAppCheck"), NSSelectorFromString(selectorName));
    XCTAssertTrue(method != NULL, @"+[FIRAppCheck %@]", selectorName);
#if __LP64__
    if (method) {
      XCTAssertEqualObjects(@(method_getTypeEncoding(method)), methods[selectorName],
                            @"+[FIRAppCheck %@]", selectorName);
    }
#endif
  }
}

- (void)testDeclaredPropertiesAndInteropSelectors {
  XCTAssertTrue(class_getProperty([FIRAppCheck class], "isTokenAutoRefreshEnabled") != NULL);
  XCTAssertTrue(class_getProperty([FIRAppCheckToken class], "token") != NULL);
  XCTAssertTrue(class_getProperty([FIRAppCheckToken class], "expirationDate") != NULL);

  NSArray<NSString *> *interopSelectors = @[
    @"getTokenForcingRefresh:completion:",
    @"getLimitedUseTokenWithCompletion:",
    @"tokenDidChangeNotificationName",
    @"notificationTokenKey",
    @"notificationAppNameKey",
  ];
  for (NSString *selectorName in interopSelectors) {
    Method method =
        class_getInstanceMethod([FIRAppCheck class], NSSelectorFromString(selectorName));
    XCTAssertTrue(method != NULL, @"-[FIRAppCheck %@]", selectorName);
  }
}

- (void)testComponentClassExists {
  // FirebaseCore looks up the App Check component by this name, for example to disable App Check
  // for apps created by the ARCore SDK.
  Class component = NSClassFromString(@"FIRAppCheckComponent");
  XCTAssertNotNil(component);
  XCTAssertTrue([component conformsToProtocol:NSProtocolFromString(@"FIRLibrary")]);
  XCTAssertTrue([component respondsToSelector:NSSelectorFromString(@"componentsToRegister")]);
}

- (void)registerDefaultAppCleanup {
  __weak typeof(self) weakSelf = self;
  [self addTeardownBlock:^{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:@"/google/firebase/global_data_collection_enabled:__FIRAPP_DEFAULT"];
    FIRApp *existing = [FIRApp defaultApp];
    if (!existing || !weakSelf) {
      return;
    }
    XCTestExpectation *deleted =
        [weakSelf expectationWithDescription:@"default app deleted in teardown"];
    [existing deleteApp:^(BOOL success) {
      [deleted fulfill];
    }];
    [weakSelf waitForExpectations:@[ deleted ] timeout:5];
  }];
}

- (void)testDefaultAppCheckIsNilWithoutProviderFactory {
  // `+appCheck` is declared nonnull, but it has always returned nil when App Check isn't
  // available for the default app, for example when the provider factory is nil. Callers rely on
  // messages to it doing nothing, so the behavior must not change.
  if ([FIRApp defaultApp] != nil) {
    XCTSkip(@"A default app is configured.");
  }
  [FIRAppCheck setAppCheckProviderFactory:nil];
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  [FIRApp configureWithOptions:options];
  [self registerDefaultAppCleanup];
  FIRApp *defaultApp = [FIRApp defaultApp];
  XCTAssertNotNil(defaultApp);

  FIRAppCheck *appCheck = [FIRAppCheck appCheck];
  XCTAssertNil(appCheck);
  XCTAssertNil([FIRAppCheck appCheckWithApp:defaultApp]);
  XCTAssertFalse(appCheck.isTokenAutoRefreshEnabled);
}

- (void)testSubclassesDontReturnTheAppCheckInstance {
  // Changed in the Swift implementation: the Objective-C implementation returned the registered
  // `FIRAppCheck` instance, typed as the subclass, from `+appCheck` and `+appCheckWithApp:` sent
  // to a subclass. The Swift implementation returns the instance only if it is an instance of the
  // receiver, so subclasses get nil.
  if ([FIRApp defaultApp] != nil) {
    XCTSkip(@"A default app is configured.");
  }
  [FIRAppCheck setAppCheckProviderFactory:[[FIRAppCheckObjCAPITestsFactory alloc] init]];
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  [FIRApp configureWithOptions:options];
  [self registerDefaultAppCleanup];
  FIRApp *defaultApp = [FIRApp defaultApp];
  XCTAssertNotNil(defaultApp);
  defaultApp.dataCollectionDefaultEnabled = NO;

  FIRAppCheck *appCheck = [FIRAppCheck appCheckWithApp:defaultApp];
  XCTAssertNotNil(appCheck);
  XCTAssertEqual([FIRAppCheck appCheck], appCheck);
  XCTAssertNil([FIRAppCheckObjCAPITestsAppCheck appCheckWithApp:defaultApp]);
  XCTAssertNil([FIRAppCheckObjCAPITestsAppCheck appCheck]);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"default app token"];
  [[FIRAppCheck appCheck]
      limitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertEqualObjects(token.token, @"token");
        XCTAssertNil(error);
        [tokenExpectation fulfill];
      }];
  [self waitForExpectations:@[ tokenExpectation ] timeout:5];
}

- (void)testObjectiveCSubclassesAndIvarLayout {
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:42];
  FIRAppCheckObjCAPITestsTokenSubclass *tokenSubclass =
      [[FIRAppCheckObjCAPITestsTokenSubclass alloc] initWithToken:@"abc"
                                                   expirationDate:date
                                                           prefix:@"sub"
                                                              tag:77];
  XCTAssertEqualObjects(tokenSubclass.prefix, @"sub");
  XCTAssertEqual(tokenSubclass.tag, 77);
  XCTAssertEqualObjects(tokenSubclass.token, @"sub:abc");
  XCTAssertEqualObjects(tokenSubclass.expirationDate, date);

  [FIRAppCheck setAppCheckProviderFactory:[[FIRAppCheckObjCAPITestsFactory alloc] init]];
  NSString *appName = @"FIRAppCheckObjCAPITests_Subclasses";
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  [FIRApp configureWithName:appName options:options];
  __weak typeof(self) weakSelf = self;
  [self addTeardownBlock:^{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:[@"/google/firebase/global_data_collection_enabled:"
                               stringByAppendingString:appName]];
    FIRApp *existing = [FIRApp appNamed:appName];
    if (!existing || !weakSelf) {
      return;
    }
    XCTestExpectation *deleted = [weakSelf expectationWithDescription:@"subclass app deleted"];
    [existing deleteApp:^(BOOL success) {
      [deleted fulfill];
    }];
    [weakSelf waitForExpectations:@[ deleted ] timeout:5];
  }];
  FIRApp *app = [FIRApp appNamed:appName];
  XCTAssertNotNil(app);
  app.dataCollectionDefaultEnabled = NO;

  FIRAppCheckObjCAPITestsDebugProvider *debugProvider =
      [[FIRAppCheckObjCAPITestsDebugProvider alloc] initWithApp:app];
  XCTAssertNotNil(debugProvider);
  XCTAssertEqualObjects(debugProvider.customTag, @"before-super");
  // `super initWithApp:` logs the local debug token on initialization, which dynamically dispatches
  // `-localDebugToken` before returning if source is `.local`, and then sets `overrideCallCount =
  // 10`.
  XCTAssertEqual(debugProvider.overrideCallCount, 10);
  XCTAssertGreaterThan(debugProvider.localDebugToken.length, 0U);
  XCTAssertGreaterThan(debugProvider.currentDebugToken.length, 0U);
  XCTAssertEqual(debugProvider.overrideCallCount, 12);
  debugProvider.customTag = @"mutated-after-init";
  XCTAssertEqualObjects(debugProvider.customTag, @"mutated-after-init");

  FIRAppCheckObjCAPITestsDebugProviderFactory *debugFactory =
      [[FIRAppCheckObjCAPITestsDebugProviderFactory alloc] init];
  XCTAssertTrue(
      [[debugFactory createProviderWithApp:app] isKindOfClass:[FIRAppCheckDebugProvider class]]);
  XCTAssertEqual(debugFactory.createdCount, 1);

  if (@available(watchOS 9.0, *)) {
    FIRAppCheckObjCAPITestsDeviceCheckProvider *deviceCheckProvider =
        [[FIRAppCheckObjCAPITestsDeviceCheckProvider alloc] initWithApp:app];
    XCTAssertNotNil(deviceCheckProvider);
    XCTAssertEqualObjects(deviceCheckProvider.label, @"device-check-subclass");

    FIRAppCheckObjCAPITestsDeviceCheckProviderFactory *deviceCheckFactory =
        [[FIRAppCheckObjCAPITestsDeviceCheckProviderFactory alloc] init];
    XCTAssertTrue([[deviceCheckFactory createProviderWithApp:app]
        isKindOfClass:[FIRDeviceCheckProvider class]]);
    XCTAssertEqual(deviceCheckFactory.createdCount, 1);
  }

  if (@available(macOS 11.3, watchOS 9.0, *)) {
    FIRAppCheckObjCAPITestsAppAttestProvider *appAttestProvider =
        [[FIRAppCheckObjCAPITestsAppAttestProvider alloc] initWithApp:app];
    XCTAssertNotNil(appAttestProvider);
    XCTAssertEqualObjects(appAttestProvider.label, @"app-attest-subclass");

    FIRAppCheckObjCAPITestsAppAttestProviderFactory *appAttestFactory =
        [[FIRAppCheckObjCAPITestsAppAttestProviderFactory alloc] init];
    XCTAssertTrue(
        [[appAttestFactory createProviderWithApp:app] isKindOfClass:[FIRAppAttestProvider class]]);
    XCTAssertEqual(appAttestFactory.createdCount, 1);
  }

#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  FIRAppCheckObjCAPITestsRecaptchaProviderFactory *recaptchaFactory =
      [[FIRAppCheckObjCAPITestsRecaptchaProviderFactory alloc] initWithSiteKey:@"site_key"];
  XCTAssertNotNil(recaptchaFactory);
  XCTAssertEqualObjects(recaptchaFactory.note, @"recaptcha-factory-subclass");

  NSString *incompleteAppName = @"FIRAppCheckObjCAPITests_IncompleteRecaptcha";
  FIROptions *incompleteOptions =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  incompleteOptions.projectID = @"project_id";
  [FIRApp configureWithName:incompleteAppName options:incompleteOptions];
  [self addTeardownBlock:^{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:[@"/google/firebase/global_data_collection_enabled:"
                               stringByAppendingString:incompleteAppName]];
    FIRApp *existing = [FIRApp appNamed:incompleteAppName];
    if (!existing || !weakSelf) {
      return;
    }
    XCTestExpectation *deleted =
        [weakSelf expectationWithDescription:@"incomplete recaptcha app deleted"];
    [existing deleteApp:^(BOOL success) {
      [deleted fulfill];
    }];
    [weakSelf waitForExpectations:@[ deleted ] timeout:5];
  }];
  FIRApp *incompleteApp = [FIRApp appNamed:incompleteAppName];
  incompleteApp.dataCollectionDefaultEnabled = NO;
  XCTAssertNil([[FIRAppCheckObjCAPITestsRecaptchaProvider alloc] initWithApp:incompleteApp
                                                                     siteKey:@"site_key"]);
#endif
}

- (void)testTokenInitializer {
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:100];
  FIRAppCheckToken *token = [[FIRAppCheckToken alloc] initWithToken:@"token" expirationDate:date];
  XCTAssertEqualObjects(token.token, @"token");
  XCTAssertEqualObjects(token.expirationDate, date);
}

- (void)testConstants {
  XCTAssertEqualObjects(FIRAppCheckErrorDomain, @"com.firebase.appCheck");
  XCTAssertEqualObjects(FIRAppCheckAppCheckTokenDidChangeNotification,
                        @"FIRAppCheckAppCheckTokenDidChangeNotification");
  XCTAssertEqualObjects(kFIRAppCheckTokenNotificationKey, @"FIRAppCheckTokenNotificationKey");
  XCTAssertEqualObjects(kFIRAppCheckAppNameNotificationKey, @"FIRAppCheckAppNameNotificationKey");
  XCTAssertEqual(FIRAppCheckErrorCodeUnknown, 0);
  XCTAssertEqual(FIRAppCheckErrorCodeServerUnreachable, 1);
  XCTAssertEqual(FIRAppCheckErrorCodeInvalidConfiguration, 2);
  XCTAssertEqual(FIRAppCheckErrorCodeKeychain, 3);
  XCTAssertEqual(FIRAppCheckErrorCodeUnsupported, 4);
}

@end
