// Copyright 2026 Google LLC
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

// Checks at run time that FirebaseCore works with the prebuilt FirebaseAnalytics and
// GoogleAppMeasurement binaries. They were compiled against FirebaseCore's internal API and
// can't be rebuilt, so FirebaseCore must keep the contract they rely on:
//
// - FirebaseAnalytics registers itself from +load with
//   +[FIRApp registerInternalLibrary:withName:withVersion:], and provides the FIRAnalyticsInterop
//   component with +[FIRComponent componentWithProtocol:creationBlock:].
// - Configuring the default app calls +[FIRAnalytics startWithConfiguration:options:]. Analytics
//   reads the options and logs through FIRFirebaseVersion() and kFIRLoggerAnalytics.
// - GoogleAppMeasurement observes FIRAnalyticsConfigurationSetEnabledNotification, which
//   FirebaseCore posts when the app's data collection switch changes.
//
// scripts/core_api/check_binary_link.py checks the symbols, selectors and names that the binaries
// use. This test checks that they work. It runs with FirebaseCore linked statically (the
// CoreAnalyticsLink target) and dynamically (scripts/core_api/binary_link). It reads Analytics'
// console messages back with OSLogStore, and doesn't depend on the network.

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV

#import <XCTest/XCTest.h>

#import <OSLog/OSLog.h>
#import <os/log.h>

@import FirebaseAnalytics;

#import "FirebaseCore/Extension/FIRAppInternal.h"
#import "FirebaseCore/Extension/FIRComponentContainer.h"
#import "FirebaseCore/Extension/FIRComponentType.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FirebaseCore.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

NS_ASSUME_NONNULL_BEGIN

/// How long to wait for a message from Analytics. Analytics starts asynchronously.
static const NSTimeInterval kFIRAnalyticsLinkTimeout = 60;

/// The service name that Analytics logs with. It's the value of kFIRLoggerAnalytics, written out
/// because the value is part of the contract.
static NSString *const kFIRAnalyticsLinkService = @"[FirebaseAnalytics]";

/// The user defaults key of the default app's data collection switch.
static NSString *const kFIRAnalyticsLinkDataCollectionKey =
    @"/google/firebase/global_data_collection_enabled:__FIRAPP_DEFAULT";

/// When the default app was configured.
static NSDate *sConfigureDate;

@interface FIRAnalyticsLinkTests : XCTestCase
@end

@implementation FIRAnalyticsLinkTests

+ (void)setUp {
  [super setUp];
  // FirebaseAnalytics is a static framework, so the linker only keeps its object files if
  // something refers to them. Apps refer to them by calling the Analytics API (or link with
  // -ObjC); this does the same.
  (void)[FIRAnalytics class];

  // Start from the default data collection setting, in case an earlier run was interrupted.
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFIRAnalyticsLinkDataCollectionKey];

  // Options built in code, as an app without a GoogleService-Info.plist would do. Analytics starts
  // FirebaseInstallations, which checks the format of the API key.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123abc"
                                                    GCMSenderID:@"123"];
  options.APIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
  options.projectID = @"abc-xyz-123";
  NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
  if (bundleID) {
    options.bundleID = bundleID;
  }
  sConfigureDate = [NSDate date];
  [FIRApp configureWithOptions:options];
}

+ (void)tearDown {
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFIRAnalyticsLinkDataCollectionKey];
  [super tearDown];
}

- (void)setUp {
  [super setUp];
  // Each check waits for the previous one, so don't wait again after a failure.
  self.continueAfterFailure = NO;
}

- (void)testAnalyticsRegistersWithFirebaseCore {
  // +[FIRApp registerInternalLibrary:withName:withVersion:] adds the library to the user agent.
  NSString *userAgent = [FIRApp firebaseUserAgent];
  NSRange range = [userAgent rangeOfString:@"(^| )fire-analytics/[0-9]+\\.[0-9]+\\.[0-9]+( |$)"
                                   options:NSRegularExpressionSearch];
  XCTAssertNotEqual(range.location, NSNotFound,
                    @"FirebaseAnalytics didn't register with FirebaseCore. User agent: %@",
                    userAgent);
}

- (void)testAnalyticsProvidesInteropComponent {
  FIRApp *app = [FIRApp defaultApp];
  XCTAssertNotNil(app);
  id<FIRAnalyticsInterop> analytics = FIR_COMPONENT(FIRAnalyticsInterop, app.container);
  XCTAssertNotNil(analytics,
                  @"FirebaseCore didn't create FirebaseAnalytics' FIRAnalyticsInterop component.");
  XCTAssertTrue([(NSObject *)analytics conformsToProtocol:@protocol(FIRAnalyticsInterop)]);
  // Calls into the component, so it's the real Analytics connector.
  XCTAssertGreaterThan([analytics maxUserProperties:@"frc"], 0);
}

- (void)testConfigureStartsAnalytics {
  // FirebaseCore finds Analytics by these names, without linking to it.
  Class analyticsClass = NSClassFromString(@"FIRAnalytics");
  XCTAssertEqual(analyticsClass, [FIRAnalytics class]);
  XCTAssertTrue(
      [analyticsClass respondsToSelector:NSSelectorFromString(@"startWithConfiguration:options:")]);

  NSString *message = [self waitForAnalyticsMessage:@"[I-ACS023007]" since:sConfigureDate];
  // Analytics logs FirebaseCore's version, from FIRFirebaseVersion().
  NSString *started = [NSString stringWithFormat:@"Analytics v.%@ started", FIRFirebaseVersion()];
  XCTAssertTrue([message containsString:started], @"Expected \"%@\" in: %@", started, message);
}

- (void)testDataCollectionSwitchReachesAnalytics {
  FIRApp *app = [FIRApp defaultApp];
  XCTAssertNotNil(app);
  // Analytics logs whether collection is enabled when it starts.
  [self waitForAnalyticsMessage:@"Analytics collection enabled" since:sConfigureDate];

  NSDate *date = [NSDate date];
  app.dataCollectionDefaultEnabled = NO;
  [self waitForAnalyticsMessage:@"Analytics collection disabled" since:date];

  date = [NSDate date];
  app.dataCollectionDefaultEnabled = YES;
  [self waitForAnalyticsMessage:@"Analytics collection enabled" since:date];
}

#pragma mark - Helpers

/// Waits for a message from FirebaseAnalytics that contains `text` and was logged at or after
/// `date`, and returns it. Fails the test if there's none.
- (nullable NSString *)waitForAnalyticsMessage:(NSString *)text since:(NSDate *)date {
  if (@available(iOS 15, macOS 12, tvOS 15, *)) {
    if (![self canReadLog]) {
      XCTFail(@"This process can't read its own log, so it can't see Analytics' messages. A "
              @"sandbox may be blocking access to the log.");
      return nil;
    }
    NSArray<NSString *> *messages = nil;
    NSString *message = [self waitForMessageContaining:text
                                               service:kFIRAnalyticsLinkService
                                                 since:date
                                               timeout:kFIRAnalyticsLinkTimeout
                                              messages:&messages];
    if (!message) {
      XCTFail(
          @"FirebaseAnalytics didn't log \"%@\" within %.0f seconds. Its messages since %@:\n%@",
          text, kFIRAnalyticsLinkTimeout, date, [messages componentsJoinedByString:@"\n"]);
    }
    return message;
  }
  XCTFail(@"OSLogStore needs iOS 15, macOS 12 or tvOS 15.");
  return nil;
}

/// Whether this process can read back what it logs. Sandboxes can block access to the log.
- (BOOL)canReadLog API_AVAILABLE(ios(15), macos(12), tvos(15)) {
  static BOOL checked = NO;
  static BOOL readable = NO;
  if (!checked) {
    checked = YES;
    NSDate *date = [NSDate date];
    NSString *marker = [NSString stringWithFormat:@"FIRAnalyticsLinkTests %@", [NSUUID UUID]];
    os_log(OS_LOG_DEFAULT, "%{public}@", marker);
    readable = [self waitForMessageContaining:marker
                                      service:marker
                                        since:date
                                      timeout:10
                                     messages:NULL] != nil;
  }
  return readable;
}

/// Polls this process's log for a message that contains `service` and `text`, logged at or after
/// `date`. Returns the message, or nil after `timeout` seconds. `messages` returns the messages
/// that contain `service`.
- (nullable NSString *)waitForMessageContaining:(NSString *)text
                                        service:(NSString *)service
                                          since:(NSDate *)date
                                        timeout:(NSTimeInterval)timeout
                                       messages:(NSArray<NSString *> *_Nullable *_Nullable)messages
    API_AVAILABLE(ios(15), macos(12), tvos(15)) {
  NSError *error;
  OSLogStore *store = [OSLogStore storeWithScope:OSLogStoreCurrentProcessIdentifier error:&error];
  if (!store) {
    XCTFail(@"Can't open the log: %@", error);
    return nil;
  }
  NSPredicate *predicate =
      [NSPredicate predicateWithFormat:@"composedMessage CONTAINS %@", service];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  NSMutableArray<NSString *> *found = [NSMutableArray array];
  do {
    [found removeAllObjects];
    OSLogEnumerator *entries = [store entriesEnumeratorWithOptions:0
                                                          position:[store positionWithDate:date]
                                                         predicate:predicate
                                                             error:&error];
    if (!entries) {
      XCTFail(@"Can't read the log: %@", error);
      return nil;
    }
    for (OSLogEntry *entry in entries) {
      [found addObject:entry.composedMessage];
      if ([entry.composedMessage containsString:text]) {
        return entry.composedMessage;
      }
    }
    // Analytics may need the main queue.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
  } while ([deadline timeIntervalSinceNow] > 0);
  if (messages) {
    *messages = found;
  }
  return nil;
}

@end

NS_ASSUME_NONNULL_END

#endif  // TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
