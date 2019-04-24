// Copyright 2019 Google LLC
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

#import <GoogleNotificationUtilities/GULAppDelegateSwizzler+Notifications.h>
#import <GoogleUtilities/GULAppDelegateSwizzler.h>
#import <GoogleUtilities/GULAppDelegateSwizzler_Private.h>

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#if (defined(__IPHONE_9_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0))
#define SDK_HAS_USERACTIVITY 1
#endif

/** Plist key that allows Firebase developers to disable App Delegate Proxying.  Source of truth is
 *  the GULAppDelegateSwizzler class.
 */
static NSString *const kGULFirebaseAppDelegateProxyEnabledPlistKey =
    @"FirebaseAppDelegateProxyEnabled";

/** Plist key that allows non-Firebase developers to disable App Delegate Proxying.  Source of truth
 *  is the GULAppDelegateSwizzler class.
 */
static NSString *const kGULGoogleAppDelegateProxyEnabledPlistKey =
    @"GoogleUtilitiesAppDelegateProxyEnabled";

#pragma mark - GULTestAppDelegate

/** This class conforms to the UIApplicationDelegate protocol and is there to be able to test the
 *  App Delegate Swizzler's behavior.
 */
@interface GULTestAppDelegate : UIResponder <UIApplicationDelegate> {
 @public  // Because we want to access the ivars from outside the class like obj->ivar for testing.
  /** YES if init was called. Used for memory layout testing after isa swizzling. */
  BOOL _isInitialized;

  /** An arbitrary number. Used for memory layout testing after isa swizzling. */
  int _arbitraryNumber;
}

@property(nonatomic, strong) NSUserActivity *userActivity;

@property(nonatomic, strong) NSData *remoteNotificationsDeviceToken;
@property(nonatomic, strong) NSError *failToRegisterForRemoteNotificationsError;
@property(nonatomic, strong) NSDictionary *remoteNotification;
@property(nonatomic, copy) void (^remoteNotificationCompletionHandler)(UIBackgroundFetchResult);

/**
 * The application is set each time a UIApplicationDelegate method is called
 */
@property(nonatomic, weak) UIApplication *application;

@end

@implementation GULTestAppDelegate

- (instancetype)init {
  self = [super init];
  if (self) {
    _isInitialized = YES;
    _arbitraryNumber = 123456789;
  }
  return self;
}

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  self.application = application;
  self.remoteNotificationsDeviceToken = deviceToken;
}

- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  self.application = application;
  self.failToRegisterForRemoteNotificationsError = error;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  self.application = application;
  self.remoteNotification = userInfo;
}
#pragma clang diagnostic pop

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  self.application = application;
  self.remoteNotification = userInfo;
  self.remoteNotificationCompletionHandler = completionHandler;
}

// These are methods to test whether changing the class still maintains behavior that the app
// delegate proxy shouldn't have modified.

- (NSString *)someArbitraryMethod {
  return @"blabla";
}

+ (int)someNumber {
  return 890;
}

@end

@interface GULEmptyTestAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation GULEmptyTestAppDelegate
@end

#pragma mark - Interceptor class

/** This is a class used to test whether interceptors work with the App Delegate Swizzler. */
@interface GULTestInterceptorAppDelegate : UIResponder <UIApplicationDelegate>

/** URL sent to application:openURL:options:. */
@property(nonatomic, copy) NSURL *URLForIOS9;

/** URL sent to application:openURL:sourceApplication:annotation:. */
@property(nonatomic, copy) NSURL *URLForIOS8;

/** The NSUserActivity sent to application:continueUserActivity:restorationHandler:. */
@property(nonatomic, copy) NSUserActivity *userActivity;

@end

@implementation GULTestInterceptorAppDelegate

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
  _URLForIOS9 = [url copy];
  return YES;
}

#if TARGET_OS_IOS
- (BOOL)application:(UIApplication *)application
              openURL:(nonnull NSURL *)url
    sourceApplication:(nullable NSString *)sourceApplication
           annotation:(nonnull id)annotation {
  _URLForIOS8 = [url copy];
  return YES;
}
#endif  // TARGET_OS_IOS

#if SDK_HAS_USERACTIVITY

- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *__nullable
                                       restorableObjects))restorationHandler {
  _userActivity = userActivity;
  return YES;
}

#endif  // SDK_HAS_USERACTIVITY

@end

@interface GULAppDelegateSwizzlerNotificationsTest : XCTestCase
@property(nonatomic, strong) id mockSharedApplication;
@end

@implementation GULAppDelegateSwizzlerNotificationsTest

- (void)setUp {
  [super setUp];
  self.mockSharedApplication = OCMPartialMock([UIApplication sharedApplication]);
}

- (void)tearDown {
  [GULAppDelegateSwizzler clearInterceptors];
  [GULAppDelegateSwizzler resetProxyOriginalDelegateOnceToken];
  [GULAppDelegateSwizzler resetProxyOriginalDelegateIncludingAPNSMethodsOnceToken];
  self.mockSharedApplication = nil;
  [super tearDown];
}

- (void)testNotAppDelegateIsNotSwizzled {
  NSObject *notAppDelegate = [[NSObject alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(notAppDelegate);
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];
  XCTAssertEqualObjects(NSStringFromClass([notAppDelegate class]), @"NSObject");
}

/** Tests proxying an object that responds to UIApplicationDelegate protocol and makes sure that
 *  it is isa swizzled and that the object after proxying responds to the expected methods
 *  and doesn't have its ivars modified.
 */
- (void)testProxyAppDelegate {
  GULTestAppDelegate *realAppDelegate = [[GULTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(realAppDelegate);
  size_t sizeBefore = class_getInstanceSize([GULTestAppDelegate class]);

  Class realAppDelegateClassBefore = [realAppDelegate class];

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  XCTAssertTrue([realAppDelegate isKindOfClass:[GULTestAppDelegate class]]);

  NSString *newClassName = NSStringFromClass([realAppDelegate class]);
  XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
  // It is no longer GULTestAppDelegate class instance.
  XCTAssertFalse([realAppDelegate isMemberOfClass:[GULTestAppDelegate class]]);

  size_t sizeAfter = class_getInstanceSize([realAppDelegate class]);

  // Class size must stay the same.
  XCTAssertEqual(sizeBefore, sizeAfter);

  // After being proxied, it should be able to respond to the required method selector.
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);
  XCTAssertTrue([realAppDelegate respondsToSelector:@selector(application:
                                                        didReceiveRemoteNotification:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:
                             didReceiveRemoteNotification:fetchCompletionHandler:)]);

  // Make sure that the class has changed.
  XCTAssertNotEqualObjects([realAppDelegate class], realAppDelegateClassBefore);

  // Make sure that the ivars are not changed in memory as the subclass is created. Directly
  // accessing the ivars should not crash.
  XCTAssertEqual(realAppDelegate->_arbitraryNumber, 123456789);
  XCTAssertEqual(realAppDelegate->_isInitialized, 1);
}

- (void)testProxyRemoteNotificationsMethodsEmptyAppDelegate {
  GULEmptyTestAppDelegate *realAppDelegate = [[GULEmptyTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(realAppDelegate);
  size_t sizeBefore = class_getInstanceSize([GULEmptyTestAppDelegate class]);

  Class realAppDelegateClassBefore = [realAppDelegate class];

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  XCTAssertTrue([realAppDelegate isKindOfClass:[GULEmptyTestAppDelegate class]]);

  NSString *newClassName = NSStringFromClass([realAppDelegate class]);
  XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
  // It is no longer GULTestAppDelegate class instance.
  XCTAssertFalse([realAppDelegate isMemberOfClass:[GULEmptyTestAppDelegate class]]);

  size_t sizeAfter = class_getInstanceSize([realAppDelegate class]);

  // Class size must stay the same.
  XCTAssertEqual(sizeBefore, sizeAfter);

  // After being proxied, it should be able to respond to the required method selector.
#if TARGET_OS_IOS
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)]);
#endif  // TARGET_OS_IOS

  XCTAssertTrue([realAppDelegate respondsToSelector:@selector(application:
                                                        continueUserActivity:restorationHandler:)]);

  // The implementation should not be added if there is no original implementation
  XCTAssertFalse([realAppDelegate respondsToSelector:@selector(application:openURL:options:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:
                             handleEventsForBackgroundURLSession:completionHandler:)]);

  // Remote notifications methods should be added only by
  // -proxyOriginalDelegateIncludingAPNSMethods
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);
  XCTAssertTrue([realAppDelegate respondsToSelector:@selector(application:
                                                        didReceiveRemoteNotification:)]);

  // The implementation should not be added if there is no original implementation
  XCTAssertFalse([realAppDelegate
      respondsToSelector:@selector(application:
                             didReceiveRemoteNotification:fetchCompletionHandler:)]);

  // Make sure that the class has changed.
  XCTAssertNotEqualObjects([realAppDelegate class], realAppDelegateClassBefore);
}

- (void)testProxyRemoteNotificationsMethodsEmptyAppDelegateAfterInitialProxy {
  GULEmptyTestAppDelegate *realAppDelegate = [[GULEmptyTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(realAppDelegate);
  size_t sizeBefore = class_getInstanceSize([GULEmptyTestAppDelegate class]);

  Class realAppDelegateClassBefore = [realAppDelegate class];

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  XCTAssertTrue([realAppDelegate isKindOfClass:[GULEmptyTestAppDelegate class]]);

  NSString *newClassName = NSStringFromClass([realAppDelegate class]);
  XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
  // It is no longer GULTestAppDelegate class instance.
  XCTAssertFalse([realAppDelegate isMemberOfClass:[GULEmptyTestAppDelegate class]]);

  size_t sizeAfter = class_getInstanceSize([realAppDelegate class]);

  // Class size must stay the same.
  XCTAssertEqual(sizeBefore, sizeAfter);

  // After being proxied, it should be able to respond to the required method selector.
#if TARGET_OS_IOS
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)]);
#endif  // TARGET_OS_IOS

  XCTAssertTrue([realAppDelegate respondsToSelector:@selector(application:
                                                        continueUserActivity:restorationHandler:)]);

  // The implementation should not be added if there is no original implementation
  XCTAssertFalse([realAppDelegate respondsToSelector:@selector(application:openURL:options:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:
                             handleEventsForBackgroundURLSession:completionHandler:)]);

  // Proxy remote notifications methods
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);
  XCTAssertTrue([realAppDelegate respondsToSelector:@selector(application:
                                                        didReceiveRemoteNotification:)]);

  // The implementation should not be added if there is no original implementation
  XCTAssertFalse([realAppDelegate
      respondsToSelector:@selector(application:
                             didReceiveRemoteNotification:fetchCompletionHandler:)]);

  // Make sure that the class has changed.
  XCTAssertNotEqualObjects([realAppDelegate class], realAppDelegateClassBefore);
}

/** Tests that methods that are not overriden by the App Delegate Proxy still work as expected. */
- (void)testNotOverriddenMethods {
  GULTestAppDelegate *realAppDelegate = [[GULTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(realAppDelegate);

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  // Make sure that original class instance method still works.
  XCTAssertEqualObjects([realAppDelegate someArbitraryMethod], @"blabla");

  // Make sure that the new subclass inherits the original class method.
  XCTAssertEqual([[realAppDelegate class] someNumber], 890);

  // Make sure that the original class still works.
  XCTAssertEqual([GULTestAppDelegate someNumber], 890);
}

#pragma mark - Tests the behaviour with interceptors

- (void)testApplicationDidRegisterForRemoteNotificationsIsInvokedOnInterceptors {
  NSData *deviceToken = [NSData data];
  UIApplication *application = [UIApplication sharedApplication];

  id interceptor = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor application:application
      didRegisterForRemoteNotificationsWithDeviceToken:deviceToken]);

  id interceptor2 = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor2 application:application
      didRegisterForRemoteNotificationsWithDeviceToken:deviceToken]);

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(testAppDelegate);
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application
      didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
  OCMVerifyAll(interceptor);
  OCMVerifyAll(interceptor2);

  XCTAssertEqual(testAppDelegate.application, application);
  XCTAssertEqual(testAppDelegate.remoteNotificationsDeviceToken, deviceToken);
}

- (void)testApplicationDidFailToRegisterForRemoteNotificationsIsInvokedOnInterceptors {
  NSError *error = [NSError errorWithDomain:@"test" code:-1 userInfo:nil];
  UIApplication *application = [UIApplication sharedApplication];

  id interceptor = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor application:application
      didFailToRegisterForRemoteNotificationsWithError:error]);

  id interceptor2 = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor2 application:application
      didFailToRegisterForRemoteNotificationsWithError:error]);

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(testAppDelegate);
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application didFailToRegisterForRemoteNotificationsWithError:error];
  OCMVerifyAll(interceptor);
  OCMVerifyAll(interceptor2);

  XCTAssertEqual(testAppDelegate.application, application);
  XCTAssertEqual(testAppDelegate.failToRegisterForRemoteNotificationsError, error);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testApplicationDidReceiveRemoteNotificationIsInvokedOnInterceptors {
  NSDictionary *notification = @{};
  UIApplication *application = [UIApplication sharedApplication];

  id interceptor = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor application:application didReceiveRemoteNotification:notification]);

  id interceptor2 = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor2 application:application didReceiveRemoteNotification:notification]);

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(testAppDelegate);
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application didReceiveRemoteNotification:notification];
  OCMVerifyAll(interceptor);
  OCMVerifyAll(interceptor2);

  XCTAssertEqual(testAppDelegate.application, application);
  XCTAssertEqual(testAppDelegate.remoteNotification, notification);
}
#pragma clang diagnostic pop

- (void)testApplicationDidReceiveRemoteNotificationWithCompletionIsInvokedOnInterceptors {
  NSDictionary *notification = @{};
  UIApplication *application = [UIApplication sharedApplication];
  void (^completion)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result) {
  };

  id interceptor = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor application:application
        didReceiveRemoteNotification:notification
              fetchCompletionHandler:completion]);

  id interceptor2 = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMExpect([interceptor2 application:application
         didReceiveRemoteNotification:notification
               fetchCompletionHandler:completion]);

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(testAppDelegate);
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application
      didReceiveRemoteNotification:notification
            fetchCompletionHandler:completion];
  OCMVerifyAll(interceptor);
  OCMVerifyAll(interceptor2);

  XCTAssertEqual(testAppDelegate.application, application);
  XCTAssertEqual(testAppDelegate.remoteNotification, notification);
  XCTAssertEqual(testAppDelegate.remoteNotificationCompletionHandler, completion);
}

- (void)testApplicationDidReceiveRemoteNotificationWithCompletionImplementationIsNotAdded {
  // The delegate without application:didReceiveRemoteNotification:fetchCompletionHandler:
  // implementation
  GULTestInterceptorAppDelegate *legacyDelegate = [[GULTestInterceptorAppDelegate alloc] init];
  OCMStub([self.mockSharedApplication delegate]).andReturn(legacyDelegate);

  XCTAssertFalse([legacyDelegate
      respondsToSelector:@selector(application:
                             didReceiveRemoteNotification:fetchCompletionHandler:)]);

  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  XCTAssertFalse([legacyDelegate
      respondsToSelector:@selector(application:
                             didReceiveRemoteNotification:fetchCompletionHandler:)]);
}

#pragma mark - Tests to test that Plist flag is honored

/** Tests that the App Delegate is not proxied when it is disabled. */
- (void)testAppDelegateIsNotProxiedWhenDisabled {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{kGULFirebaseAppDelegateProxyEnabledPlistKey : @(NO)};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock stub] andReturn:mainDictionary] infoDictionary];
  XCTAssertFalse([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);

  id originalAppDelegate = OCMProtocolMock(@protocol(UIApplicationDelegate));
  Class originalAppDelegateClass = [originalAppDelegate class];
  XCTAssertNotNil(originalAppDelegate);
  OCMStub([self.mockSharedApplication delegate]).andReturn(originalAppDelegate);

  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];
  XCTAssertEqualObjects([originalAppDelegate class], originalAppDelegateClass);

  [mainBundleMock stopMocking];
}

/** Tests that the App Delegate is proxied when it is enabled. */
- (void)testAppDelegateIsProxiedWhenEnabled {
  // App Delegate Proxying is enabled by default.
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);

  id originalAppDelegate = [[GULTestAppDelegate alloc] init];
  Class originalAppDelegateClass = [originalAppDelegate class];
  XCTAssertNotNil(originalAppDelegate);
  OCMStub([self.mockSharedApplication delegate]).andReturn(originalAppDelegate);

  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];
  XCTAssertNotEqualObjects([originalAppDelegate class], originalAppDelegateClass);
}

@end
