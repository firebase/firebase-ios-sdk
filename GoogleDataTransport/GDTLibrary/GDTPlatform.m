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

#import <GoogleDataTransport/GDTPlatform.h>

const GDTBackgroundIdentifier GDTBackgroundIdentifierInvalid = 0;

NSString *const kGDTApplicationDidEnterBackgroundNotification =
    @"GDTApplicationDidEnterBackgroundNotification";

NSString *const kGDTApplicationWillEnterForegroundNotification =
    @"GDTApplicationWillEnterForegroundNotification";

NSString *const kGDTApplicationWillTerminateNotification =
    @"GDTApplicationWillTerminateNotification";

BOOL GDTReachabilityFlagsContainWWAN(SCNetworkReachabilityFlags flags) {
#if TARGET_OS_IOS
  return (flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN;
#else
  return NO;
#endif  // TARGET_OS_IOS
}

@implementation GDTApplication

+ (void)load {
#if TARGET_OS_IOS || TARGET_OS_TVOS
  NSAssert(GDTBackgroundIdentifierInvalid == UIBackgroundTaskInvalid,
           @"GDTBackgroundIdentifierInvalid and UIBackgroundTaskInvalid should be the same.");
#endif
  [self sharedApplication];
}

+ (nullable GDTApplication *)sharedApplication {
  static GDTApplication *application;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    application = [[GDTApplication alloc] init];
  });
  return application;
}

- (instancetype)init {
  self = [super init];
  if (self) {
#if TARGET_OS_IOS || TARGET_OS_TVOS
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(iOSApplicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(iOSApplicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];

    NSString *name = UIApplicationWillTerminateNotification;
    [notificationCenter addObserver:self
                           selector:@selector(iOSApplicationWillTerminate:)
                               name:name
                             object:nil];
#elif TARGET_OS_OSX
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(macOSApplicationWillTerminate:)
                               name:NSApplicationWillTerminateNotification
                             object:nil];
#endif  // TARGET_OS_IOS || TARGET_OS_TVOS
  }
  return self;
}

- (GDTBackgroundIdentifier)beginBackgroundTaskWithExpirationHandler:(void (^)(void))handler {
#if TARGET_OS_IOS || TARGET_OS_TVOS
  return [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:handler];
#else
  return GDTBackgroundIdentifierInvalid;
#endif  // TARGET_OS_IOS || TARGET_OS_TVOS
}

- (void)endBackgroundTask:(GDTBackgroundIdentifier)bgID {
#if TARGET_OS_IOS || TARGET_OS_TVOS
  [[UIApplication sharedApplication] endBackgroundTask:bgID];
#endif  // TARGET_OS_IOS || TARGET_OS_TVOS
}

#pragma mark - UIApplicationDelegate

#if TARGET_OS_IOS || TARGET_OS_TVOS
- (void)iOSApplicationDidEnterBackground:(NSNotification *)notif {
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTApplicationDidEnterBackgroundNotification object:nil];
}

- (void)iOSApplicationWillEnterForeground:(NSNotification *)notif {
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTApplicationWillEnterForegroundNotification object:nil];
}

- (void)iOSApplicationWillTerminate:(NSNotification *)notif {
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTApplicationWillTerminateNotification object:nil];
}
#endif  // TARGET_OS_IOS || TARGET_OS_TVOS

#pragma mark - NSApplicationDelegate

#if TARGET_OS_OSX
- (void)macOSApplicationWillTerminate:(NSNotification *)notif {
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter postNotificationName:kGDTApplicationWillTerminateNotification object:nil];
}
#endif  // TARGET_OS_OSX

@end
