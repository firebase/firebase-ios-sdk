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

#if  !__has_feature(objc_arc)
#error FIRMessagingLib should be compiled with ARC.
#endif

#import "FIRMessaging.h"
#import "FIRMessaging_Private.h"

#import <UIKit/UIKit.h>

#import "FIRMessagingAnalytics.h"
#import "FIRMessagingClient.h"
#import "FIRMessagingConstants.h"
#import "FIRMessagingContextManagerService.h"
#import "FIRMessagingDataMessageManager.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingExtensionHelper.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingPubSub.h"
#import "FIRMessagingReceiver.h"
#import "FIRMessagingRemoteNotificationsProxy.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessagingSyncMessageManager.h"
#import "FIRMessagingUtilities.h"
#import "FIRMessagingVersionUtilities.h"
#import "FIRMessaging_Private.h"

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRDependency.h>
#import <FirebaseCore/FIRLibrary.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <GoogleUtilities/GULReachabilityChecker.h>
#import <GoogleUtilities/GULUserDefaults.h>

#import "NSError+FIRMessaging.h"

static NSString *const kFIRMessagingMessageViaAPNSRootKey = @"aps";
static NSString *const kFIRMessagingReachabilityHostname = @"www.google.com";
static NSString *const kFIRMessagingDefaultTokenScope = @"*";
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
NSString *const FIRMessagingSendSuccessNotification =
    @"com.firebase.messaging.notif.send-success";
NSString *const FIRMessagingSendErrorNotification =
    @"com.firebase.messaging.notif.send-error";
NSString * const FIRMessagingMessagesDeletedNotification =
    @"com.firebase.messaging.notif.messages-deleted";
NSString * const FIRMessagingConnectionStateChangedNotification =
    @"com.firebase.messaging.notif.connection-state-changed";
NSString * const FIRMessagingRegistrationTokenRefreshedNotification =
    @"com.firebase.messaging.notif.fcm-token-refreshed";
#endif  // defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

NSString *const kFIRMessagingUserDefaultsKeyAutoInitEnabled =
    @"com.firebase.messaging.auto-init.enabled";  // Auto Init Enabled key stored in NSUserDefaults

NSString *const kFIRMessagingAPNSTokenType = @"APNSTokenType"; // APNS Token type key stored in user info.

NSString *const kFIRMessagingPlistAutoInitEnabled =
    @"FirebaseMessagingAutoInitEnabled";  // Auto Init Enabled key stored in Info.plist

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
@implementation FIRMessagingRemoteMessage

- (instancetype)init {
  self = [super init];
  if (self) {
    _appData = [[NSMutableDictionary alloc] init];
  }

  return self;
}

@end

@interface FIRMessaging ()<FIRMessagingClientDelegate, FIRMessagingReceiverDelegate,
                           GULReachabilityDelegate>

// FIRApp properties
@property(nonatomic, readwrite, strong) NSData *apnsTokenData;
@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;

@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;

@property(nonatomic, readwrite, assign) BOOL isClientSetup;

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;
@property(nonatomic, readwrite, strong) GULReachabilityChecker *reachability;
@property(nonatomic, readwrite, strong) FIRMessagingDataMessageManager *dataMessageManager;
@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmq2Manager;
@property(nonatomic, readwrite, strong) FIRMessagingReceiver *receiver;
@property(nonatomic, readwrite, strong) FIRMessagingSyncMessageManager *syncMessageManager;
@property(nonatomic, readwrite, strong) GULUserDefaults *messagingUserDefaults;

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
  FIRMessaging *messaging = (FIRMessaging *)instance;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [messaging start];
  });
  return messaging;
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
                   withInstanceID:(FIRInstanceID *)instanceID
                 withUserDefaults:(GULUserDefaults *)defaults {
  self = [super init];
  if (self != nil) {
    _loggedMessageIDs = [NSMutableSet set];
    _instanceID = instanceID;
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
  FIRDependency *analyticsDep =
      [FIRDependency dependencyWithProtocol:@protocol(FIRAnalyticsInterop) isRequired:NO];
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    // Ensure it's cached so it returns the same instance every time messaging is called.
    *isCacheable = YES;
    id<FIRAnalyticsInterop> analytics = FIR_COMPONENT(FIRAnalyticsInterop, container);
        return [[FIRMessaging alloc] initWithAnalytics:analytics
                                        withInstanceID:[FIRInstanceID instanceID]
                                      withUserDefaults:[GULUserDefaults standardUserDefaults]];
  };
  FIRComponent *messagingProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRMessagingInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingLazy
                             dependencies:@[ analyticsDep ]
                           creationBlock:creationBlock];

  return @[ messagingProvider ];
}

+ (void)configureWithApp:(FIRApp *)app {
  if (!app.isDefaultApp) {
    // Only configure for the default FIRApp.
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeFIRApp001,
                            @"Firebase Messaging only works with the default app.");
    return;
  }
  [[FIRMessaging messaging] configureMessaging:app];
}

- (void)configureMessaging:(FIRApp *)app {
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
    [FIRMessagingRemoteNotificationsProxy swizzleMethods];
  }
}

- (void)start {
  // Print the library version for logging.
  NSString *currentLibraryVersion = FIRMessagingCurrentLibraryVersion();
  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessagingPrintLibraryVersion,
                         @"FIRMessaging library version %@",
                         currentLibraryVersion);

  [self setupReceiver];

  NSString *hostname = kFIRMessagingReachabilityHostname;
  self.reachability = [[GULReachabilityChecker alloc] initWithReachabilityDelegate:self
                                                                          withHost:hostname];
  [self.reachability start];

  [self setupFileManagerSubDirectory];
  // setup FIRMessaging objects
  [self setupRmqManager];
  [self setupClient];
  [self setupSyncMessageManager];
  [self setupDataMessageManager];
  [self setupTopics];

  self.isClientSetup = YES;
  [self setupNotificationListeners];
}

- (void)setupFileManagerSubDirectory {
  if (![[self class] hasSubDirectory:kFIRMessagingSubDirectoryName]) {
    [[self class] createSubDirectory:kFIRMessagingSubDirectoryName];
  }
}

- (void)setupNotificationListeners {
  // To prevent multiple notifications remove self as observer for all events.
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver:self];

  [center addObserver:self
             selector:@selector(didReceiveDefaultInstanceIDToken:)
                 name:kFIRMessagingFCMTokenNotification
               object:nil];
  [center addObserver:self
             selector:@selector(defaultInstanceIDTokenWasRefreshed:)
                 name:kFIRMessagingRegistrationTokenRefreshNotification
               object:nil];
  [center addObserver:self
             selector:@selector(applicationStateChanged)
                 name:UIApplicationDidBecomeActiveNotification
               object:nil];
  [center addObserver:self
             selector:@selector(applicationStateChanged)
                 name:UIApplicationDidEnterBackgroundNotification
               object:nil];
}

- (void)setupReceiver {
  self.receiver = [[FIRMessagingReceiver alloc] initWithUserDefaults:self.messagingUserDefaults];
  self.receiver.delegate = self;
}

- (void)setupClient {
  self.client = [[FIRMessagingClient alloc] initWithDelegate:self
                                                reachability:self.reachability
                                                 rmq2Manager:self.rmq2Manager];
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
  _FIRMessagingDevAssert(self.client, @"Invalid nil client before init pubsub.");
  self.pubsub = [[FIRMessagingPubSub alloc] initWithClient:self.client];
}

- (void)setupSyncMessageManager {
  self.syncMessageManager =
      [[FIRMessagingSyncMessageManager alloc] initWithRmqManager:self.rmq2Manager];

  // Delete the expired messages with a delay. We don't want to block startup with a somewhat
  // expensive db call.
  FIRMessaging_WEAKIFY(self);
  dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC));
  dispatch_after(time, dispatch_get_main_queue(), ^{
    FIRMessaging_STRONGIFY(self);
    [self.syncMessageManager removeExpiredSyncMessages];
  });
}

- (void)teardown {
  _FIRMessagingDevAssert([NSThread isMainThread],
                         @"FIRMessaging should be called from main thread only.");
  [self.client teardown];
  self.pubsub = nil;
  self.syncMessageManager = nil;
  self.rmq2Manager = nil;
  self.dataMessageManager = nil;
  self.client = nil;
  self.isClientSetup = NO;
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
  if ([messageID length]) {
    [self.rmq2Manager saveS2dMessageWithRmqId:messageID];

    BOOL isSyncMessage = [[self class] isAPNSSyncMessage:message];
    if (isSyncMessage) {
      isOldMessage = [self.syncMessageManager didReceiveAPNSSyncMessage:message];
    }
  }
  // Prevent duplicates by keeping a cache of all the logged messages during each session.
  // The duplicates only happen when the 3P app calls `appDidReceiveMessage:` along with
  // us swizzling their implementation to call the same method implicitly.
  if (!isOldMessage && messageID.length) {
    isOldMessage = [self.loggedMessageIDs containsObject:messageID];
    if (!isOldMessage) {
      [self.loggedMessageIDs addObject:messageID];
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
  if ([FIRMessagingContextManagerService isContextManagerMessage:message]) {
    return [FIRMessagingContextManagerService handleContextManagerMessage:message];
  }
  return NO;
}

+ (BOOL)isAPNSSyncMessage:(NSDictionary *)message {
  if ([message[kFIRMessagingMessageViaAPNSRootKey] isKindOfClass:[NSDictionary class]]) {
    NSDictionary *aps = message[kFIRMessagingMessageViaAPNSRootKey];
    return [aps[kFIRMessagingMessageAPNSContentAvailableKey] boolValue];
  }
  return NO;
}

- (void)handleIncomingLinkIfNeededFromMessage:(NSDictionary *)message {
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
  UIApplication *application = FIRMessagingUIApplication();
  if (!application) {
    return;
  }
  id<UIApplicationDelegate> appDelegate = application.delegate;
  SEL continueUserActivitySelector =
      @selector(application:continueUserActivity:restorationHandler:);
  SEL openURLWithOptionsSelector = @selector(application:openURL:options:);
  SEL openURLWithSourceApplicationSelector =
      @selector(application:openURL:sourceApplication:annotation:);
  SEL handleOpenURLSelector = @selector(application:handleOpenURL:);
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
          restorationHandler:^(NSArray * _Nullable restorableObjects) {
      // Do nothing, as we don't support the app calling this block
    }];

  } else if ([appDelegate respondsToSelector:openURLWithOptionsSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    [appDelegate application:application openURL:url options:@{}];
#pragma clang diagnostic pop

  // Similarly, |application:openURL:sourceApplication:annotation:| will also always be called, due
  // to the default swizzling done by FIRAAppDelegateProxy in Firebase Analytics
  } else if ([appDelegate respondsToSelector:openURLWithSourceApplicationSelector]) {
#if TARGET_OS_IOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [appDelegate application:application
                     openURL:url
           sourceApplication:FIRMessagingAppIdentifier()
                  annotation:@{}];
#pragma clang diagnostic pop
#endif
  } else if ([appDelegate respondsToSelector:handleOpenURLSelector]) {
#if TARGET_OS_IOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [appDelegate application:application handleOpenURL:url];
#pragma clang diagnostic pop
#endif
  }
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
  NSNotification *notification =
      [NSNotification notificationWithName:kFIRMessagingAPNSTokenNotification
                                    object:[apnsToken copy]
                                  userInfo:userInfo];
  [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

#pragma mark - FCM

- (BOOL)isAutoInitEnabled {
  // Check storage
  id isAutoInitEnabledObject =
      [_messagingUserDefaults objectForKey:kFIRMessagingUserDefaultsKeyAutoInitEnabled];
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.defaultFcmToken = self.instanceID.token;
#pragma clang diagnostic pop
  }
}

- (NSString *)FCMToken {
  NSString *token = self.defaultFcmToken;
  if (!token) {
    // We may not have received it from Instance ID yet (via NSNotification), so extract it directly
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    token = self.instanceID.token;
#pragma clang diagnostic pop
  }
  return token;
}

- (void)retrieveFCMTokenForSenderID:(nonnull NSString *)senderID
                         completion:(nonnull FIRMessagingFCMTokenFetchCompletion)completion {
  if (!senderID.length) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenFetch,
                            @"Sender ID not supplied. It is required for a token fetch, "
                            @"to identify the sender.");
    if (completion) {
      NSString *description = @"Couldn't fetch token because a Sender ID was not supplied. A valid "
                              @"Sender ID is required to fetch an FCM token";
      NSError *error = [NSError fcm_errorWithCode:FIRMessagingErrorInvalidRequest
                                         userInfo:@{NSLocalizedDescriptionKey : description}];
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
                           @"set.", senderID);
  }
  [self.instanceID tokenWithAuthorizedEntity:senderID
                                       scope:kFIRMessagingDefaultTokenScope
                                     options:options
                                     handler:completion];
}

- (void)deleteFCMTokenForSenderID:(nonnull NSString *)senderID
                       completion:(nonnull FIRMessagingDeleteFCMTokenCompletion)completion {
  if (!senderID.length) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenDelete,
                            @"Sender ID not supplied. It is required to delete an FCM token.");
    if (completion) {
      NSString *description = @"Couldn't delete token because a Sender ID was not supplied. A "
                              @"valid Sender ID is required to delete an FCM token";
      NSError *error = [NSError fcm_errorWithCode:FIRMessagingErrorInvalidRequest
                                         userInfo:@{NSLocalizedDescriptionKey : description}];
      completion(error);
    }
    return;
  }
  [self.instanceID deleteTokenWithAuthorizedEntity:senderID
                                             scope:kFIRMessagingDefaultTokenScope
                                           handler:completion];
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
  if (self.delegate &&
      ![self.delegate respondsToSelector:@selector(messaging:didReceiveRegistrationToken:)]) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeTokenDelegateMethodsNotImplemented,
                           @"The object %@ does not respond to "
                           @"-messaging:didReceiveRegistrationToken:. Please implement "
                           @"-messaging:didReceiveRegistrationToken: to be provided with an FCM "
                           @"token.", self.delegate.description);
  }
}

- (void)notifyDelegateOfFCMTokenAvailability {
  __weak FIRMessaging *weakSelf = self;
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf notifyDelegateOfFCMTokenAvailability];
    });
    return;
  }
  if ([self.delegate respondsToSelector:@selector(messaging:didReceiveRegistrationToken:)]) {
    [self.delegate messaging:self didReceiveRegistrationToken:self.defaultFcmToken];
  }
}


- (void)setUseMessagingDelegateForDirectChannel:(BOOL)useMessagingDelegateForDirectChannel {
  self.receiver.useDirectChannel = useMessagingDelegateForDirectChannel;
}

- (BOOL)useMessagingDelegateForDirectChannel {
  return self.receiver.useDirectChannel;
}

#pragma mark - Application State Changes

- (void)applicationStateChanged {
  if (self.shouldEstablishDirectChannel) {
    [self updateAutomaticClientConnection];
  }
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
  // We require a token from Instance ID
  NSString *token = self.defaultFcmToken;
  // Only on foreground connections
  UIApplication *application = FIRMessagingUIApplication();
  if (!application) {
    return NO;
  }
  UIApplicationState applicationState = application.applicationState;
  BOOL shouldBeConnected = _shouldEstablishDirectChannel &&
                           (token.length > 0) &&
                           applicationState == UIApplicationStateActive;
  return shouldBeConnected;
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
      }
    }];
  } else if (!shouldBeConnected && self.client.isConnected) {
    [self.client disconnect];
    [self notifyOfDirectChannelConnectionChange];
  }
}

- (void)notifyOfDirectChannelConnectionChange {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center postNotificationName:FIRMessagingConnectionStateChangedNotification object:self];
}

#pragma mark - Connect

- (void)connectWithCompletion:(FIRMessagingConnectCompletion)handler {
  _FIRMessagingDevAssert([NSThread isMainThread],
                         @"FIRMessaging connect should be called from main thread only.");
  _FIRMessagingDevAssert(self.isClientSetup, @"FIRMessaging client not setup.");
  [self.client connectWithHandler:^(NSError *error) {
    if (handler) {
      handler(error);
    }
    if (!error) {
      // It means we connected. Fire connection change notification
      [self notifyOfDirectChannelConnectionChange];
    }
  }];

}

- (void)disconnect {
  _FIRMessagingDevAssert([NSThread isMainThread],
                         @"FIRMessaging should be called from main thread only.");
  if ([self.client isConnected]) {
    [self.client disconnect];
    [self notifyOfDirectChannelConnectionChange];
  }
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
  if (!self.defaultFcmToken.length) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeMessaging010,
                           @"The subscription operation is suspended because you don't have a "
                           @"token. The operation will resume once you get an FCM token.");
  }
  NSString *normalizeTopic = [[self class] normalizeTopic:topic];
  if (normalizeTopic.length) {
    [self.pubsub subscribeToTopic:normalizeTopic handler:completion];
    return;
  }
  FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging009,
                          @"Cannot parse topic name %@. Will not subscribe.", topic);
  if (completion) {
    completion([NSError fcm_errorWithCode:FIRMessagingErrorInvalidTopicName userInfo:nil]);
  }
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
  if (!self.defaultFcmToken.length) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeMessaging012,
                           @"The unsubscription operation is suspended because you don't have a "
                           @"token. The operation will resume once you get an FCM token.");
  }
  NSString *normalizeTopic = [[self class] normalizeTopic:topic];
  if (normalizeTopic.length) {
    [self.pubsub unsubscribeFromTopic:normalizeTopic handler:completion];
    return;
  }
  FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging011,
                          @"Cannot parse topic name %@. Will not unsubscribe.", topic);
  if (completion) {
    completion([NSError fcm_errorWithCode:FIRMessagingErrorInvalidTopicName userInfo:nil]);
  }
}

#pragma mark - Send

- (void)sendMessage:(NSDictionary *)message
                 to:(NSString *)to
      withMessageID:(NSString *)messageID
         timeToLive:(int64_t)ttl {
  _FIRMessagingDevAssert([to length] != 0, @"Invalid receiver id for FIRMessaging-message");

  NSMutableDictionary *fcmMessage = [[self class] createFIRMessagingMessageWithMessage:message
                                                                           to:to
                                                                       withID:messageID
                                                                   timeToLive:ttl
                                                                        delay:0];
  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessaging013, @"Sending message: %@ with id: %@",
                         message, messageID);
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

#pragma mark - IID dependencies

+ (NSString *)FIRMessagingSDKVersion {
  return FIRMessagingCurrentLibraryVersion();
}

+ (NSString *)FIRMessagingSDKCurrentLocale {
  return [self currentLocale];
}

#pragma mark - FIRMessagingReceiverDelegate

- (void)receiver:(FIRMessagingReceiver *)receiver
      receivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
  if ([self.delegate respondsToSelector:@selector(messaging:didReceiveMessage:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    [self.delegate messaging:self didReceiveMessage:remoteMessage];
#pragma pop
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

#pragma mark - Notifications

- (void)didReceiveDefaultInstanceIDToken:(NSNotification *)notification {
  if (notification.object && ![notification.object isKindOfClass:[NSString class]]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging015,
                            @"Invalid default FCM token type %@",
                            NSStringFromClass([notification.object class]));
    return;
  }
  NSString *oldToken = self.defaultFcmToken;
  self.defaultFcmToken = [(NSString *)notification.object copy];
  if (self.defaultFcmToken && ![self.defaultFcmToken isEqualToString:oldToken]) {
    [self notifyDelegateOfFCMTokenAvailability];
  }
  [self.pubsub scheduleSync:YES];
  if (self.shouldEstablishDirectChannel) {
    [self updateAutomaticClientConnection];
  }
}

- (void)defaultInstanceIDTokenWasRefreshed:(NSNotification *)notification {
  // Retrieve the Instance ID default token, and if it is non-nil, post it
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSString *token = self.instanceID.token;
#pragma clang diagnostic pop
  // Sometimes Instance ID doesn't yet have a token, so wait until the default
  // token is fetched, and then notify. This ensures that this token should not
  // be nil when the developer accesses it.
  if (token != nil) {
    NSString *oldToken = self.defaultFcmToken;
    self.defaultFcmToken = [token copy];
    if (self.defaultFcmToken && ![self.defaultFcmToken isEqualToString:oldToken]) {
      [self notifyDelegateOfFCMTokenAvailability];
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:FIRMessagingRegistrationTokenRefreshedNotification object:nil];
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
  NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(FIRMessagingSupportedDirectory(),
                                                                NSUserDomainMask, YES);
  NSString *dirPath = directoryPaths.lastObject;
  NSArray *components = @[dirPath, subDirectoryName];
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

#pragma mark - Locales

+ (NSString *)currentLocale {
  NSArray *locales = [self firebaseLocales];
  NSArray *preferredLocalizations =
    [NSBundle preferredLocalizationsFromArray:locales
                               forPreferences:[NSLocale preferredLanguages]];
  NSString *legalDocsLanguage = [preferredLocalizations firstObject];
  // Use en as the default language
  return legalDocsLanguage ? legalDocsLanguage : @"en";
}

+ (NSArray *)firebaseLocales {
  NSMutableArray *locales = [NSMutableArray array];
  NSDictionary *localesMap = [self firebaselocalesMap];
  for (NSString *key in localesMap) {
    [locales addObjectsFromArray:localesMap[key]];
  }
  return locales;
}

+ (NSDictionary *)firebaselocalesMap {
  return @{
    // Albanian
    @"sq" : @[ @"sq_AL" ],
    // Belarusian
    @"be" : @[ @"be_BY" ],
    // Bulgarian
    @"bg" : @[ @"bg_BG" ],
    // Catalan
    @"ca" : @[ @"ca", @"ca_ES" ],
    // Croatian
    @"hr" : @[ @"hr", @"hr_HR" ],
    // Czech
    @"cs" : @[ @"cs", @"cs_CZ" ],
    // Danish
    @"da" : @[ @"da", @"da_DK" ],
    // Estonian
    @"et" : @[ @"et_EE" ],
    // Finnish
    @"fi" : @[ @"fi", @"fi_FI" ],
    // Hebrew
    @"he" : @[ @"he", @"iw_IL" ],
    // Hindi
    @"hi" : @[ @"hi_IN" ],
    // Hungarian
    @"hu" : @[ @"hu", @"hu_HU" ],
    // Icelandic
    @"is" : @[ @"is_IS" ],
    // Indonesian
    @"id" : @[ @"id", @"in_ID", @"id_ID" ],
    // Irish
    @"ga" : @[ @"ga_IE" ],
    // Korean
    @"ko" : @[ @"ko", @"ko_KR", @"ko-KR" ],
    // Latvian
    @"lv" : @[ @"lv_LV" ],
    // Lithuanian
    @"lt" : @[ @"lt_LT" ],
    // Macedonian
    @"mk" : @[ @"mk_MK" ],
    // Malay
    @"ms" : @[ @"ms_MY" ],
    // Maltese
    @"ms" : @[ @"mt_MT" ],
    // Polish
    @"pl" : @[ @"pl", @"pl_PL", @"pl-PL" ],
    // Romanian
    @"ro" : @[ @"ro", @"ro_RO" ],
    // Russian
    @"ru" : @[ @"ru_RU", @"ru", @"ru_BY", @"ru_KZ", @"ru-RU" ],
    // Slovak
    @"sk" : @[ @"sk", @"sk_SK" ],
    // Slovenian
    @"sl" : @[ @"sl_SI" ],
    // Swedish
    @"sv" : @[ @"sv", @"sv_SE", @"sv-SE" ],
    // Turkish
    @"tr" : @[ @"tr", @"tr-TR", @"tr_TR" ],
    // Ukrainian
    @"uk" : @[ @"uk", @"uk_UA" ],
    // Vietnamese
    @"vi" : @[ @"vi", @"vi_VN" ],
    // The following are groups of locales or locales that sub-divide a
    // language).
    // Arabic
    @"ar" : @[
      @"ar",
      @"ar_DZ",
      @"ar_BH",
      @"ar_EG",
      @"ar_IQ",
      @"ar_JO",
      @"ar_KW",
      @"ar_LB",
      @"ar_LY",
      @"ar_MA",
      @"ar_OM",
      @"ar_QA",
      @"ar_SA",
      @"ar_SD",
      @"ar_SY",
      @"ar_TN",
      @"ar_AE",
      @"ar_YE",
      @"ar_GB",
      @"ar-IQ",
      @"ar_US"
    ],
    // Simplified Chinese
    @"zh_Hans" : @[ @"zh_CN", @"zh_SG", @"zh-Hans" ],
    // Traditional Chinese
    @"zh_Hant" : @[ @"zh_HK", @"zh_TW", @"zh-Hant", @"zh-HK", @"zh-TW" ],
    // Dutch
    @"nl" : @[ @"nl", @"nl_BE", @"nl_NL", @"nl-NL" ],
    // English
    @"en" : @[
      @"en",
      @"en_AU",
      @"en_CA",
      @"en_IN",
      @"en_IE",
      @"en_MT",
      @"en_NZ",
      @"en_PH",
      @"en_SG",
      @"en_ZA",
      @"en_GB",
      @"en_US",
      @"en_AE",
      @"en-AE",
      @"en_AS",
      @"en-AU",
      @"en_BD",
      @"en-CA",
      @"en_EG",
      @"en_ES",
      @"en_GB",
      @"en-GB",
      @"en_HK",
      @"en_ID",
      @"en-IN",
      @"en_NG",
      @"en-PH",
      @"en_PK",
      @"en-SG",
      @"en-US"
    ],
    // French

    @"fr" : @[
      @"fr",
      @"fr_BE",
      @"fr_CA",
      @"fr_FR",
      @"fr_LU",
      @"fr_CH",
      @"fr-CA",
      @"fr-FR",
      @"fr_MA"
    ],
    // German
    @"de" : @[ @"de", @"de_AT", @"de_DE", @"de_LU", @"de_CH", @"de-DE" ],
    // Greek
    @"el" : @[ @"el", @"el_CY", @"el_GR" ],
    // Italian
    @"it" : @[ @"it", @"it_IT", @"it_CH", @"it-IT" ],
    // Japanese
    @"ja" : @[ @"ja", @"ja_JP", @"ja_JP_JP", @"ja-JP" ],
    // Norwegian
    @"no" : @[ @"nb", @"no_NO", @"no_NO_NY", @"nb_NO" ],
    // Brazilian Portuguese
    @"pt_BR" : @[ @"pt_BR", @"pt-BR" ],
    // European Portuguese
    @"pt_PT" : @[ @"pt", @"pt_PT", @"pt-PT" ],
    // Serbian
    @"sr" : @[
      @"sr_BA",
      @"sr_ME",
      @"sr_RS",
      @"sr_Latn_BA",
      @"sr_Latn_ME",
      @"sr_Latn_RS"
    ],
    // European Spanish
    @"es_ES" : @[ @"es", @"es_ES", @"es-ES" ],
    // Mexican Spanish
    @"es_MX" : @[ @"es-MX", @"es_MX", @"es_US", @"es-US" ],
    // Latin American Spanish
    @"es_419" : @[
      @"es_AR",
      @"es_BO",
      @"es_CL",
      @"es_CO",
      @"es_CR",
      @"es_DO",
      @"es_EC",
      @"es_SV",
      @"es_GT",
      @"es_HN",
      @"es_NI",
      @"es_PA",
      @"es_PY",
      @"es_PE",
      @"es_PR",
      @"es_UY",
      @"es_VE",
      @"es-AR",
      @"es-CL",
      @"es-CO"
    ],
    // Thai
    @"th" : @[ @"th", @"th_TH", @"th_TH_TH" ],
  };
}

@end
