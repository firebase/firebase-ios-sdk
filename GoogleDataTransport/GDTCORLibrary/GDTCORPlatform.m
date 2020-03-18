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

#import <GoogleDataTransport/GDTCORPlatform.h>

#import <GoogleDataTransport/GDTCORAssert.h>
#import <GoogleDataTransport/GDTCORConsoleLogger.h>
#import <GoogleDataTransport/GDTCORReachability.h>

#import "GDTCORLibrary/Private/GDTCORRegistrar_Private.h"

#ifdef GDTCOR_VERSION
#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x
NSString *const kGDTCORVersion = @STR(GDTCOR_VERSION);
#else
NSString *const kGDTCORVersion = @"Unknown";
#endif  // GDTCOR_VERSION

const GDTCORBackgroundIdentifier GDTCORBackgroundIdentifierInvalid = 0;

NSString *const kGDTCORApplicationDidEnterBackgroundNotification =
    @"GDTCORApplicationDidEnterBackgroundNotification";

NSString *const kGDTCORApplicationWillEnterForegroundNotification =
    @"GDTCORApplicationWillEnterForegroundNotification";

NSString *const kGDTCORApplicationWillTerminateNotification =
    @"GDTCORApplicationWillTerminateNotification";

NSURL *GDTCORRootDirectory(void) {
  static NSURL *GDTPath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *cachePath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    GDTPath =
        [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/google-sdks-events", cachePath]];
    GDTCORLogDebug("GDT's state will be saved to: %@", GDTPath);
  });
  return GDTPath;
}

#if !TARGET_OS_WATCH
BOOL GDTCORReachabilityFlagsContainWWAN(SCNetworkReachabilityFlags flags) {
#if TARGET_OS_IOS
  return (flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN;
#else
  return NO;
#endif  // TARGET_OS_IOS
}
#endif  // !TARGET_OS_WATCH

GDTCORNetworkType GDTCORNetworkTypeMessage() {
#if !TARGET_OS_WATCH
  SCNetworkReachabilityFlags reachabilityFlags = [GDTCORReachability currentFlags];
  if ((reachabilityFlags & kSCNetworkReachabilityFlagsReachable) ==
      kSCNetworkReachabilityFlagsReachable) {
    if (GDTCORReachabilityFlagsContainWWAN(reachabilityFlags)) {
      return GDTCORNetworkTypeMobile;
    } else {
      return GDTCORNetworkTypeWIFI;
    }
  }
#endif
  return GDTCORNetworkTypeUNKNOWN;
}

GDTCORNetworkMobileSubtype GDTCORNetworkMobileSubTypeMessage() {
#if TARGET_OS_IOS
  static NSDictionary<NSString *, NSNumber *> *CTRadioAccessTechnologyToNetworkSubTypeMessage;
  static CTTelephonyNetworkInfo *networkInfo;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    CTRadioAccessTechnologyToNetworkSubTypeMessage = @{
      CTRadioAccessTechnologyGPRS : @(GDTCORNetworkMobileSubtypeGPRS),
      CTRadioAccessTechnologyEdge : @(GDTCORNetworkMobileSubtypeEdge),
      CTRadioAccessTechnologyWCDMA : @(GDTCORNetworkMobileSubtypeWCDMA),
      CTRadioAccessTechnologyHSDPA : @(GDTCORNetworkMobileSubtypeHSDPA),
      CTRadioAccessTechnologyHSUPA : @(GDTCORNetworkMobileSubtypeHSUPA),
      CTRadioAccessTechnologyCDMA1x : @(GDTCORNetworkMobileSubtypeCDMA1x),
      CTRadioAccessTechnologyCDMAEVDORev0 : @(GDTCORNetworkMobileSubtypeCDMAEVDORev0),
      CTRadioAccessTechnologyCDMAEVDORevA : @(GDTCORNetworkMobileSubtypeCDMAEVDORevA),
      CTRadioAccessTechnologyCDMAEVDORevB : @(GDTCORNetworkMobileSubtypeCDMAEVDORevB),
      CTRadioAccessTechnologyeHRPD : @(GDTCORNetworkMobileSubtypeHRPD),
      CTRadioAccessTechnologyLTE : @(GDTCORNetworkMobileSubtypeLTE),
    };
    networkInfo = [[CTTelephonyNetworkInfo alloc] init];
  });
  NSString *networkCurrentRadioAccessTechnology;
#if TARGET_OS_MACCATALYST
  NSDictionary<NSString *, NSString *> *networkCurrentRadioAccessTechnologyDict =
      networkInfo.serviceCurrentRadioAccessTechnology;
  if (networkCurrentRadioAccessTechnologyDict.count) {
    networkCurrentRadioAccessTechnology = networkCurrentRadioAccessTechnologyDict.allValues[0];
  }
#else  // TARGET_OS_MACCATALYST
#if defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000
  if (@available(iOS 12.0, *)) {
    NSDictionary<NSString *, NSString *> *networkCurrentRadioAccessTechnologyDict =
        networkInfo.serviceCurrentRadioAccessTechnology;
    if (networkCurrentRadioAccessTechnologyDict.count) {
      // In iOS 12, multiple radio technologies can be captured. We prefer not particular radio
      // tech to another, so we'll just return the first value in the dictionary.
      networkCurrentRadioAccessTechnology = networkCurrentRadioAccessTechnologyDict.allValues[0];
    }
  } else {
#else   // defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000
  networkCurrentRadioAccessTechnology = networkInfo.currentRadioAccessTechnology;
#endif  // // defined(__IPHONE_12_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000
  }
#endif  // TARGET_OS_MACCATALYST
  if (networkCurrentRadioAccessTechnology) {
    NSNumber *networkMobileSubtype =
        CTRadioAccessTechnologyToNetworkSubTypeMessage[networkCurrentRadioAccessTechnology];
    return networkMobileSubtype.intValue;
  } else {
    return GDTCORNetworkMobileSubtypeUNKNOWN;
  }
#else
  return GDTCORNetworkMobileSubtypeUNKNOWN;
#endif
}

NSData *_Nullable GDTCOREncodeArchive(id<NSSecureCoding> obj,
                                      NSString *archivePath,
                                      NSError *_Nullable *error) {
  NSData *resultData;
#if (defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000) || \
    (defined(__MAC_10_13) && MAC_OS_X_VERSION_MAX_ALLOWED >= 101300) ||      \
    (defined(__TVOS_11_0) && __TV_OS_VERSION_MAX_ALLOWED >= 110000) ||       \
    (defined(__WATCHOS_4_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= 040000) ||  \
    (defined(TARGET_OS_MACCATALYST) && TARGET_OS_MACCATALYST)
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4, *)) {
    resultData = [NSKeyedArchiver archivedDataWithRootObject:obj
                                       requiringSecureCoding:YES
                                                       error:error];
    if (*error) {
      GDTCORLogDebug(@"Encoding an object failed: %@", *error);
      return nil;
    }
    if (archivePath) {
      BOOL result = [resultData writeToFile:archivePath options:NSDataWritingAtomic error:error];
      if (result == NO || *error) {
        GDTCORLogDebug(@"Attempt to write archive failed: URL:%@ error:%@", archivePath, *error);
      } else {
        GDTCORLogDebug(@"Writing archive succeeded: %@", archivePath);
      }
    }
  } else {
#endif
    BOOL result = NO;
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      resultData = [NSKeyedArchiver archivedDataWithRootObject:obj];
#pragma clang diagnostic pop
      if (archivePath) {
        result = [resultData writeToFile:archivePath options:NSDataWritingAtomic error:error];
        if (result == NO || *error) {
          GDTCORLogDebug(@"Attempt to write archive failed: URL:%@ error:%@", archivePath, *error);
        } else {
          GDTCORLogDebug(@"Writing archive succeeded: %@", archivePath);
        }
      }
    } @catch (NSException *exception) {
      NSString *errorString =
          [NSString stringWithFormat:@"An exception was thrown during encoding: %@", exception];
      *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                   code:-1
                               userInfo:@{NSLocalizedFailureReasonErrorKey : errorString}];
    }
    GDTCORLogDebug(@"Attempt to write archive. successful:%@ URL:%@ error:%@",
                   result ? @"YES" : @"NO", archivePath, *error);
  }
  return resultData;
}

id<NSSecureCoding> _Nullable GDTCORDecodeArchive(Class archiveClass,
                                                 NSString *_Nullable archivePath,
                                                 NSData *_Nullable archiveData,
                                                 NSError *_Nullable *error) {
  id<NSSecureCoding> unarchivedObject = nil;
#if (defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000) || \
    (defined(__MAC_10_13) && MAC_OS_X_VERSION_MAX_ALLOWED >= 101300) ||      \
    (defined(__TVOS_11_0) && __TV_OS_VERSION_MAX_ALLOWED >= 110000) ||       \
    (defined(__WATCHOS_4_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= 040000) ||  \
    (defined(TARGET_OS_MACCATALYST) && TARGET_OS_MACCATALYST)
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4, *)) {
    NSData *data = archiveData ? archiveData : [NSData dataWithContentsOfFile:archivePath];
    if (data) {
      unarchivedObject = [NSKeyedUnarchiver unarchivedObjectOfClass:archiveClass
                                                           fromData:data
                                                              error:error];
    }
  } else {
#endif
    @try {
      NSData *archivedData =
          archiveData ? archiveData : [NSData dataWithContentsOfFile:archivePath];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      unarchivedObject = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
#pragma clang diagnostic pop
    } @catch (NSException *exception) {
      NSString *errorString =
          [NSString stringWithFormat:@"An exception was thrown during encoding: %@", exception];
      *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                   code:-1
                               userInfo:@{NSLocalizedFailureReasonErrorKey : errorString}];
    }
  }
  return unarchivedObject;
}

@interface GDTCORApplication ()
/**
 Private flag to match the existing `readonly` public flag. This will be accurate for all platforms,
 since we handle each platform's lifecycle notifications separately.
 */
@property(atomic, readwrite) BOOL isRunningInBackground;

@end

@implementation GDTCORApplication

+ (void)load {
  GDTCORLogDebug(
      "%@", @"GDT is initializing. Please note that if you quit the app via the "
             "debugger and not through a lifecycle event, event data will remain on disk but "
             "storage won't have a reference to them since the singleton wasn't saved to disk.");
#if TARGET_OS_IOS || TARGET_OS_TV
  // If this asserts, please file a bug at https://github.com/firebase/firebase-ios-sdk/issues.
  GDTCORFatalAssert(
      GDTCORBackgroundIdentifierInvalid == UIBackgroundTaskInvalid,
      @"GDTCORBackgroundIdentifierInvalid and UIBackgroundTaskInvalid should be the same.");
#endif
  [self sharedApplication];
}

+ (nullable GDTCORApplication *)sharedApplication {
  static GDTCORApplication *application;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    application = [[GDTCORApplication alloc] init];
  });
  return application;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    // This class will be instantiated in the foreground.
    _isRunningInBackground = NO;

#if TARGET_OS_IOS || TARGET_OS_TV
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

#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (@available(iOS 13, tvOS 13.0, *)) {
      [notificationCenter addObserver:self
                             selector:@selector(iOSApplicationWillEnterForeground:)
                                 name:UISceneWillEnterForegroundNotification
                               object:nil];
      [notificationCenter addObserver:self
                             selector:@selector(iOSApplicationDidEnterBackground:)
                                 name:UISceneWillDeactivateNotification
                               object:nil];
    }
#endif  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000

#elif TARGET_OS_OSX
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(macOSApplicationWillTerminate:)
                               name:NSApplicationWillTerminateNotification
                             object:nil];
#endif  // TARGET_OS_IOS || TARGET_OS_TV
  }
  return self;
}

- (GDTCORBackgroundIdentifier)beginBackgroundTaskWithName:(NSString *)name
                                        expirationHandler:(void (^)(void))handler {
  GDTCORBackgroundIdentifier bgID =
      [[self sharedApplicationForBackgroundTask] beginBackgroundTaskWithName:name
                                                           expirationHandler:handler];
#if !NDEBUG
  if (bgID != GDTCORBackgroundIdentifierInvalid) {
    GDTCORLogDebug("Creating background task with name:%@ bgID:%ld", name, (long)bgID);
  }
#endif  // !NDEBUG
  return bgID;
}

- (void)endBackgroundTask:(GDTCORBackgroundIdentifier)bgID {
  if (bgID != GDTCORBackgroundIdentifierInvalid) {
    GDTCORLogDebug("Ending background task with ID:%ld was successful", (long)bgID);
    [[self sharedApplicationForBackgroundTask] endBackgroundTask:bgID];
    return;
  }
}

#pragma mark - App environment helpers

- (BOOL)isAppExtension {
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
  BOOL appExtension = [[[NSBundle mainBundle] bundlePath] hasSuffix:@".appex"];
  return appExtension;
#elif TARGET_OS_OSX
  return NO;
#endif
}

/** Returns a UIApplication instance if on the appropriate platform.
 *
 * @return The shared UIApplication if on the appropriate platform.
 */
#if TARGET_OS_IOS || TARGET_OS_TV
- (nullable UIApplication *)sharedApplicationForBackgroundTask {
#else
- (nullable id)sharedApplicationForBackgroundTask {
#endif
  if ([self isAppExtension]) {
    return nil;
  }
  id sharedApplication = nil;
  Class uiApplicationClass = NSClassFromString(@"UIApplication");
  if (uiApplicationClass &&
      [uiApplicationClass respondsToSelector:(NSSelectorFromString(@"sharedApplication"))]) {
    sharedApplication = [uiApplicationClass sharedApplication];
  }
  return sharedApplication;
}

#pragma mark - UIApplicationDelegate

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)iOSApplicationDidEnterBackground:(NSNotification *)notif {
  _isRunningInBackground = YES;

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  GDTCORLogDebug("%@", @"GDTCORPlatform is sending a notif that the app is backgrounding.");
  [notifCenter postNotificationName:kGDTCORApplicationDidEnterBackgroundNotification object:nil];
}

- (void)iOSApplicationWillEnterForeground:(NSNotification *)notif {
  _isRunningInBackground = NO;

  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  GDTCORLogDebug("%@", @"GDTCORPlatform is sending a notif that the app is foregrounding.");
  [notifCenter postNotificationName:kGDTCORApplicationWillEnterForegroundNotification object:nil];
}

- (void)iOSApplicationWillTerminate:(NSNotification *)notif {
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  GDTCORLogDebug("%@", @"GDTCORPlatform is sending a notif that the app is terminating.");
  [notifCenter postNotificationName:kGDTCORApplicationWillTerminateNotification object:nil];
}
#endif  // TARGET_OS_IOS || TARGET_OS_TV

#pragma mark - NSApplicationDelegate

#if TARGET_OS_OSX
- (void)macOSApplicationWillTerminate:(NSNotification *)notif {
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  GDTCORLogDebug("%@", @"GDTCORPlatform is sending a notif that the app is terminating.");
  [notifCenter postNotificationName:kGDTCORApplicationWillTerminateNotification object:nil];
}
#endif  // TARGET_OS_OSX

@end
