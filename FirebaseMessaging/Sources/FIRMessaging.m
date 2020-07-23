/*
 * Copyright 2017 Google
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

#if !__has_feature(objc_arc)
#error FIRMessagingLib should be compiled with ARC.
#endif

#import <FirebaseInstallations/FIRInstallations.h>
#import <FirebaseMessaging/FIRMessaging.h>
#import <FirebaseMessaging/FIRMessagingExtensionHelper.h>
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "GoogleUtilities/AppDelegateSwizzler/Private/GULAppDelegateSwizzler.h"
#import "GoogleUtilities/Environment/Private/GULAppEnvironmentUtil.h"
#import "GoogleUtilities/Reachability/Private/GULReachabilityChecker.h"
#import "GoogleUtilities/UserDefaults/Private/GULUserDefaults.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#import "FirebaseMessaging/Sources/FIRMessagingAnalytics.h"
#import "FirebaseMessaging/Sources/FIRMessagingClient.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingContextManagerService.h"
#import "FirebaseMessaging/Sources/FIRMessagingDataMessageManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingPubSub.h"
#import "FirebaseMessaging/Sources/FIRMessagingReceiver.h"
#import "FirebaseMessaging/Sources/FIRMessagingRemoteNotificationsProxy.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingSyncMessageManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/FIRMessagingVersionUtilities.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"

static NSString *const kFIRMessagingMessageViaAPNSRootKey = @"aps";
static NSString *const kFIRMessagingReachabilityHostname = @"www.google.com";
static NSString *const kFIRMessagingFCMTokenFetchAPNSOption = @"apns_token";

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
const NSNotificationName FIRMessagingSendSuccessNotification =
    @"com.firebase.messaging.notif.send-success";
const NSNotificationName FIRMessagingSendErrorNotification =
    @"com.firebase.messaging.notif.send-error";
const NSNotificationName FIRMessagingMessagesDeletedNotification =
    @"com.firebase.messaging.notif.messages-deleted";
const NSNotificationName FIRMessagingConnectionStateChangedNotification =
    @"com.firebase.messaging.notif.connection-state-changed";
const NSNotificationName FIRMessagingRegistrationTokenRefreshedNotification =
    @"com.firebase.messaging.notif.fcm-token-refreshed";
#else
NSString *const FIRMessagingSendSuccessNotification = @"com.firebase.messaging.notif.send-success";
NSString *const FIRMessagingSendErrorNotification = @"com.firebase.messaging.notif.send-error";
NSString *const FIRMessagingMessagesDeletedNotification =
    @"com.firebase.messaging.notif.messages-deleted";
NSString *const FIRMessagingConnectionStateChangedNotification =
    @"com.firebase.messaging.notif.connection-state-changed";
NSString *const FIRMessagingRegistrationTokenRefreshedNotification =
    @"com.firebase.messaging.notif.fcm-token-refreshed";
#endif  // defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

NSString *const kFIRMessagingUserDefaultsKeyAutoInitEnabled =
    @"com.firebase.messaging.auto-init.enabled";  // Auto Init Enabled key stored in NSUserDefaults

NSString *const kFIRMessagingPlistAutoInitEnabled =
    @"FirebaseMessagingAutoInitEnabled";  // Auto Init Enabled key stored in Info.plist

const BOOL FIRMessagingIsAPNSSyncMessage(NSDictionary *message) {
  if ([message[kFIRMessagingMessageViaAPNSRootKey] isKindOfClass:[NSDictionary class]]) {
    NSDictionary *aps = message[kFIRMessagingMessageViaAPNSRootKey];
    if (aps && [aps isKindOfClass:[NSDictionary class]]) {
      return [aps[kFIRMessagingMessageAPNSContentAvailableKey] boolValue];
    }
  }
  return NO;
}

BOOL FIRMessagingIsContextManagerMessage(NSDictionary *message) {
  return [FIRMessagingContextManagerService isContextManagerMessage:message];
}

@interface FIRMessagingMessageInfo ()

@property(nonatomic, readwrite, assign) FIRMessagingMessageStatus status;

@end

@implementation FIRMessagingMessageInfo

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
}

- (instancetype)initWithStatus:(FIRMessagingMessageStatus)status {
  self = [super init];
  if (self) {
    _status = status;
  }
  return self;
}

@end

#pragma mark - for iOS 10 compatibility
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation FIRMessagingRemoteMessage
#pragma clang diagnostic pop

- (instancetype)init {
  self = [super init];
  if (self) {
    _appData = [[NSMutableDictionary alloc] init];
  }

  return self;
}

@end

@interface FIRMessaging () <FIRMessagingClientDelegate,
                            FIRMessagingReceiverDelegate,
                            GULReachabilityDelegate>

// FIRApp properties
@property(nonatomic, readwrite, strong) NSData *apnsTokenData;

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;
@property(nonatomic, readwrite, strong) GULReachabilityChecker *reachability;
@property(nonatomic, readwrite, strong) FIRMessagingDataMessageManager *dataMessageManager;
@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmq2Manager;
@property(nonatomic, readwrite, strong) FIRMessagingReceiver *receiver;
@property(nonatomic, readwrite, strong) FIRMessagingSyncMessageManager *syncMessageManager;
@property(nonatomic, readwrite, strong) GULUserDefaults *messagingUserDefaults;
@property(nonatomic, readwrite, strong) FIRInstallations *installations;
@property(nonatomic, readwrite, strong) FIRMessagingTokenManager *tokenManager;

/// Message ID's logged for analytics. This prevents us from logging the same message twice
/// which can happen if the user inadvertently calls `appDidReceiveMessage` along with us
/// calling it implicitly during swizzling.
@property(nonatomic, readwrite, strong) NSMutableSet *loggedMessageIDs;
@property(nonatomic, readwrite, strong) id<FIRAnalyticsInterop> _Nullable analytics;

@end

// Messaging doesn't provide any functionality to other components,
// so it provides a private, empty protocol that it conforms to and use it for registration.

@protocol FIRMessagingInstanceProvider
@end

@interface FIRMessaging () <FIRMessagingInstanceProvider, FIRLibrary>
@end

@implementation FIRMessaging

+ (FIRMessaging *)messaging {
  FIRApp *defaultApp = [FIRApp defaultApp];  // Missing configure will be logged here.
  id<FIRMessagingInstanceProvider> instance =
      FIR_COMPONENT(FIRMessagingInstanceProvider, defaultApp.container);

  // We know the instance coming from the container is a FIRMessaging instance, cast it and move on.
  return (FIRMessaging *)instance;
}

+ (FIRMessagingExtensionHelper *)extensionHelper {
  static dispatch_once_t once;
  static FIRMessagingExtensionHelper *extensionHelper;
  dispatch_once(&once, ^{
    extensionHelper = [[FIRMessagingExtensionHelper alloc] init];
  });
  return extensionHelper;
}

- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics
                 withUserDefaults:(GULUserDefaults *)defaults {
  self = [super init];
  if (self != nil) {
    _loggedMessageIDs = [NSMutableSet set];
    _messagingUserDefaults = defaults;
    _analytics = analytics;
  }
  return self;
}

- (void)dealloc {
  [self.reachability stop];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self teardown];
}

#pragma mark - Config

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                         withName:@"fire-fcm"
                      withVersion:FIRMessagingCurrentLibraryVersion()];
}

+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRDependency *analyticsDep = [FIRDependency dependencyWithProtocol:@protocol(FIRAnalyticsInterop)
                                                           isRequired:NO];
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    if (!container.app.isDefaultApp) {
      // Only start for the default FIRApp.
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeFIRApp001,
                              @"Firebase Messaging only works with the default app.");
      return nil;
    }

    // Ensure it's cached so it returns the same instance every time messaging is called.
    *isCacheable = YES;
    id<FIRAnalyticsInterop> analytics = FIR_COMPONENT(FIRAnalyticsInterop, container);
    FIRMessaging *messaging =
        [[FIRMessaging alloc] initWithAnalytics:analytics
                               withUserDefaults:[GULUserDefaults standardUserDefaults]];
    [messaging start];
    [messaging configureMessagingWithOptions:container.app.options];

    [messaging configureNotificationSwizzlingIfEnabled];
    return messaging;
  };
  FIRComponent *messagingProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRMessagingInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingEagerInDefaultApp
                             dependencies:@[ analyticsDep ]
                            creationBlock:creationBlock];

  return @[ messagingProvider ];
}

- (void)configureMessagingWithOptions:(FIROptions *)options {
  NSString *GCMSenderID = options.GCMSenderID;
  if (!GCMSenderID.length) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeFIRApp000,
                            @"Firebase not set up correctly, nil or empty senderID.");
    [NSException raise:kFIRMessagingDomain
                format:@"Could not configure Firebase Messaging. GCMSenderID must not be nil or "
                       @"empty."];
  }

  self.tokenManager.fcmSenderID = GCMSenderID;
  self.tokenManager.firebaseAppID = options.googleAppID;

  // FCM generates a FCM token during app start for sending push notification to device.
  // This is not needed for app extension except for watch.
#if TARGET_OS_WATCH
  [self didCompleteConfigure];
#else
  if (![GULAppEnvironmentUtil isAppExtension]) {
    [self didCompleteConfigure];
  }
#endif
}

- (void)didCompleteConfigure {
  NSString *cachedToken =
      [self.tokenManager cachedTokenInfoWithAuthorizedEntity:self.tokenManager.fcmSenderID
                                                       scope:kFIRMessagingDefaultTokenScope]
          .token;
  // When there is a cached token, do the token refresh.
  if (cachedToken) {
    // Clean up expired tokens by checking the token refresh policy.
    [self.installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                       NSError *_Nullable error) {
      if ([self.tokenManager checkTokenRefreshPolicyWithIID:identifier]) {
        // Default token is expired, fetch default token from server.
        [self retrieveFCMTokenForSenderID:self.tokenManager.fcmSenderID
                               completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error){
                               }];
      }
    }];
  } else if (self.isAutoInitEnabled) {
    // When there is no cached token, must check auto init is enabled.
    // If it's disabled, don't initiate token generation/refresh.
    // If no cache token and auto init is enabled, fetch a token from server.
    [self retrieveFCMTokenForSenderID:self.tokenManager.fcmSenderID
                           completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error){
                           }];
  }
}

- (void)configureNotificationSwizzlingIfEnabled {
  // Swizzle remote-notification-related methods (app delegate and UNUserNotificationCenter)
  if ([FIRMessagingRemoteNotificationsProxy canSwizzleMethods]) {
    NSString *docsURLString = @"https://firebase.google.com/docs/cloud-messaging/ios/client"
                              @"#method_swizzling_in_firebase_messaging";
    FIRMessagingLoggerNotice(kFIRMessagingMessageCodeFIRApp000,
                             @"FIRMessaging Remote Notifications proxy enabled, will swizzle "
                             @"remote notification receiver handlers. If you'd prefer to manually "
                             @"integrate Firebase Messaging, add \"%@\" to your Info.plist, "
                             @"and set it to NO. Follow the instructions at:\n%@\nto ensure "
                             @"proper integration.",
                             kFIRMessagingRemoteNotificationsProxyEnabledInfoPlistKey,
                             docsURLString);
    [[FIRMessagingRemoteNotificationsProxy sharedProxy] swizzleMethodsIfPossible];
  }
}

- (void)start {
  [self setupFileManagerSubDirectory];
  [self setupNotificationListeners];
  self.tokenManager = [[FIRMessagingTokenManager alloc] init];
  self.installations = [FIRInstallations installations];

#if !TARGET_OS_WATCH
  // Print the library version for logging.
  NSString *currentLibraryVersion = FIRMessagingCurrentLibraryVersion();
  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessagingPrintLibraryVersion,
                         @"FIRMessaging library version %@", currentLibraryVersion);

  [self setupReceiver];

  NSString *hostname = kFIRMessagingReachabilityHostname;
  self.reachability = [[GULReachabilityChecker alloc] initWithReachabilityDelegate:self
                                                                          withHost:hostname];
  [self.reachability start];

  // setup FIRMessaging objects
  [self setupRmqManager];
  [self setupClient];
  [self setupSyncMessageManager];
  [self setupDataMessageManager];
  [self setupTopics];

#endif
}

- (void)setupFileManagerSubDirectory {
  if (![[self class] hasSubDirectory:kFIRMessagingSubDirectoryName]) {
    [[self class] createSubDirectory:kFIRMessagingSubDirectoryName];
  }
  if (![[self class] hasSubDirectory:kFIRMessagingInstanceIDSubDirectoryName]) {
    [[self class] createSubDirectory:kFIRMessagingInstanceIDSubDirectoryName];
  }
}

- (void)setupNotificationListeners {
  // To prevent multiple notifications remove self as observer for all events.
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver:self];
  [center addObserver:self
             selector:@selector(defaultInstanceIDTokenWasRefreshed:)
                 name:kFIRMessagingRegistrationTokenRefreshNotification
               object:nil];
#if TARGET_OS_IOS || TARGET_OS_TV
  [center addObserver:self
             selector:@selector(applicationStateChanged)
                 name:UIApplicationDidBecomeActiveNotification
               object:nil];
  [center addObserver:self
             selector:@selector(applicationStateChanged)
                 name:UIApplicationDidEnterBackgroundNotification
               object:nil];
#endif
}

- (void)defaultInstanceIDTokenWasRefreshed:(NSNotification *)notification {
  if (notification.object && ![notification.object isKindOfClass:[NSString class]]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging015,
                            @"Invalid default FCM token type %@",
                            NSStringFromClass([notification.object class]));
    return;
  }
  // Retrieve the Instance ID default token, and should notify delegate and
  // trigger notification as long as the token is different from previous state.
  NSString *oldToken = self.tokenManager.defaultFCMToken;
  NSString *newToken = [(NSString *)notification.object copy];
  if ((newToken.length && oldToken.length && ![newToken isEqualToString:oldToken]) ||
      newToken.length != oldToken.length) {
    [self.tokenManager setDefaultFCMTokenWithoutUpdate:newToken];
    [self notifyRefreshedFCMToken];
    [self.pubsub scheduleSync:YES];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (self.shouldEstablishDirectChannel) {
      [self updateAutomaticClientConnection];
    }
#pragma clang diagnostic pop
  }
}

- (void)setupReceiver {
  self.receiver = [[FIRMessagingReceiver alloc] init];
  self.receiver.delegate = self;
}

- (void)setupClient {
  self.client = [[FIRMessagingClient alloc] initWithDelegate:self
                                                reachability:self.reachability
                                                 rmq2Manager:self.rmq2Manager
                                                tokenManager:_tokenManager];
}

- (void)setupDataMessageManager {
  self.dataMessageManager =
      [[FIRMessagingDataMessageManager alloc] initWithDelegate:self.receiver
                                                        client:self.client
                                                   rmq2Manager:self.rmq2Manager
                                            syncMessageManager:self.syncMessageManager];

  [self.dataMessageManager refreshDelayedMessages];
  [self.client setDataMessageManager:self.dataMessageManager];
}

- (void)setupRmqManager {
  self.rmq2Manager = [[FIRMessagingRmqManager alloc] initWithDatabaseName:@"rmq2"];
  [self.rmq2Manager loadRmqId];
}

- (void)setupTopics {
  if (!self.client) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeInvalidClient,
                           @"Invalid nil client before init pubsub.");
  }
  self.pubsub = [[FIRMessagingPubSub alloc] initWithClient:self.client];
}

- (void)setupSyncMessageManager {
  self.syncMessageManager =
      [[FIRMessagingSyncMessageManager alloc] initWithRmqManager:self.rmq2Manager];
  [self.syncMessageManager removeExpiredSyncMessages];
}

- (void)teardown {
  [self.client teardown];
  self.pubsub = nil;
  self.syncMessageManager = nil;
  self.rmq2Manager = nil;
  self.dataMessageManager = nil;
  self.client = nil;
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging001, @"Did successfully teardown");
}

#pragma mark - Messages

- (FIRMessagingMessageInfo *)appDidReceiveMessage:(NSDictionary *)message {
  if (!message.count) {
    return [[FIRMessagingMessageInfo alloc] initWithStatus:FIRMessagingMessageStatusUnknown];
  }

  // For downstream messages that go via MCS we should strip out this key before sending
  // the message to the device.
  BOOL isOldMessage = NO;
  NSString *messageID = message[kFIRMessagingMessageIDKey];
  if (messageID.length) {
    [self.rmq2Manager saveS2dMessageWithRmqId:messageID];

    BOOL isSyncMessage = FIRMessagingIsAPNSSyncMessage(message);
    if (isSyncMessage) {
      isOldMessage = [self.syncMessageManager didReceiveAPNSSyncMessage:message];
    }

    // Prevent duplicates by keeping a cache of all the logged messages during each session.
    // The duplicates only happen when the 3P app calls `appDidReceiveMessage:` along with
    // us swizzling their implementation to call the same method implicitly.
    // We need to rule out the contextual message because it shares the same message ID
    // as the local notification it will schedule. And because it is also a APNSSync message
    // its duplication is already checked previously.
    if (!isOldMessage && !FIRMessagingIsContextManagerMessage(message)) {
      isOldMessage = [self.loggedMessageIDs containsObject:messageID];
      if (!isOldMessage) {
        [self.loggedMessageIDs addObject:messageID];
      }
    }
  }

  if (!isOldMessage) {
    [FIRMessagingAnalytics logMessage:message toAnalytics:_analytics];
    [self handleContextManagerMessage:message];
    [self handleIncomingLinkIfNeededFromMessage:message];
  }
  return [[FIRMessagingMessageInfo alloc] initWithStatus:FIRMessagingMessageStatusNew];
}

- (BOOL)handleContextManagerMessage:(NSDictionary *)message {
  if (FIRMessagingIsContextManagerMessage(message)) {
    return [FIRMessagingContextManagerService handleContextManagerMessage:message];
  }
  return NO;
}

- (void)handleIncomingLinkIfNeededFromMessage:(NSDictionary *)message {
#if TARGET_OS_IOS || TARGET_OS_TV
  NSURL *url = [self linkURLFromMessage:message];
  if (url == nil) {
    return;
  }
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self handleIncomingLinkIfNeededFromMessage:message];
    });
    return;
  }
  UIApplication *application = [GULAppDelegateSwizzler sharedApplication];
  if (!application) {
    return;
  }
  id<UIApplicationDelegate> appDelegate = application.delegate;
  SEL continueUserActivitySelector = @selector(application:
                                      continueUserActivity:restorationHandler:);

  SEL openURLWithOptionsSelector = @selector(application:openURL:options:);
  SEL openURLWithSourceApplicationSelector = @selector(application:
                                                           openURL:sourceApplication:annotation:);
#if TARGET_OS_IOS
  SEL handleOpenURLSelector = @selector(application:handleOpenURL:);
#endif
  // Due to FIRAAppDelegateProxy swizzling, this selector will most likely get chosen, whether or
  // not the actual application has implemented
  // |application:continueUserActivity:restorationHandler:|. A warning will be displayed to the user
  // if they haven't implemented it.
  if ([NSUserActivity class] != nil &&
      [appDelegate respondsToSelector:continueUserActivitySelector]) {
    NSUserActivity *userActivity =
        [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    userActivity.webpageURL = url;
    [appDelegate application:application
        continueUserActivity:userActivity
          restorationHandler:^(NSArray *_Nullable restorableObjects){
              // Do nothing, as we don't support the app calling this block
          }];

  } else if ([appDelegate respondsToSelector:openURLWithOptionsSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    [appDelegate application:application openURL:url options:@{}];
#pragma clang diagnostic pop
    // Similarly, |application:openURL:sourceApplication:annotation:| will also always be called,
    // due to the default swizzling done by FIRAAppDelegateProxy in Firebase Analytics
  } else if ([appDelegate respondsToSelector:openURLWithSourceApplicationSelector]) {
#if TARGET_OS_IOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [appDelegate application:application
                     openURL:url
           sourceApplication:FIRMessagingAppIdentifier()
                  annotation:@{}];
#pragma clang diagnostic pop
  } else if ([appDelegate respondsToSelector:handleOpenURLSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [appDelegate application:application handleOpenURL:url];
#pragma clang diagnostic pop
#endif
  }
#endif
}

- (NSURL *)linkURLFromMessage:(NSDictionary *)message {
  NSString *urlString = message[kFIRMessagingMessageLinkKey];
  if (urlString == nil || ![urlString isKindOfClass:[NSString class]] || urlString.length == 0) {
    return nil;
  }
  NSURL *url = [NSURL URLWithString:urlString];
  return url;
}

#pragma mark - APNS

- (NSData *)APNSToken {
  return self.apnsTokenData;
}

- (void)setAPNSToken:(NSData *)APNSToken {
  [self setAPNSToken:APNSToken type:FIRMessagingAPNSTokenTypeUnknown];
}

- (void)setAPNSToken:(NSData *)apnsToken type:(FIRMessagingAPNSTokenType)type {
  if ([apnsToken isEqual:self.apnsTokenData]) {
    return;
  }
  self.apnsTokenData = apnsToken;

  // Notify InstanceID that APNS Token has been set.
  NSDictionary *userInfo = @{kFIRMessagingAPNSTokenType : @(type)};
  // TODO(chliang) This is sent to InstanceID in case users are still using the deprecated SDK.
  // Should be safe to remove once InstanceID is removed.
  NSNotification *notification =
      [NSNotification notificationWithName:kFIRMessagingAPNSTokenNotification
                                    object:[apnsToken copy]
                                  userInfo:userInfo];
  [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];

  [self.tokenManager setAPNSToken:[apnsToken copy] withUserInfo:userInfo];
}

#pragma mark - FCM Token

- (BOOL)isAutoInitEnabled {
  // Defer to the class method since we're just reading from regular userDefaults and we need to
  // read this from IID without instantiating the Messaging singleton.
  return [[self class] isAutoInitEnabledWithUserDefaults:_messagingUserDefaults];
}

/// Checks if Messaging auto-init is enabled in the user defaults instance passed in. This is
/// exposed as a class property for IID to fetch the property without instantiating an instance of
/// Messaging. Since Messaging can only be used with the default FIRApp, we can have one point of
/// entry without context of which FIRApp instance is being used.
/// ** THIS METHOD IS DEPENDED ON INTERNALLY BY IID USING REFLECTION. PLEASE DO NOT CHANGE THE
///  SIGNATURE, AS IT WOULD BREAK AUTOINIT FUNCTIONALITY WITHIN IID. **
+ (BOOL)isAutoInitEnabledWithUserDefaults:(GULUserDefaults *)userDefaults {
  // Check storage
  id isAutoInitEnabledObject =
      [userDefaults objectForKey:kFIRMessagingUserDefaultsKeyAutoInitEnabled];
  if (isAutoInitEnabledObject) {
    return [isAutoInitEnabledObject boolValue];
  }

  // Check Info.plist
  isAutoInitEnabledObject =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:kFIRMessagingPlistAutoInitEnabled];
  if (isAutoInitEnabledObject) {
    return [isAutoInitEnabledObject boolValue];
  }

  // If none of above exists, we default to the global switch that comes from FIRApp.
  return [[FIRApp defaultApp] isDataCollectionDefaultEnabled];
}

- (void)setAutoInitEnabled:(BOOL)autoInitEnabled {
  BOOL isFCMAutoInitEnabled = [self isAutoInitEnabled];
  [_messagingUserDefaults setBool:autoInitEnabled
                           forKey:kFIRMessagingUserDefaultsKeyAutoInitEnabled];
  [_messagingUserDefaults synchronize];
  if (!isFCMAutoInitEnabled && autoInitEnabled) {
    [self.tokenManager tokenAndRequestIfNotExist];
  }
}

- (NSString *)FCMToken {
  // Gets the current default token, and requets a new one if it doesn't exist.
  return [[FIRMessaging messaging].tokenManager tokenAndRequestIfNotExist];
}

- (void)retrieveFCMTokenForSenderID:(nonnull NSString *)senderID
                         completion:(nonnull FIRMessagingFCMTokenFetchCompletion)completion {
  if (!senderID.length) {
    NSString *description = @"Couldn't fetch token because a Sender ID was not supplied. A valid "
                            @"Sender ID is required to fetch an FCM token";
    FIRMessagingLoggerError(kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenFetch, @"%@",
                            description);
    if (completion) {
      NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeMissingAuthorizedEntity
                                         failureReason:description];
      completion(nil, error);
    }
    return;
  }
  NSDictionary *options = nil;
  if (self.APNSToken) {
    options = @{kFIRMessagingFCMTokenFetchAPNSOption : self.APNSToken};
  } else {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeAPNSTokenNotAvailableDuringTokenFetch,
                           @"APNS device token not set before retrieving FCM Token for Sender ID "
                           @"'%@'. Notifications to this FCM Token will not be delivered over APNS."
                           @"Be sure to re-retrieve the FCM token once the APNS device token is "
                           @"set.",
                           senderID);
  }
  [self.tokenManager
      tokenWithAuthorizedEntity:senderID
                          scope:kFIRMessagingDefaultTokenScope
                        options:options
                        handler:^(NSString *_Nullable FCMToken, NSError *_Nullable error) {
                          if (completion) {
                            completion(FCMToken, error);
                          }
                        }];
}

- (void)deleteFCMTokenForSenderID:(nonnull NSString *)senderID
                       completion:(nonnull FIRMessagingDeleteFCMTokenCompletion)completion {
  if (!senderID.length) {
    NSString *description = @"Couldn't delete token because a Sender ID was not supplied. A "
                            @"valid Sender ID is required to delete an FCM token";
    FIRMessagingLoggerError(kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenDelete, @"%@",
                            description);
    if (completion) {
      NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeInvalidRequest
                                         failureReason:description];
      completion(error);
    }
    return;
  }
  FIRMessaging_WEAKIFY(self);
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        FIRMessaging_STRONGIFY(self);
        if (error) {
          NSError *newError = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeInvalidIdentity
                                                failureReason:@"Failed to get installation ID."];
          completion(newError);
        } else {
          [self.tokenManager deleteTokenWithAuthorizedEntity:senderID
                                                       scope:kFIRMessagingDefaultTokenScope
                                                  instanceID:identifier
                                                     handler:^(NSError *_Nullable error) {
                                                       if (completion) {
                                                         completion(error);
                                                       }
                                                     }];
        }
      }];
}

#pragma mark - FIRMessagingDelegate helper methods
- (void)setDelegate:(id<FIRMessagingDelegate>)delegate {
  _delegate = delegate;
  [self validateDelegateConformsToTokenAvailabilityMethods];
}

// Check if the delegate conforms to |didReceiveRegistrationToken:|
// and display a warning to the developer if not.
// NOTE: Once |didReceiveRegistrationToken:| can be made a required method, this
// check can be removed.
- (void)validateDelegateConformsToTokenAvailabilityMethods {
  if (self.delegate && ![self.delegate respondsToSelector:@selector(messaging:
                                                              didReceiveRegistrationToken:)]) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeTokenDelegateMethodsNotImplemented,
                           @"The object %@ does not respond to "
                           @"-messaging:didReceiveRegistrationToken:. Please implement "
                           @"-messaging:didReceiveRegistrationToken: to be provided with an FCM "
                           @"token.",
                           self.delegate.description);
  }
}

- (void)notifyRefreshedFCMToken {
  __weak FIRMessaging *weakSelf = self;
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf notifyRefreshedFCMToken];
    });
    return;
  }
  if ([self.delegate respondsToSelector:@selector(messaging:didReceiveRegistrationToken:)]) {
    [self.delegate messaging:self didReceiveRegistrationToken:self.tokenManager.defaultFCMToken];
  }

  // Should always trigger the token refresh notification when the delegate method is called
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center postNotificationName:FIRMessagingRegistrationTokenRefreshedNotification
                        object:self.tokenManager.defaultFCMToken];
}

#pragma mark - Application State Changes

- (void)applicationStateChanged {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (self.shouldEstablishDirectChannel) {
    [self updateAutomaticClientConnection];
  }
#pragma clang diagnostic pop
}

#pragma mark - Direct Channel

- (void)setShouldEstablishDirectChannel:(BOOL)shouldEstablishDirectChannel {
  if (_shouldEstablishDirectChannel == shouldEstablishDirectChannel) {
    return;
  }
  _shouldEstablishDirectChannel = shouldEstablishDirectChannel;
  [self updateAutomaticClientConnection];
}

- (BOOL)isDirectChannelEstablished {
  return self.client.isConnectionActive;
}

- (BOOL)shouldBeConnectedAutomatically {
#if TARGET_OS_OSX || TARGET_OS_WATCH
  return NO;
#else
  // We require a token from Instance ID
  NSString *token = self.tokenManager.defaultFCMToken;
  // Only on foreground connections
  UIApplication *application = [GULAppDelegateSwizzler sharedApplication];
  if (!application) {
    return NO;
  }
  UIApplicationState applicationState = application.applicationState;
  BOOL shouldBeConnected = _shouldEstablishDirectChannel && (token.length > 0) &&
                           applicationState == UIApplicationStateActive;
  return shouldBeConnected;
#endif
}

- (void)updateAutomaticClientConnection {
  if (![NSThread isMainThread]) {
    // Call this method from the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
      [self updateAutomaticClientConnection];
    });
    return;
  }
  BOOL shouldBeConnected = [self shouldBeConnectedAutomatically];
  if (shouldBeConnected && !self.client.isConnected) {
    [self.client connectWithHandler:^(NSError *error) {
      if (!error) {
        // It means we connected. Fire connection change notification
        [self notifyOfDirectChannelConnectionChange];
      } else {
        FIRMessagingLoggerError(kFIRMessagingMessageCodeDirectChannelConnectionFailed,
                                @"Failed to connect to direct channel, error: %@\n", error);
      }
    }];
  } else if (!shouldBeConnected && self.client.isConnected) {
    [self.client disconnect];
    [self notifyOfDirectChannelConnectionChange];
  }
}

- (void)notifyOfDirectChannelConnectionChange {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [center postNotificationName:FIRMessagingConnectionStateChangedNotification object:self];
#pragma clang diagnostic pop
}

#pragma mark - Topics

+ (NSString *)normalizeTopic:(NSString *)topic {
  if (!topic.length) {
    return nil;
  }
  if (![FIRMessagingPubSub hasTopicsPrefix:topic]) {
    topic = [FIRMessagingPubSub addPrefixToTopic:topic];
  }
  if ([FIRMessagingPubSub isValidTopicWithPrefix:topic]) {
    return [topic copy];
  }
  return nil;
}

- (void)subscribeToTopic:(NSString *)topic {
  [self subscribeToTopic:topic completion:nil];
}

- (void)subscribeToTopic:(NSString *)topic
              completion:(nullable FIRMessagingTopicOperationCompletion)completion {
  if ([FIRMessagingPubSub hasTopicsPrefix:topic]) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeTopicFormatIsDeprecated,
                           @"Format '%@' is deprecated. Only '%@' should be used in "
                           @"subscribeToTopic.",
                           topic, [FIRMessagingPubSub removePrefixFromTopic:topic]);
  }
  __weak FIRMessaging *weakSelf = self;
  [self
      retrieveFCMTokenForSenderID:self.tokenManager.fcmSenderID
                       completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error) {
                         if (error) {
                           FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging010,
                                                   @"The subscription operation failed due to an "
                                                   @"error getting the FCM token: %@.",
                                                   error);
                           if (completion) {
                             completion(error);
                           }
                           return;
                         }
                         FIRMessaging *strongSelf = weakSelf;
                         NSString *normalizeTopic = [[strongSelf class] normalizeTopic:topic];
                         if (normalizeTopic.length) {
                           [strongSelf.pubsub subscribeToTopic:normalizeTopic handler:completion];
                           return;
                         }
                         NSString *failureReason = [NSString
                             stringWithFormat:@"Cannot parse topic name: '%@'. Will not subscribe.",
                                              topic];
                         FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging009, @"%@",
                                                 failureReason);
                         if (completion) {
                           completion([NSError
                               messagingErrorWithCode:kFIRMessagingErrorCodeInvalidTopicName
                                        failureReason:failureReason]);
                         }
                       }];
}

- (void)unsubscribeFromTopic:(NSString *)topic {
  [self unsubscribeFromTopic:topic completion:nil];
}

- (void)unsubscribeFromTopic:(NSString *)topic
                  completion:(nullable FIRMessagingTopicOperationCompletion)completion {
  if ([FIRMessagingPubSub hasTopicsPrefix:topic]) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeTopicFormatIsDeprecated,
                           @"Format '%@' is deprecated. Only '%@' should be used in "
                           @"unsubscribeFromTopic.",
                           topic, [FIRMessagingPubSub removePrefixFromTopic:topic]);
  }
  __weak FIRMessaging *weakSelf = self;
  [self retrieveFCMTokenForSenderID:self.tokenManager.fcmSenderID
                         completion:^(NSString *_Nullable FCMToken, NSError *_Nullable error) {
                           if (error) {
                             FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging012,
                                                     @"The unsubscription operation failed due to "
                                                     @"an error getting the FCM token: %@.",
                                                     error);
                             if (completion) {
                               completion(error);
                             }
                             return;
                           }
                           FIRMessaging *strongSelf = weakSelf;
                           NSString *normalizeTopic = [[strongSelf class] normalizeTopic:topic];
                           if (normalizeTopic.length) {
                             [strongSelf.pubsub unsubscribeFromTopic:normalizeTopic
                                                             handler:completion];
                             return;
                           }
                           NSString *failureReason = [NSString
                               stringWithFormat:
                                   @"Cannot parse topic name: '%@'. Will not unsubscribe.", topic];
                           FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging011, @"%@",
                                                   failureReason);
                           if (completion) {
                             completion([NSError
                                 messagingErrorWithCode:kFIRMessagingErrorCodeInvalidTopicName
                                          failureReason:failureReason]);
                           }
                         }];
}

#pragma mark - Send

- (void)sendMessage:(NSDictionary *)message
                 to:(NSString *)to
      withMessageID:(NSString *)messageID
         timeToLive:(int64_t)ttl {
  NSMutableDictionary *fcmMessage = [[self class] createFIRMessagingMessageWithMessage:message
                                                                                    to:to
                                                                                withID:messageID
                                                                            timeToLive:ttl
                                                                                 delay:0];
  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessaging013,
                         @"Sending message: %@ with id: %@ to %@.", message, messageID, to);
  [self.dataMessageManager sendDataMessageStanza:fcmMessage];
}

+ (NSMutableDictionary *)createFIRMessagingMessageWithMessage:(NSDictionary *)message
                                                           to:(NSString *)to
                                                       withID:(NSString *)msgID
                                                   timeToLive:(int64_t)ttl
                                                        delay:(int)delay {
  NSMutableDictionary *fcmMessage = [NSMutableDictionary dictionary];
  fcmMessage[kFIRMessagingSendTo] = [to copy];
  fcmMessage[kFIRMessagingSendMessageID] = msgID ? [msgID copy] : @"";
  fcmMessage[kFIRMessagingSendTTL] = @(ttl);
  fcmMessage[kFIRMessagingSendDelay] = @(delay);
  fcmMessage[KFIRMessagingSendMessageAppData] =
      [NSMutableDictionary dictionaryWithDictionary:message];
  return fcmMessage;
}

#pragma mark - FIRMessagingReceiverDelegate

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)receiver:(FIRMessagingReceiver *)receiver
    receivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
  if ([self.delegate respondsToSelector:@selector(messaging:didReceiveMessage:)]) {
    [self appDidReceiveMessage:remoteMessage.appData];
#pragma clang diagnostic ignored "-Wunguarded-availability"
    [self.delegate messaging:self didReceiveMessage:remoteMessage];
#pragma clang diagnostic pop
  } else {
    // Delegate methods weren't implemented, so messages are being dropped, log a warning
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeRemoteMessageDelegateMethodNotImplemented,
                           @"FIRMessaging received data-message, but FIRMessagingDelegate's"
                           @"-messaging:didReceiveMessage: not implemented");
  }
}

#pragma mark - GULReachabilityDelegate

- (void)reachability:(GULReachabilityChecker *)reachability
       statusChanged:(GULReachabilityStatus)status {
  [self onNetworkStatusChanged];
}

#pragma mark - Network

- (void)onNetworkStatusChanged {
  if (![self.client isConnected] && [self isNetworkAvailable]) {
    if (self.client.shouldStayConnected) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging014,
                              @"Attempting to establish direct channel.");
      [self.client retryConnectionImmediately:YES];
    }
    [self.pubsub scheduleSync:YES];
  }
}

- (BOOL)isNetworkAvailable {
  GULReachabilityStatus status = self.reachability.reachabilityStatus;
  return (status == kGULReachabilityViaCellular || status == kGULReachabilityViaWifi);
}

- (FIRMessagingNetworkStatus)networkType {
  GULReachabilityStatus status = self.reachability.reachabilityStatus;
  if (![self isNetworkAvailable]) {
    return kFIRMessagingReachabilityNotReachable;
  } else if (status == kGULReachabilityViaCellular) {
    return kFIRMessagingReachabilityReachableViaWWAN;
  } else {
    return kFIRMessagingReachabilityReachableViaWiFi;
  }
}

#pragma mark - Application Support Directory

+ (BOOL)hasSubDirectory:(NSString *)subDirectoryName {
  NSString *subDirectoryPath = [self pathForSubDirectory:subDirectoryName];
  BOOL isDirectory;
  if (![[NSFileManager defaultManager] fileExistsAtPath:subDirectoryPath
                                            isDirectory:&isDirectory]) {
    return NO;
  } else if (!isDirectory) {
    return NO;
  }
  return YES;
}

+ (NSString *)pathForSubDirectory:(NSString *)subDirectoryName {
  NSArray *directoryPaths =
      NSSearchPathForDirectoriesInDomains(FIRMessagingSupportedDirectory(), NSUserDomainMask, YES);
  NSString *dirPath = directoryPaths.lastObject;
  NSArray *components = @[ dirPath, subDirectoryName ];
  return [NSString pathWithComponents:components];
}

+ (BOOL)createSubDirectory:(NSString *)subDirectoryName {
  NSString *subDirectoryPath = [self pathForSubDirectory:subDirectoryName];
  BOOL hasSubDirectory;

  if (![[NSFileManager defaultManager] fileExistsAtPath:subDirectoryPath
                                            isDirectory:&hasSubDirectory]) {
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:subDirectoryPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging017,
                              @"Cannot create directory %@, error: %@", subDirectoryPath, error);
      return NO;
    }
  } else {
    if (!hasSubDirectory) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging018,
                              @"Found file instead of directory at %@", subDirectoryPath);
      return NO;
    }
  }
  return YES;
}

@end
