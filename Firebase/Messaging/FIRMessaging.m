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

// FIXME b/36640532
//#import "googlemac/iPhone/Shared/Net/GIPReachability.h"

#import "FIRMessagingAnalytics.h"
#import "FIRMessagingClient.h"
#import "FIRMessagingConfig.h"
#import "FIRMessagingConstants.h"
#import "FIRMessagingContextManagerService.h"
#import "FIRMessagingDataMessageManager.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingPubSub.h"
#import "FIRMessagingReceiver.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessagingSyncMessageManager.h"
#import "FIRMessagingUtilities.h"
#import "FIRMessagingVersionUtilities.h"

static const NSString *const kFIRMessagingMessageViaAPNSRootKey = @"aps";
static NSString *const kFIRMessagingReachabilityHostname = @"www.google.com";
static NSString *const kClassNameExperimentController = @"FIRExperimentController";
static NSString *const kClassNameLifecycleEvent = @"FIRLifecycleEvents";
static NSString *const kMethodNameSetExperiment =
    @"setExperimentWithServiceOrigin:events:policy:payload:";

NSString *const FIRMessagingSendSuccessNotification =
    @"com.firebase.messaging.notif.send-success";
NSString *const FIRMessagingSendErrorNotification =
    @"com.firebase.messaging.notif.send-error";
NSString * const FIRMessagingMessagesDeletedNotification =
    @"com.firebase.messaging.notif.messages-deleted";

// Copied from Apple's header in case it is missing in some cases (e.g. pre-Xcode 8 builds).
#ifndef NSFoundationVersionNumber_iOS_8_x_Max
#define NSFoundationVersionNumber_iOS_8_x_Max 1199
#endif

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

- (instancetype)initWithMessage:(FIRMessagingRemoteMessage *)message {
  self = [self init];
  if (self) {
    _appData = [message.appData copy];
  }

  return self;
}

@end

@interface FIRMessaging () <FIRMessagingClientDelegate>

// FIRApp properties
@property(nonatomic, readwrite, copy) NSString *fcmSenderID;
@property(nonatomic, readwrite, strong) NSData *apnsTokenData;
@property(nonatomic, readwrite, strong) NSString *apnsToken;
@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;

@property(nonatomic, readwrite, strong) FIRMessagingConfig *config;
@property(nonatomic, readwrite, assign) BOOL isClientSetup;

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;
@property(nonatomic, readwrite, strong) GIPReachability *reachability;
@property(nonatomic, readwrite, strong) FIRMessagingDataMessageManager *dataMessageManager;
@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmq2Manager;
@property(nonatomic, readwrite, strong) FIRMessagingReceiver *receiver;
@property(nonatomic, readwrite, strong) FIRMessagingSyncMessageManager *syncMessageManager;

/// Message ID's logged for analytics. This prevents us from logging the same message twice
/// which can happen if the user inadvertently calls `appDidReceiveMessage` along with us
/// calling it implicitly during swizzling.
@property(nonatomic, readwrite, strong) NSMutableSet *loggedMessageIDs;

@end

@implementation FIRMessaging

+ (FIRMessaging *)messaging {
  static FIRMessaging *messaging;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // Start Messaging (Fully initialize in one place).
    FIRMessagingConfig *config = [FIRMessagingConfig defaultConfig];
    messaging = [[FIRMessaging alloc] initWithConfig:config];
    [messaging start];
  });
  return messaging;
}

- (instancetype)initWithConfig:(FIRMessagingConfig *)config {
  self = [super init];
  if (self) {
    _config = config;
    _loggedMessageIDs = [NSMutableSet set];
  }
  return self;
}

- (void)dealloc {
//  [self.reachability stop];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self teardown];
}

- (void)setRemoteMessageDelegate:(id<FIRMessagingDelegate>)delegate {
  if (self.receiver && delegate) {
    self.receiver.remoteMessagingDelegate = delegate;
  }
}

- (id<FIRMessagingDelegate>)remoteMessageDelegate {
  return self.receiver.remoteMessagingDelegate;
}

#pragma mark - Config

- (void)start {
  _FIRMessagingDevAssert(self.config, @"Invalid nil config in FIRMessagingService");

  [self saveLibraryVersion];
  [self setupLogger:self.config.logLevel];
  [self setupReceiverWithConfig:self.config];

  // TODO: b/31255903 update GIPReachability.m to check the device version as well.
  // TODO: figure out a more generic way to check device version that is compatible for
  // different platforms, e.g. iOS/watchOS/macOS/etc.
//  if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_x_Max) {
//    // Use the IPv6 friendly method SCNetworkReachabilityCreateWithName to check the reachability.
//    self.reachability =
////        [[GIPReachability alloc] initWithHostName:kFIRMessagingReachabilityHostname];
//  } else {
//    // Use the SCNetworkReachabilityCreateWithAddress method to check reachability for devices
//    // running iOS 8 or below, as there is some DNS lookup issue with the older versions
//    // (see b/31040435).
//    self.reachability = [[GIPReachability alloc] init];
//  }

 // [self.reachability startWithCompletionHandler:nil];

  [self setupApplicationSupportSubDirectory];
  // setup FIRMessaging objects
  [self setupRmqManager];
  [self setupClient];
  [self setupSyncMessageManager];
  [self setupDataMessageManager];
  [self setupTopics];

  self.isClientSetup = YES;
  [self setupNotificationListeners];
}

- (void)setupApplicationSupportSubDirectory {
  NSString *messagingSubDirectory = kFIRMessagingApplicationSupportSubDirectory;
  if (![[self class] hasApplicationSupportSubDirectory:messagingSubDirectory]) {
    [[self class] createApplicationSupportSubDirectory:messagingSubDirectory];
  }
}

- (void)setupNotificationListeners {
  // To prevent multiple notifications remove self as observer for all events.
  [[NSNotificationCenter defaultCenter] removeObserver:self];
//  [[NSNotificationCenter defaultCenter] addObserver:self
//                                           selector:@selector(networkStatusChanged)
//                                               name:kGIPReachabilityChangedNotification
//                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveDefaultFCMToken:)
                                               name:kFIRMessagingFCMTokenNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveAPNSToken:)
                                               name:kFIRMessagingAPNSTokenNotification
                                             object:nil];
}

- (void)saveLibraryVersion {
  NSString *currentLibraryVersion = FIRMessagingCurrentLibraryVersion();
  [[NSUserDefaults standardUserDefaults] setObject:currentLibraryVersion
                                            forKey:kFIRMessagingLibraryVersion];
  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessaging000, @"FIRMessaging library version %@",
                         currentLibraryVersion);
}

- (void)setupLogger:(FIRMessagingLogLevel)loggerLevel {
#if FIRMessaging_PROBER
  // do nothing
#else
  FIRMessagingLogger *logger = FIRMessagingSharedLogger();
  FIRMessagingLogLevelFilter *filter =
      [[FIRMessagingLogLevelFilter alloc] initWithLevel:loggerLevel];
  [logger setFilter:filter];
#endif
}

- (void)setupReceiverWithConfig:(FIRMessagingConfig *)config {
  self.receiver = [[FIRMessagingReceiver alloc] init];
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
    [self updateExperimentsIfNeededFromMessage:message];
    [self logAnalyticsForMessage:message];
    [self handleContextManagerMessage:message];
    [self handleIncomingLinkIfNeededFromMessage:message];
  }
  return [[FIRMessagingMessageInfo alloc] initWithStatus:FIRMessagingMessageStatusNew];
}

- (void)updateExperimentsIfNeededFromMessage:(NSDictionary *)message {
  Class experimentClass = NSClassFromString(kClassNameExperimentController);
  if (!experimentClass) {
    return;
  }
  SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
  if (![experimentClass respondsToSelector:sharedInstanceSelector]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging002,
                            @"[%@ sharedInstance] does not exist in this version of Firebase.",
                            kClassNameExperimentController);
    return;
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  id sharedInstance = [experimentClass performSelector:sharedInstanceSelector];
#pragma clang diagnostic pop

  SEL experimentSelector = NSSelectorFromString(kMethodNameSetExperiment);
  if (![sharedInstance respondsToSelector:experimentSelector]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging003, @"Method %@ does not exist.",
                            kMethodNameSetExperiment);
    return;
  }
  NSMethodSignature *signature = [sharedInstance methodSignatureForSelector:experimentSelector];
  if (!signature) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging004, @"No signature for %@ selector.",
                            kClassNameExperimentController);
    return;
  }
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
  if (!inv) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging005,
                            @"No invocation for %@ signature.", kClassNameExperimentController);
    return;
  }

  NSString *originArgument = @"REPLACEME";
  Class lifecycleEventClass = NSClassFromString(kClassNameLifecycleEvent);
  id lifecycleEvent = [[lifecycleEventClass alloc] init];
  // Discard oldest experiments policy = 1
  // The full list of policy can be found at
  // //depot/google3/developers/mobile/abt/proto/experiment_payload.proto
  int defaultPolicy = 1;
  [inv setSelector:experimentSelector];
  [inv setTarget:sharedInstance];
  [inv setArgument:&originArgument atIndex:2];
  [inv setArgument:&lifecycleEvent atIndex:3];
  [inv setArgument:&defaultPolicy atIndex:4];

  NSData *payload = [self abtExperimentPayloadFromMessage:message];
  if (!payload) {
    return;
  }
  [inv setArgument:&payload atIndex:5];

  [inv invoke];
}


- (NSData *)abtExperimentPayloadFromMessage:(NSDictionary *)message {
  NSString *encodedPayloadString = message[kFIRMessagingMessageABTExperimentPayloadKey];
  if (!encodedPayloadString) {
    // nil
    return nil;
  }
  if (![encodedPayloadString isKindOfClass:[NSString class]]) {
    FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessaging006,
                           @"FIRMessaging could not parse experiment payload.");
    return nil;
  }
  if (encodedPayloadString.length == 0) {
    // zero-length
    FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessaging007,
                           @"FIRMessaging received an empty experiment payload.");
    return nil;
  }
  NSData *payload = [[NSData alloc] initWithBase64EncodedString:encodedPayloadString options:0];
  if (!payload) {
    FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessaging008,
                           @"FIRMessaging could not parse experiment payload.");
    return nil;
  }
  return payload;
}

- (void)logAnalyticsForMessage:(NSDictionary *)message {
#if !defined(FIRMessaging_GYP_PROJECT)
  if (![FIRMessagingAnalytics canLogNotification:message]) {
    return;
  }
  UIApplicationState applicationState = [UIApplication sharedApplication].applicationState;
  switch (applicationState) {
    case UIApplicationStateInactive:
      // App was either in background(suspended) or inactive and user tapped on a display
      // notification.
      [FIRMessagingAnalytics logOpenNotification:message];
      break;

    case UIApplicationStateActive:
      // App was in foreground when it received the notification.
      [FIRMessagingAnalytics logForegroundNotification:message];
      break;

    default:
      // Only a silent notification (i.e. 'content-available' is true) can be received while the app
      // is in the background. These messages aren't loggable anyway.
      break;
  }
#endif
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
  UIApplication *application = [UIApplication sharedApplication];
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
    [appDelegate application:application openURL:url options:@{}];

  // Similarly, |application:openURL:sourceApplication:annotation:| will also always be called, due
  // to the default swizzling done by FIRAAppDelegateProxy in Firebase Analytics
  } else if ([appDelegate respondsToSelector:openURLWithSourceApplicationSelector]) {
    [appDelegate application:application
                     openURL:url
           sourceApplication:FIRMessagingAppIdentifier()
                  annotation:@{}];

  } else if ([appDelegate respondsToSelector:handleOpenURLSelector]) {
    [appDelegate application:application handleOpenURL:url];
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

#pragma mark - Connect

- (void)connectWithCompletion:(FIRMessagingConnectCompletion)handler {
  _FIRMessagingDevAssert([NSThread isMainThread],
                         @"FIRMessaging connect should be called from main thread only.");
  _FIRMessagingDevAssert(self.isClientSetup, @"FIRMessaging client not setup.");
  [self.client connectWithHandler:handler];

}

- (void)disconnect {
  _FIRMessagingDevAssert([NSThread isMainThread],
                         @"FIRMessaging should be called from main thread only.");
  if ([self.client isConnected]) {
    [self.client disconnect];
  }
}

#pragma mark - Topics

+ (NSString *)normalizeTopic:(NSString *)topic {
  if (![FIRMessagingPubSub hasTopicsPrefix:topic]) {
    topic = [FIRMessagingPubSub addPrefixToTopic:topic];
  }
  if ([FIRMessagingPubSub isValidTopicWithPrefix:topic]) {
    return [topic copy];
  }
  return nil;
}

- (void)subscribeToTopic:(NSString *)topic {
  if (self.defaultFcmToken.length && topic.length) {
    NSString *normalizeTopic = [[self class ] normalizeTopic:topic];
    if (normalizeTopic.length) {
      [self.pubsub subscribeToTopic:normalizeTopic];
    } else {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging009,
                              @"Cannot parse topic name %@. Will not subscribe.", topic);
    }
  } else {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging010,
                            @"Cannot subscribe to topic: %@ with token: %@", topic,
                            self.defaultFcmToken);
  }
}

- (void)unsubscribeFromTopic:(NSString *)topic {
  if (self.defaultFcmToken.length && topic.length) {
    NSString *normalizeTopic = [[self class] normalizeTopic:topic];
    if (normalizeTopic.length) {
      [self.pubsub unsubscribeFromTopic:normalizeTopic];
    } else {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging011,
                              @"Cannot parse topic name %@. Will not unsubscribe.", topic);
    }
  } else {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeMessaging012,
                            @"Cannot unsubscribe to topic: %@ with token: %@", topic,
                            self.defaultFcmToken);
  }
}

#pragma mark - Send

- (void)sendMessage:(NSDictionary *)message
                 to:(NSString *)to
      withMessageID:(NSString *)messageID
         timeToLive:(int64_t)ttl {
  _FIRMessagingDevAssert([to length] != 0, @"Invalid receiver id for FIRMessaging-message");

  NSMutableDictionary *gcmMessage = [[self class] createFIRMessagingMessageWithMessage:message
                                                                           to:to
                                                                       withID:messageID
                                                                   timeToLive:ttl
                                                                        delay:0];
  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeMessaging013, @"Sending message: %@ with id: %@",
                         message, messageID);
  [self.dataMessageManager sendDataMessageStanza:gcmMessage];
}

+ (NSMutableDictionary *)createFIRMessagingMessageWithMessage:(NSDictionary *)message
                                                  to:(NSString *)to
                                              withID:(NSString *)msgID
                                          timeToLive:(int64_t)ttl
                                               delay:(int)delay {
  NSMutableDictionary *gcmMessage = [NSMutableDictionary dictionary];
  gcmMessage[kFIRMessagingSendTo] = [to copy];
  gcmMessage[kFIRMessagingSendMessageID] = msgID ? [msgID copy] : @"";
  gcmMessage[kFIRMessagingSendTTL] = @(ttl);
  gcmMessage[kFIRMessagingSendDelay] = @(delay);
  gcmMessage[KFIRMessagingSendMessageAppData] =
      [NSMutableDictionary dictionaryWithDictionary:message];
  return gcmMessage;
}

#pragma mark - IID dependencies

// FIRMessagingInternalUtilities.h to see usage.
+ (NSString *)FIRMessagingSDKVersion {
  NSString *semanticVersion = FIRMessagingCurrentLibraryVersion();
  // Use prefix fcm for all FCM libs. This allows us to differentiate b/w
  // the new and old GCM registrations.
  return [NSString stringWithFormat:@"fcm-%@", semanticVersion];
}

+ (NSString *)FIRMessagingSDKCurrentLocale {
  // GIPLocale doesn't support all the locales AppManager supports. Hence we need to roll out
  // our version of all the locales.
  return [self currentLocale];
}

- (void)setAPNSToken:(NSData *)apnsToken error:(NSError *)error {
  if (apnsToken) {
    self.apnsTokenData = [apnsToken copy];
  }
}

#pragma mark - Network

- (BOOL)isNetworkAvailable {
  return YES;
 // return self.reachability.isReachable;
}

- (FIRMessagingNetworkStatus)networkType {
  if (![self isNetworkAvailable]) {
    return kFIRMessagingReachabilityNotReachable;
//  } else if ([self.reachability isCellularNetwork]) {
//    return kFIRMessagingReachabilityReachableViaWWAN;
  } else {
    return kFIRMessagingReachabilityReachableViaWiFi;
  }
}

#pragma mark - Notifications

- (void)networkStatusChanged {
  if (![self.client isConnected] && [self isNetworkAvailable]) {
    if (self.client.shouldStayConnected) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging014,
                              @"Attempting to establish direct channel.");
      [self.client retryConnectionImmediately:YES];
    }
    [self.pubsub scheduleSync:YES];
  }
}

- (void)didReceiveDefaultFCMToken:(NSNotification *)notification {
  if (![notification.object isKindOfClass:[NSString class]]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging015,
                            @"Invalid default FCM token type %@",
                            NSStringFromClass([notification.object class]));
    return;
  }
  self.defaultFcmToken = [(NSString *)notification.object copy];
  [self.pubsub scheduleSync:YES];
}

- (void)didReceiveAPNSToken:(NSNotification *)notification {
  if (![notification.object isKindOfClass:[NSData class]]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeMessaging016, @"Invalid APNS token type %@",
                            NSStringFromClass([notification.object class]));
    return;
  }
  [self setAPNSToken:notification.object error:nil];
}

#pragma mark - Application Support Directory

+ (BOOL)hasApplicationSupportSubDirectory:(NSString *)subDirectoryName {
  NSString *subDirectoryPath = [self pathForApplicationSupportSubDirectory:subDirectoryName];
  BOOL isDirectory;
  if (![[NSFileManager defaultManager] fileExistsAtPath:subDirectoryPath
                                            isDirectory:&isDirectory]) {
    return NO;
  } else if (!isDirectory) {
    return NO;
  }
  return YES;
}

+ (NSString *)pathForApplicationSupportSubDirectory:(NSString *)subDirectoryName {
  NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                NSUserDomainMask, YES);
  NSString *applicationSupportDirPath = directoryPaths.lastObject;
  NSArray *components = @[applicationSupportDirPath, subDirectoryName];
  return [NSString pathWithComponents:components];
}

+ (BOOL)createApplicationSupportSubDirectory:(NSString *)subDirectoryName {
  NSString *subDirectoryPath = [self pathForApplicationSupportSubDirectory:subDirectoryName];
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
  NSArray *locales = [self appManagerLocales];
  NSArray *preferredLocalizations =
    [NSBundle preferredLocalizationsFromArray:locales
                               forPreferences:[NSLocale preferredLanguages]];
  NSString *legalDocsLanguage = [preferredLocalizations firstObject];
  // Use en as the default language
  return legalDocsLanguage ? legalDocsLanguage : @"en";
}

+ (NSArray *)appManagerLocales {
  NSMutableArray *locales = [NSMutableArray array];
  NSDictionary *localesMap = [self appManagerlocalesMap];
  for (NSString *key in localesMap) {
    [locales addObjectsFromArray:localesMap[key]];
  }
  return locales;
}

+ (NSDictionary *)appManagerlocalesMap {
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
