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

#import "FirebaseCore/Tests/TestHooks/include/FIRCoreTestHooks.h"

// Internal FirebaseCore classes and test seams. Declared here so the hooks don't depend on
// FirebaseCore's private headers, which go away when FirebaseCore is implemented in Swift.
@interface FIRBundleUtil (CoreTestSeams)
+ (void)setRelevantBundlesForTesting:(nullable NSArray<NSBundle *> *)bundles;
+ (void)setIsAppExtensionForTesting:(nullable NSNumber *)isAppExtension;
@end

@interface FIRAnalyticsConfiguration (CoreTestSeams)
+ (void)setUserDefaultsForTesting:(nullable NSUserDefaults *)userDefaults;
@end

@interface FIRApp (CoreTestSeams)
+ (void)setUserDefaultsForTesting:(nullable NSUserDefaults *)userDefaults;
+ (void)setIsAppExtensionForTesting:(nullable NSNumber *)isAppExtension;
+ (void)setInfoDictionaryForTesting:(nullable NSDictionary<NSString *, id> *)infoDictionary;
+ (void)setHeartbeatLoggerFactoryForTesting:
    (nullable FIRHeartbeatLogger * (^)(NSString *appID))factory;
@end

@interface FIRConfiguration (CoreTestSeams)
+ (void)resetLoggerForTestingWithUserDefaults:(nullable NSUserDefaults *)userDefaults
                              launchArguments:(nullable NSArray<NSString *> *)launchArguments;
@end

@implementation FIRCoreTestHooks

+ (void)setRelevantBundles:(nullable NSArray<NSBundle *> *)bundles {
  [FIRBundleUtil setRelevantBundlesForTesting:bundles];
}

+ (void)setUserDefaults:(nullable NSUserDefaults *)userDefaults {
  [FIRApp setUserDefaultsForTesting:userDefaults];
  [FIRAnalyticsConfiguration setUserDefaultsForTesting:userDefaults];
}

+ (void)setIsAppExtension:(nullable NSNumber *)isAppExtension {
  // FIRBundleUtil holds the override for all of FirebaseCore. `+[FIRApp
  // setIsAppExtensionForTesting:]` forwards to it.
  [FIRBundleUtil setIsAppExtensionForTesting:isAppExtension];
}

+ (void)setIsAppExtensionThroughFirebaseApp:(nullable NSNumber *)isAppExtension {
  [FIRApp setIsAppExtensionForTesting:isAppExtension];
}

+ (void)setInfoDictionary:(nullable NSDictionary<NSString *, id> *)infoDictionary {
  [FIRApp setInfoDictionaryForTesting:infoDictionary];
}

/// The heartbeat loggers created through `+setHeartbeatLogHandler:`, so their stored heartbeats can
/// be removed when recording stops.
static NSMutableArray<FIRHeartbeatLogger *> *sRecordingHeartbeatLoggers;

+ (void)setHeartbeatLogHandler:(nullable void (^)(NSString *appID))handler {
  // Remove the heartbeats that the previous loggers stored. Flushing empties a logger's storage.
  NSArray<FIRHeartbeatLogger *> *previousLoggers;
  @synchronized(self) {
    previousLoggers = sRecordingHeartbeatLoggers;
    sRecordingHeartbeatLoggers = [NSMutableArray array];
  }
  for (FIRHeartbeatLogger *logger in previousLoggers) {
    [logger flushHeartbeatsIntoPayload];
  }

  if (!handler) {
    [FIRApp setHeartbeatLoggerFactoryForTesting:nil];
    return;
  }
  [FIRApp setHeartbeatLoggerFactoryForTesting:^FIRHeartbeatLogger *(NSString *appID) {
    // A real logger, so the app logs heartbeats exactly as it does in production.
    // FIRHeartbeatLogger asks for the user agent each time it logs, which is when the handler is
    // called. A separate storage ID keeps test heartbeats apart from a real app's.
    NSString *storageID = [@"FIRCoreTestHooks-" stringByAppendingString:appID];
    FIRHeartbeatLogger *logger = [[FIRHeartbeatLogger alloc] initWithAppID:storageID
                                                         userAgentProvider:^NSString * {
                                                           handler(appID);
                                                           return @"FIRCoreTestHooks";
                                                         }];
    @synchronized(self) {
      [sRecordingHeartbeatLoggers addObject:logger];
    }
    return logger;
  }];
}

+ (void)registerInternalLibraryWithUncheckedClass:(Class)library
                                             name:(NSString *)name
                                          version:(NSString *)version {
  [FIRApp registerInternalLibrary:library withName:name withVersion:version];
}

+ (BOOL)resetLoggerWithUserDefaults:(nullable NSUserDefaults *)userDefaults
                    launchArguments:(nullable NSArray<NSString *> *)launchArguments {
  // The seam only exists in DEBUG builds.
  SEL selector = @selector(resetLoggerForTestingWithUserDefaults:launchArguments:);
  if (![FIRConfiguration respondsToSelector:selector]) {
    return NO;
  }
  [FIRConfiguration resetLoggerForTestingWithUserDefaults:userDefaults
                                          launchArguments:launchArguments];
  return YES;
}

+ (void)configureWithNullableOptions:(nullable FIROptions *)options {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
  [FIRApp configureWithOptions:options];
#pragma clang diagnostic pop
}

+ (void)configureWithNullableName:(nullable NSString *)name options:(nullable FIROptions *)options {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
  [FIRApp configureWithName:name options:options];
#pragma clang diagnostic pop
}

+ (nullable NSException *)exceptionRaisedBy:(NS_NOESCAPE void (^)(void))block {
  @try {
    block();
  } @catch (NSException *exception) {
    return exception;
  }
  return nil;
}

@end
