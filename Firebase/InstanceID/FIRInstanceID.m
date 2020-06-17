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

#import "FIRInstanceID.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

#import "FIRInstanceID+Private.h"
#import "FIRInstanceIDAuthService.h"
#import "FIRInstanceIDCheckinPreferences.h"
#import "FIRInstanceIDCombinedHandler.h"
#import "FIRInstanceIDConstants.h"
#import "FIRInstanceIDDefines.h"
#import "FIRInstanceIDLogger.h"
#import "FIRInstanceIDStore.h"
#import "FIRInstanceIDTokenInfo.h"
#import "FIRInstanceIDTokenManager.h"
#import "FIRInstanceIDUtilities.h"
#import "FIRInstanceIDVersionUtilities.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "GoogleUtilities/Environment/Private/GULAppEnvironmentUtil.h"
#import "GoogleUtilities/UserDefaults/Private/GULUserDefaults.h"
#import "NSError+FIRInstanceID.h"

// Public constants
NSString *const kFIRInstanceIDScopeFirebaseMessaging = @"fcm";

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
const NSNotificationName kFIRInstanceIDTokenRefreshNotification =
    @"com.firebase.iid.notif.refresh-token";
#else
NSString *const kFIRInstanceIDTokenRefreshNotification = @"com.firebase.iid.notif.refresh-token";
#endif  // defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

NSString *const kFIRInstanceIDInvalidNilHandlerError = @"Invalid nil handler.";

// Private constants
int64_t const kMaxRetryIntervalForDefaultTokenInSeconds = 20 * 60;  // 20 minutes
int64_t const kMinRetryIntervalForDefaultTokenInSeconds = 10;       // 10 seconds
// we retry only a max 5 times.
// TODO(chliangGoogle): If we still fail we should listen for the network change notification
// since GCM would have started Reachability. We only start retrying after we see a configuration
// change.
NSInteger const kMaxRetryCountForDefaultToken = 5;

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
static NSString *const kEntitlementsAPSEnvironmentKey = @"Entitlements.aps-environment";
#else
static NSString *const kEntitlementsAPSEnvironmentKey =
    @"Entitlements.com.apple.developer.aps-environment";
#endif
static NSString *const kAPSEnvironmentDevelopmentValue = @"development";
/// FIRMessaging selector that returns the current FIRMessaging auto init
/// enabled flag.
static NSString *const kFIRInstanceIDFCMSelectorAutoInitEnabled =
    @"isAutoInitEnabledWithUserDefaults:";

static NSString *const kFIRInstanceIDAPNSTokenType = @"APNSTokenType";
static NSString *const kFIRIIDAppReadyToConfigureSDKNotification =
    @"FIRAppReadyToConfigureSDKNotification";
static NSString *const kFIRIIDAppNameKey = @"FIRAppNameKey";
static NSString *const kFIRIIDErrorDomain = @"com.firebase.instanceid";
static NSString *const kFIRIIDServiceInstanceID = @"InstanceID";

/**
 *  The APNS token type for the app. If the token type is set to `UNKNOWN`
 *  InstanceID will implicitly try to figure out what the actual token type
 *  is from the provisioning profile.
 *  This must match FIRMessagingAPNSTokenType in FIRMessaging.h
 */
typedef NS_ENUM(NSInteger, FIRInstanceIDAPNSTokenType) {
  /// Unknown token type.
  FIRInstanceIDAPNSTokenTypeUnknown,
  /// Sandbox token type.
  FIRInstanceIDAPNSTokenTypeSandbox,
  /// Production token type.
  FIRInstanceIDAPNSTokenTypeProd,
} NS_SWIFT_NAME(InstanceIDAPNSTokenType);

@interface FIRInstanceIDResult ()
@property(nonatomic, readwrite, copy) NSString *instanceID;
@property(nonatomic, readwrite, copy) NSString *token;
@end

@interface FIRInstanceID ()

// FIRApp configuration objects.
@property(nonatomic, readwrite, copy) NSString *fcmSenderID;
@property(nonatomic, readwrite, copy) NSString *firebaseAppID;

// Raw APNS token data
@property(nonatomic, readwrite, strong) NSData *apnsTokenData;

@property(nonatomic, readwrite) FIRInstanceIDAPNSTokenType apnsTokenType;
// String-based, internal representation of APNS token
@property(nonatomic, readwrite, copy) NSString *APNSTupleString;
// Token fetched from the server automatically for the default app.
@property(nonatomic, readwrite, copy) NSString *defaultFCMToken;

@property(nonatomic, readwrite, strong) FIRInstanceIDTokenManager *tokenManager;
@property(nonatomic, readwrite, strong) FIRInstallations *installations;

// backoff and retry for default token
@property(nonatomic, readwrite, assign) NSInteger retryCountForDefaultToken;
@property(atomic, strong, nullable)
    FIRInstanceIDCombinedHandler<NSString *> *defaultTokenFetchHandler;

/// A cached value of FID. Should be used only for `-[FIRInstanceID appInstanceID:]`.
@property(atomic, copy, nullable) NSString *firebaseInstallationsID;

@end

// InstanceID doesn't provide any functionality to other components,
// so it provides a private, empty protocol that it conforms to and use it for registration.

@protocol FIRInstanceIDInstanceProvider
@end

@interface FIRInstanceID () <FIRInstanceIDInstanceProvider, FIRLibrary>
@end

@implementation FIRInstanceIDResult
- (id)copyWithZone:(NSZone *)zone {
  FIRInstanceIDResult *result = [[[self class] allocWithZone:zone] init];
  result.instanceID = self.instanceID;
  result.token = self.token;
  return result;
}
@end

@implementation FIRInstanceID

// File static to support InstanceID tests that call [FIRInstanceID instanceID] after
// [FIRInstanceID instanceIDForTests].
static FIRInstanceID *gInstanceID;

+ (instancetype)instanceID {
  // If the static instance was created, return it. This should only be set in tests and we should
  // eventually use proper dependency injection for a better test structure.
  if (gInstanceID != nil) {
    return gInstanceID;
  }
  FIRApp *defaultApp = [FIRApp defaultApp];  // Missing configure will be logged here.
  FIRInstanceID *instanceID =
      (FIRInstanceID *)FIR_COMPONENT(FIRInstanceIDInstanceProvider, defaultApp.container);
  return instanceID;
}

- (instancetype)initPrivately {
  self = [super init];
  if (self != nil) {
    // Use automatic detection of sandbox, unless otherwise set by developer
    _apnsTokenType = FIRInstanceIDAPNSTokenTypeUnknown;
  }
  return self;
}

+ (FIRInstanceID *)instanceIDForTests {
  gInstanceID = [[FIRInstanceID alloc] initPrivately];
  [gInstanceID start];
  return gInstanceID;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Tokens

- (NSString *)token {
  if (!self.fcmSenderID.length) {
    return nil;
  }

  NSString *cachedToken = [self cachedTokenIfAvailable];

  if (cachedToken) {
    return cachedToken;
  } else {
    // If we've never had a cached default token, we should fetch one because unrelatedly,
    // this request will help us determine whether the locally-generated Instance ID keypair is not
    // unique, and therefore generate a new one.
    [self defaultTokenWithHandler:nil];
    return nil;
  }
}

- (void)instanceIDWithHandler:(FIRInstanceIDResultHandler)handler {
  FIRInstanceID_WEAKIFY(self);
  [self getIDWithHandler:^(NSString *identity, NSError *error) {
    FIRInstanceID_STRONGIFY(self);
    // This is in main queue already
    if (error) {
      if (handler) {
        handler(nil, error);
      }
      return;
    }
    FIRInstanceIDResult *result = [[FIRInstanceIDResult alloc] init];
    result.instanceID = identity;
    NSString *cachedToken = [self cachedTokenIfAvailable];
    if (cachedToken) {
      if (handler) {
        result.token = cachedToken;
        handler(result, nil);
      }
      // If no handler, simply return since client has generated iid and token.
      return;
    }
    [self defaultTokenWithHandler:^(NSString *_Nullable token, NSError *_Nullable error) {
      if (handler) {
        if (error) {
          handler(nil, error);
          return;
        }
        result.token = token;
        handler(result, nil);
      }
    }];
  }];
}

- (NSString *)cachedTokenIfAvailable {
  FIRInstanceIDTokenInfo *cachedTokenInfo =
      [self.tokenManager cachedTokenInfoWithAuthorizedEntity:self.fcmSenderID
                                                       scope:kFIRInstanceIDDefaultTokenScope];
  return cachedTokenInfo.token;
}

- (void)setDefaultFCMToken:(NSString *)defaultFCMToken {
  // Sending this notification out will ensure that FIRMessaging and FIRInstanceID has the updated
  // default FCM token.
  // Only notify of token refresh if we have a new valid token that's different than before
  if ((defaultFCMToken.length && _defaultFCMToken.length &&
       ![defaultFCMToken isEqualToString:_defaultFCMToken]) ||
      defaultFCMToken.length != _defaultFCMToken.length) {
    NSNotification *tokenRefreshNotification =
        [NSNotification notificationWithName:kFIRInstanceIDTokenRefreshNotification
                                      object:[defaultFCMToken copy]];
    [[NSNotificationQueue defaultQueue] enqueueNotification:tokenRefreshNotification
                                               postingStyle:NSPostASAP];
  }

  _defaultFCMToken = defaultFCMToken;
}

- (void)tokenWithAuthorizedEntity:(NSString *)authorizedEntity
                            scope:(NSString *)scope
                          options:(NSDictionary *)options
                          handler:(FIRInstanceIDTokenHandler)handler {
  if (!handler) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID000,
                             kFIRInstanceIDInvalidNilHandlerError);
    return;
  }

  // Add internal options
  NSMutableDictionary *tokenOptions = [NSMutableDictionary dictionary];
  if (options.count) {
    [tokenOptions addEntriesFromDictionary:options];
  }

  NSString *APNSKey = kFIRInstanceIDTokenOptionsAPNSKey;
  NSString *serverTypeKey = kFIRInstanceIDTokenOptionsAPNSIsSandboxKey;
  if (tokenOptions[APNSKey] != nil && tokenOptions[serverTypeKey] == nil) {
    // APNS key was given, but server type is missing. Supply the server type with automatic
    // checking. This can happen when the token is requested from FCM, which does not include a
    // server type during its request.
    tokenOptions[serverTypeKey] = @([self isSandboxApp]);
  }
  if (self.firebaseAppID) {
    tokenOptions[kFIRInstanceIDTokenOptionsFirebaseAppIDKey] = self.firebaseAppID;
  }

  // comparing enums to ints directly throws a warning
  FIRInstanceIDErrorCode noError = INT_MAX;
  FIRInstanceIDErrorCode errorCode = noError;
  if (FIRInstanceIDIsValidGCMScope(scope) && !tokenOptions[APNSKey]) {
    errorCode = kFIRInstanceIDErrorCodeMissingAPNSToken;
  } else if (FIRInstanceIDIsValidGCMScope(scope) &&
             ![tokenOptions[APNSKey] isKindOfClass:[NSData class]]) {
    errorCode = kFIRInstanceIDErrorCodeInvalidRequest;
  } else if (![authorizedEntity length]) {
    errorCode = kFIRInstanceIDErrorCodeInvalidAuthorizedEntity;
  } else if (![scope length]) {
    errorCode = kFIRInstanceIDErrorCodeInvalidScope;
  } else if (!self.installations) {
    errorCode = kFIRInstanceIDErrorCodeInvalidStart;
  }

  FIRInstanceIDTokenHandler newHandler = ^(NSString *token, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      handler(token, error);
    });
  };

  if (errorCode != noError) {
    newHandler(nil, [NSError errorWithFIRInstanceIDErrorCode:errorCode]);
    return;
  }

  FIRInstanceID_WEAKIFY(self);
  FIRInstanceIDAuthService *authService = self.tokenManager.authService;
  [authService fetchCheckinInfoWithHandler:^(FIRInstanceIDCheckinPreferences *preferences,
                                             NSError *error) {
    FIRInstanceID_STRONGIFY(self);
    if (error) {
      newHandler(nil, error);
      return;
    }

    FIRInstanceID_WEAKIFY(self);
    [self.installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                       NSError *_Nullable error) {
      FIRInstanceID_STRONGIFY(self);

      if (error) {
        NSError *newError =
            [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeInvalidKeyPair];
        newHandler(nil, newError);

      } else {
        FIRInstanceIDTokenInfo *cachedTokenInfo =
            [self.tokenManager cachedTokenInfoWithAuthorizedEntity:authorizedEntity scope:scope];
        if (cachedTokenInfo) {
          FIRInstanceIDAPNSInfo *optionsAPNSInfo =
              [[FIRInstanceIDAPNSInfo alloc] initWithTokenOptionsDictionary:tokenOptions];
          // Check if APNS Info is changed
          if ((!cachedTokenInfo.APNSInfo && !optionsAPNSInfo) ||
              [cachedTokenInfo.APNSInfo isEqualToAPNSInfo:optionsAPNSInfo]) {
            // check if token is fresh
            if ([cachedTokenInfo isFreshWithIID:identifier]) {
              newHandler(cachedTokenInfo.token, nil);
              return;
            }
          }
        }
        [self.tokenManager fetchNewTokenWithAuthorizedEntity:[authorizedEntity copy]
                                                       scope:[scope copy]
                                                  instanceID:identifier
                                                     options:tokenOptions
                                                     handler:newHandler];
      }
    }];
  }];
}

- (void)deleteTokenWithAuthorizedEntity:(NSString *)authorizedEntity
                                  scope:(NSString *)scope
                                handler:(FIRInstanceIDDeleteTokenHandler)handler {
  if (!handler) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID001,
                             kFIRInstanceIDInvalidNilHandlerError);
    return;
  }

  // comparing enums to ints directly throws a warning
  FIRInstanceIDErrorCode noError = INT_MAX;
  FIRInstanceIDErrorCode errorCode = noError;

  if (![authorizedEntity length]) {
    errorCode = kFIRInstanceIDErrorCodeInvalidAuthorizedEntity;
  } else if (![scope length]) {
    errorCode = kFIRInstanceIDErrorCodeInvalidScope;
  } else if (!self.installations) {
    errorCode = kFIRInstanceIDErrorCodeInvalidStart;
  }

  FIRInstanceIDDeleteTokenHandler newHandler = ^(NSError *error) {
    // If a default token is deleted successfully, reset the defaultFCMToken too.
    if (!error && [authorizedEntity isEqualToString:self.fcmSenderID] &&
        [scope isEqualToString:kFIRInstanceIDDefaultTokenScope]) {
      self.defaultFCMToken = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      handler(error);
    });
  };

  if (errorCode != noError) {
    newHandler([NSError errorWithFIRInstanceIDErrorCode:errorCode]);
    return;
  }

  FIRInstanceID_WEAKIFY(self);
  FIRInstanceIDAuthService *authService = self.tokenManager.authService;
  [authService
      fetchCheckinInfoWithHandler:^(FIRInstanceIDCheckinPreferences *preferences, NSError *error) {
        FIRInstanceID_STRONGIFY(self);
        if (error) {
          newHandler(error);
          return;
        }

        FIRInstanceID_WEAKIFY(self);
        [self.installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                           NSError *_Nullable error) {
          FIRInstanceID_STRONGIFY(self);
          if (error) {
            NSError *newError =
                [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeInvalidKeyPair];
            newHandler(newError);

          } else {
            [self.tokenManager deleteTokenWithAuthorizedEntity:authorizedEntity
                                                         scope:scope
                                                    instanceID:identifier
                                                       handler:newHandler];
          }
        }];
      }];
}

#pragma mark - Identity

- (void)getIDWithHandler:(FIRInstanceIDHandler)handler {
  if (!handler) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID003,
                             kFIRInstanceIDInvalidNilHandlerError);
    return;
  }

  FIRInstanceID_WEAKIFY(self);
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        FIRInstanceID_STRONGIFY(self);
        // When getID is explicitly called, trigger getToken to make sure token always exists.
        // This is to avoid ID conflict (ID is not checked for conflict until we generate a token)
        if (identifier) {
          [self token];
        }
        handler(identifier, error);
      }];
}

- (void)deleteIDWithHandler:(FIRInstanceIDDeleteHandler)handler {
  if (!handler) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID004,
                             kFIRInstanceIDInvalidNilHandlerError);
    return;
  }

  void (^callHandlerOnMainThread)(NSError *) = ^(NSError *error) {
    if ([NSThread isMainThread]) {
      handler(error);
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      handler(error);
    });
  };

  if (!self.installations) {
    FIRInstanceIDErrorCode error = kFIRInstanceIDErrorCodeInvalidStart;
    callHandlerOnMainThread([NSError errorWithFIRInstanceIDErrorCode:error]);
    return;
  }

  FIRInstanceID_WEAKIFY(self);
  void (^deleteTokensHandler)(NSError *) = ^void(NSError *error) {
    FIRInstanceID_STRONGIFY(self);
    if (error) {
      callHandlerOnMainThread(error);
      return;
    }
    [self deleteIdentityWithHandler:^(NSError *error) {
      callHandlerOnMainThread(error);
    }];
  };

  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        FIRInstanceID_STRONGIFY(self);
        if (error) {
          NSError *newError =
              [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeInvalidKeyPair];
          callHandlerOnMainThread(newError);
        } else {
          [self.tokenManager deleteAllTokensWithInstanceID:identifier handler:deleteTokensHandler];
        }
      }];
}

- (void)notifyIdentityReset {
  [self deleteIdentityWithHandler:nil];
}

// Delete all the local cache checkin, IID and token.
- (void)deleteIdentityWithHandler:(FIRInstanceIDDeleteHandler)handler {
  // Delete tokens.
  [self.tokenManager deleteAllTokensLocallyWithHandler:^(NSError *deleteTokenError) {
    // Reset FCM token.
    self.defaultFCMToken = nil;
    if (deleteTokenError) {
      if (handler) {
        handler(deleteTokenError);
      }
      return;
    }

    // Delete Instance ID.
    [self.installations deleteWithCompletion:^(NSError *_Nullable error) {
      if (error) {
        if (handler) {
          handler(error);
        }
        return;
      }

      [self.tokenManager.authService resetCheckinWithHandler:^(NSError *error) {
        if (error) {
          if (handler) {
            handler(error);
          }
          return;
        }
        // Only request new token if FCM auto initialization is
        // enabled.
        if ([self isFCMAutoInitEnabled]) {
          // Deletion succeeds! Requesting new checkin, IID and token.
          // TODO(chliangGoogle) see if dispatch_after is necessary
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                         dispatch_get_main_queue(), ^{
                           [self defaultTokenWithHandler:nil];
                         });
        }
        if (handler) {
          handler(nil);
        }
      }];
    }];
  }];
}

#pragma mark - Checkin

- (BOOL)tryToLoadValidCheckinInfo {
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [self.tokenManager.authService checkinPreferences];
  return [checkinPreferences hasValidCheckinInfo];
}

- (NSString *)deviceAuthID {
  return [self.tokenManager.authService checkinPreferences].deviceID;
}

- (NSString *)secretToken {
  return [self.tokenManager.authService checkinPreferences].secretToken;
}

- (NSString *)versionInfo {
  return [self.tokenManager.authService checkinPreferences].versionInfo;
}

#pragma mark - Config

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                         withName:@"fire-iid"
                      withVersion:FIRInstanceIDCurrentLibraryVersion()];
}

+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    // InstanceID only works with the default app.
    if (!container.app.isDefaultApp) {
      // Only configure for the default FIRApp.
      FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeFIRApp002,
                               @"Firebase Instance ID only works with the default app.");
      return nil;
    }

    // Ensure it's cached so it returns the same instance every time instanceID is called.
    *isCacheable = YES;
    FIRInstanceID *instanceID = [[FIRInstanceID alloc] initPrivately];
    [instanceID start];
    [instanceID configureInstanceIDWithOptions:container.app.options];
    return instanceID;
  };
  FIRComponent *instanceIDProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRInstanceIDInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingEagerInDefaultApp
                             dependencies:@[]
                            creationBlock:creationBlock];
  return @[ instanceIDProvider ];
}

- (void)configureInstanceIDWithOptions:(FIROptions *)options {
  NSString *GCMSenderID = options.GCMSenderID;
  if (!GCMSenderID.length) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeFIRApp000,
                             @"Firebase not set up correctly, nil or empty senderID.");
    [NSException raise:kFIRIIDErrorDomain
                format:@"Could not configure Firebase InstanceID. GCMSenderID must not be nil or "
                       @"empty."];
  }

  self.fcmSenderID = GCMSenderID;
  self.firebaseAppID = options.googleAppID;

  [self updateFirebaseInstallationID];

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

// This is used to start any operations when we receive FirebaseSDK setup notification
// from FIRCore.
- (void)didCompleteConfigure {
  NSString *cachedToken = [self cachedTokenIfAvailable];
  // When there is a cached token, do the token refresh.
  if (cachedToken) {
    // Clean up expired tokens by checking the token refresh policy.
    [self.installations
        installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
          if ([self.tokenManager checkTokenRefreshPolicyWithIID:identifier]) {
            // Default token is expired, fetch default token from server.
            [self defaultTokenWithHandler:nil];
          }
          // Notify FCM with the default token.
          self.defaultFCMToken = [self token];
        }];
  } else if ([self isFCMAutoInitEnabled]) {
    // When there is no cached token, must check auto init is enabled.
    // If it's disabled, don't initiate token generation/refresh.
    // If no cache token and auto init is enabled, fetch a token from server.
    [self defaultTokenWithHandler:nil];
    // Notify FCM with the default token.
    self.defaultFCMToken = [self token];
  }
  // ONLY checkin when auto data collection is turned on.
  if ([self isFCMAutoInitEnabled]) {
    [self.tokenManager.authService scheduleCheckin:YES];
  }
}

- (BOOL)isFCMAutoInitEnabled {
  Class messagingClass = NSClassFromString(kFIRInstanceIDFCMSDKClassString);
  // Firebase Messaging is not installed, auto init should be disabled since it's for FCM.
  if (!messagingClass) {
    return NO;
  }

  // Messaging doesn't have the class method, auto init should be enabled since FCM exists.
  SEL autoInitSelector = NSSelectorFromString(kFIRInstanceIDFCMSelectorAutoInitEnabled);
  if (![messagingClass respondsToSelector:autoInitSelector]) {
    return YES;
  }

  // Get the autoInitEnabled class method.
  IMP isAutoInitEnabledIMP = [messagingClass methodForSelector:autoInitSelector];
  BOOL(*isAutoInitEnabled)
  (Class, SEL, GULUserDefaults *) = (BOOL(*)(id, SEL, GULUserDefaults *))isAutoInitEnabledIMP;

  // Check FCM's isAutoInitEnabled property.
  return isAutoInitEnabled(messagingClass, autoInitSelector,
                           [GULUserDefaults standardUserDefaults]);
}

// Actually makes InstanceID instantiate both the IID and Token-related subsystems.
- (void)start {
  if (![FIRInstanceIDStore hasSubDirectory:kFIRInstanceIDSubDirectoryName]) {
    [FIRInstanceIDStore createSubDirectory:kFIRInstanceIDSubDirectoryName];
  }

  [self setupTokenManager];
  self.installations = [FIRInstallations installations];
  [self setupNotificationListeners];
}

// Creates the token manager, which is used for fetching, caching, and retrieving tokens.
- (void)setupTokenManager {
  self.tokenManager = [[FIRInstanceIDTokenManager alloc] init];
}

- (void)setupNotificationListeners {
  // To prevent double notifications remove observer from all events during setup.
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver:self];
  [center addObserver:self
             selector:@selector(notifyIdentityReset)
                 name:kFIRInstanceIDIdentityInvalidatedNotification
               object:nil];
  [center addObserver:self
             selector:@selector(notifyAPNSTokenIsSet:)
                 name:kFIRInstanceIDAPNSTokenNotification
               object:nil];
  [self observeFirebaseInstallationIDChanges];
}

#pragma mark - Private Helpers
/// Maximum retry count to fetch the default token.
+ (int64_t)maxRetryCountForDefaultToken {
  return kMaxRetryCountForDefaultToken;
}

/// Minimum interval in seconds between retries to fetch the default token.
+ (int64_t)minIntervalForDefaultTokenRetry {
  return kMinRetryIntervalForDefaultTokenInSeconds;
}

/// Maximum retry interval between retries to fetch default token.
+ (int64_t)maxRetryIntervalForDefaultTokenInSeconds {
  return kMaxRetryIntervalForDefaultTokenInSeconds;
}

- (NSInteger)retryIntervalToFetchDefaultToken {
  if (self.retryCountForDefaultToken >= [[self class] maxRetryCountForDefaultToken]) {
    return (NSInteger)[[self class] maxRetryIntervalForDefaultTokenInSeconds];
  }
  // exponential backoff with a fixed initial retry time
  // 11s, 22s, 44s, 88s ...
  int64_t minInterval = [[self class] minIntervalForDefaultTokenRetry];
  return (NSInteger)MIN(
      (1 << self.retryCountForDefaultToken) + minInterval * self.retryCountForDefaultToken,
      kMaxRetryIntervalForDefaultTokenInSeconds);
}

- (void)defaultTokenWithHandler:(nullable FIRInstanceIDTokenHandler)aHandler {
  [self defaultTokenWithRetry:NO handler:aHandler];
}

/**
 * @param retry Indicates if the method is called to perform a retry after a failed attempt.
 * If `YES`, then actual token request will be performed even if `self.defaultTokenFetchHandler !=
 * nil`
 */
- (void)defaultTokenWithRetry:(BOOL)retry handler:(nullable FIRInstanceIDTokenHandler)aHandler {
  BOOL shouldPerformRequest = retry || self.defaultTokenFetchHandler == nil;

  if (!self.defaultTokenFetchHandler) {
    self.defaultTokenFetchHandler = [[FIRInstanceIDCombinedHandler<NSString *> alloc] init];
  }

  if (aHandler) {
    [self.defaultTokenFetchHandler addHandler:aHandler];
  }

  if (!shouldPerformRequest) {
    return;
  }

  NSDictionary *instanceIDOptions = @{};
  BOOL hasFirebaseMessaging = NSClassFromString(kFIRInstanceIDFCMSDKClassString) != nil;
  if (hasFirebaseMessaging && self.apnsTokenData) {
    BOOL isSandboxApp = (self.apnsTokenType == FIRInstanceIDAPNSTokenTypeSandbox);
    if (self.apnsTokenType == FIRInstanceIDAPNSTokenTypeUnknown) {
      isSandboxApp = [self isSandboxApp];
    }
    instanceIDOptions = @{
      kFIRInstanceIDTokenOptionsAPNSKey : self.apnsTokenData,
      kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(isSandboxApp),
    };
  }

  FIRInstanceID_WEAKIFY(self);
  FIRInstanceIDTokenHandler newHandler = ^void(NSString *token, NSError *error) {
    FIRInstanceID_STRONGIFY(self);

    if (error) {
      FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID009,
                               @"Failed to fetch default token %@", error);

      // This notification can be sent multiple times since we can't guarantee success at any point
      // of time.
      NSNotification *tokenFetchFailNotification =
          [NSNotification notificationWithName:kFIRInstanceIDDefaultGCMTokenFailNotification
                                        object:[error copy]];
      [[NSNotificationQueue defaultQueue] enqueueNotification:tokenFetchFailNotification
                                                 postingStyle:NSPostASAP];

      self.retryCountForDefaultToken = (NSInteger)MIN(self.retryCountForDefaultToken + 1,
                                                      [[self class] maxRetryCountForDefaultToken]);

      // Do not retry beyond the maximum limit.
      if (self.retryCountForDefaultToken < [[self class] maxRetryCountForDefaultToken]) {
        NSInteger retryInterval = [self retryIntervalToFetchDefaultToken];
        [self retryGetDefaultTokenAfter:retryInterval];
      } else {
        FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID007,
                                 @"Failed to retrieve the default FCM token after %ld retries",
                                 (long)self.retryCountForDefaultToken);
        [self performDefaultTokenHandlerWithToken:nil error:error];
      }
    } else {
      // If somebody updated IID with APNS token while our initial request did not have it
      // set we need to update it on the server.
      NSData *deviceTokenInRequest = instanceIDOptions[kFIRInstanceIDTokenOptionsAPNSKey];
      BOOL isSandboxInRequest =
          [instanceIDOptions[kFIRInstanceIDTokenOptionsAPNSIsSandboxKey] boolValue];
      // Note that APNSTupleStringInRequest will be nil if deviceTokenInRequest is nil
      NSString *APNSTupleStringInRequest = FIRInstanceIDAPNSTupleStringForTokenAndServerType(
          deviceTokenInRequest, isSandboxInRequest);
      // If the APNs value either remained nil, or was the same non-nil value, the APNs value
      // did not change.
      BOOL APNSRemainedSameDuringFetch =
          (self.APNSTupleString == nil && APNSTupleStringInRequest == nil) ||
          ([self.APNSTupleString isEqualToString:APNSTupleStringInRequest]);
      if (!APNSRemainedSameDuringFetch && hasFirebaseMessaging) {
        // APNs value did change mid-fetch, so the token should be re-fetched with the current APNs
        // value.
        [self retryGetDefaultTokenAfter:0];
        FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeRefetchingTokenForAPNS,
                                 @"Received APNS token while fetching default token. "
                                 @"Refetching default token.");
        // Do not notify and handle completion handler since this is a retry.
        // Simply return.
        return;
      } else {
        FIRInstanceIDLoggerInfo(kFIRInstanceIDMessageCodeInstanceID010,
                                @"Successfully fetched default token.");
      }
      // Post the required notifications if somebody is waiting.
      FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeInstanceID008, @"Got default token %@",
                               token);
      // Update default FCM token, this method also triggers sending notification if token has
      // changed.
      self.defaultFCMToken = token;

      [self performDefaultTokenHandlerWithToken:token error:nil];
    }
  };

  [self tokenWithAuthorizedEntity:self.fcmSenderID
                            scope:kFIRInstanceIDDefaultTokenScope
                          options:instanceIDOptions
                          handler:newHandler];
}

/**
 *
 */
- (void)performDefaultTokenHandlerWithToken:(NSString *)token error:(NSError *)error {
  if (!self.defaultTokenFetchHandler) {
    return;
  }

  [self.defaultTokenFetchHandler combinedHandler](token, error);
  self.defaultTokenFetchHandler = nil;
}

- (void)retryGetDefaultTokenAfter:(NSTimeInterval)retryInterval {
  FIRInstanceID_WEAKIFY(self);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(retryInterval * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   FIRInstanceID_STRONGIFY(self);
                   // Pass nil: no new handlers to be added, currently existing handlers
                   // will be called
                   [self defaultTokenWithRetry:YES handler:nil];
                 });
}

#pragma mark - APNS Token
// This should only be triggered from FCM.
- (void)notifyAPNSTokenIsSet:(NSNotification *)notification {
  NSData *token = notification.object;
  if (!token || ![token isKindOfClass:[NSData class]]) {
    FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeInternal002, @"Invalid APNS token type %@",
                             NSStringFromClass([notification.object class]));
    return;
  }
  NSInteger type = [notification.userInfo[kFIRInstanceIDAPNSTokenType] integerValue];

  // The APNS token is being added, or has changed (rare)
  if ([self.apnsTokenData isEqualToData:token]) {
    FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeInstanceID011,
                             @"Trying to reset APNS token to the same value. Will return");
    return;
  }
  // Use this token type for when we have to automatically fetch tokens in the future
  self.apnsTokenType = type;
  BOOL isSandboxApp = (type == FIRInstanceIDAPNSTokenTypeSandbox);
  if (self.apnsTokenType == FIRInstanceIDAPNSTokenTypeUnknown) {
    isSandboxApp = [self isSandboxApp];
  }
  self.apnsTokenData = [token copy];
  self.APNSTupleString = FIRInstanceIDAPNSTupleStringForTokenAndServerType(token, isSandboxApp);

  // Pro-actively invalidate the default token, if the APNs change makes it
  // invalid. Previously, we invalidated just before fetching the token.
  NSArray<FIRInstanceIDTokenInfo *> *invalidatedTokens =
      [self.tokenManager updateTokensToAPNSDeviceToken:self.apnsTokenData isSandbox:isSandboxApp];

  // Re-fetch any invalidated tokens automatically, this time with the current APNs token, so that
  // they are up-to-date.
  if (invalidatedTokens.count > 0) {
    FIRInstanceID_WEAKIFY(self);

    [self.installations
        installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
          FIRInstanceID_STRONGIFY(self);
          if (self == nil) {
            FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID017,
                                     @"Instance ID shut down during token reset. Aborting");
            return;
          }
          if (self.apnsTokenData == nil) {
            FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID018,
                                     @"apnsTokenData was set to nil during token reset. Aborting");
            return;
          }

          NSMutableDictionary *tokenOptions = [@{
            kFIRInstanceIDTokenOptionsAPNSKey : self.apnsTokenData,
            kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(isSandboxApp)
          } mutableCopy];
          if (self.firebaseAppID) {
            tokenOptions[kFIRInstanceIDTokenOptionsFirebaseAppIDKey] = self.firebaseAppID;
          }

          for (FIRInstanceIDTokenInfo *tokenInfo in invalidatedTokens) {
            if ([tokenInfo.token isEqualToString:self.defaultFCMToken]) {
              // We will perform a special fetch for the default FCM token, so that the delegate
              // methods are called. For all others, we will do an internal re-fetch.
              [self defaultTokenWithHandler:nil];
            } else {
              [self.tokenManager fetchNewTokenWithAuthorizedEntity:tokenInfo.authorizedEntity
                                                             scope:tokenInfo.scope
                                                        instanceID:identifier
                                                           options:tokenOptions
                                                           handler:^(NSString *_Nullable token,
                                                                     NSError *_Nullable error){

                                                           }];
            }
          }
        }];
  }
}

- (BOOL)isSandboxApp {
  static BOOL isSandboxApp = YES;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    isSandboxApp = ![self isProductionApp];
  });
  return isSandboxApp;
}

- (BOOL)isProductionApp {
  const BOOL defaultAppTypeProd = YES;

  NSError *error = nil;
  if ([GULAppEnvironmentUtil isSimulator]) {
    [self logAPNSConfigurationError:@"Running InstanceID on a simulator doesn't have APNS. "
                                    @"Use prod profile by default."];
    return defaultAppTypeProd;
  }

  if ([GULAppEnvironmentUtil isFromAppStore]) {
    // Apps distributed via AppStore or TestFlight use the Production APNS certificates.
    return defaultAppTypeProd;
  }
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  NSString *path = [[[[NSBundle mainBundle] resourcePath] stringByDeletingLastPathComponent]
      stringByAppendingPathComponent:@"embedded.provisionprofile"];
#elif TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
  NSString *path = [[[NSBundle mainBundle] bundlePath]
      stringByAppendingPathComponent:@"embedded.mobileprovision"];
#endif

  if ([GULAppEnvironmentUtil isAppStoreReceiptSandbox] && !path.length) {
    // Distributed via TestFlight
    return defaultAppTypeProd;
  }

  NSMutableData *profileData = [NSMutableData dataWithContentsOfFile:path options:0 error:&error];

  if (!profileData.length || error) {
    NSString *errorString =
        [NSString stringWithFormat:@"Error while reading embedded mobileprovision %@", error];
    [self logAPNSConfigurationError:errorString];
    return defaultAppTypeProd;
  }

  // The "embedded.mobileprovision" sometimes contains characters with value 0, which signals the
  // end of a c-string and halts the ASCII parser, or with value > 127, which violates strict 7-bit
  // ASCII. Replace any 0s or invalid characters in the input.
  uint8_t *profileBytes = (uint8_t *)profileData.bytes;
  for (int i = 0; i < profileData.length; i++) {
    uint8_t currentByte = profileBytes[i];
    if (!currentByte || currentByte > 127) {
      profileBytes[i] = '.';
    }
  }

  NSString *embeddedProfile = [[NSString alloc] initWithBytesNoCopy:profileBytes
                                                             length:profileData.length
                                                           encoding:NSASCIIStringEncoding
                                                       freeWhenDone:NO];

  if (error || !embeddedProfile.length) {
    NSString *errorString =
        [NSString stringWithFormat:@"Error while reading embedded mobileprovision %@", error];
    [self logAPNSConfigurationError:errorString];
    return defaultAppTypeProd;
  }

  NSScanner *scanner = [NSScanner scannerWithString:embeddedProfile];
  NSString *plistContents;
  if ([scanner scanUpToString:@"<plist" intoString:nil]) {
    if ([scanner scanUpToString:@"</plist>" intoString:&plistContents]) {
      plistContents = [plistContents stringByAppendingString:@"</plist>"];
    }
  }

  if (!plistContents.length) {
    return defaultAppTypeProd;
  }

  NSData *data = [plistContents dataUsingEncoding:NSUTF8StringEncoding];
  if (!data.length) {
    [self logAPNSConfigurationError:@"Couldn't read plist fetched from embedded mobileprovision"];
    return defaultAppTypeProd;
  }

  NSError *plistMapError;
  id plistData = [NSPropertyListSerialization propertyListWithData:data
                                                           options:NSPropertyListImmutable
                                                            format:nil
                                                             error:&plistMapError];
  if (plistMapError || ![plistData isKindOfClass:[NSDictionary class]]) {
    NSString *errorString =
        [NSString stringWithFormat:@"Error while converting assumed plist to dict %@",
                                   plistMapError.localizedDescription];
    [self logAPNSConfigurationError:errorString];
    return defaultAppTypeProd;
  }
  NSDictionary *plistMap = (NSDictionary *)plistData;

  if ([plistMap valueForKeyPath:@"ProvisionedDevices"]) {
    FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeInstanceID012,
                             @"Provisioning profile has specifically provisioned devices, "
                             @"most likely a Dev profile.");
  }

  NSString *apsEnvironment = [plistMap valueForKeyPath:kEntitlementsAPSEnvironmentKey];
  NSString *debugString __unused =
      [NSString stringWithFormat:@"APNS Environment in profile: %@", apsEnvironment];
  FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeInstanceID013, @"%@", debugString);

  // No aps-environment in the profile.
  if (!apsEnvironment.length) {
    [self logAPNSConfigurationError:@"No aps-environment set. If testing on a device APNS is not "
                                    @"correctly configured. Please recheck your provisioning "
                                    @"profiles. If testing on a simulator this is fine since APNS "
                                    @"doesn't work on the simulator."];
    return defaultAppTypeProd;
  }

  if ([apsEnvironment isEqualToString:kAPSEnvironmentDevelopmentValue]) {
    return NO;
  }

  return defaultAppTypeProd;
}

/// Log error messages only when Messaging exists in the pod.
- (void)logAPNSConfigurationError:(NSString *)errorString {
  BOOL hasFirebaseMessaging = NSClassFromString(kFIRInstanceIDFCMSDKClassString) != nil;
  if (hasFirebaseMessaging) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeInstanceID014, @"%@", errorString);
  } else {
    FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeInstanceID015, @"%@", errorString);
  }
}

#pragma mark - Sync InstanceID

- (void)updateFirebaseInstallationID {
  FIRInstanceID_WEAKIFY(self);
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable installationID, NSError *_Nullable error) {
        FIRInstanceID_STRONGIFY(self);
        self.firebaseInstallationsID = installationID;
      }];
}

- (void)installationIDDidChangeNotificationReceived:(NSNotification *)notification {
  NSString *installationAppID =
      notification.userInfo[kFIRInstallationIDDidChangeNotificationAppNameKey];
  if ([installationAppID isKindOfClass:[NSString class]] &&
      [installationAppID isEqual:self.firebaseAppID]) {
    [self updateFirebaseInstallationID];
  }
}

- (void)observeFirebaseInstallationIDChanges {
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:FIRInstallationIDDidChangeNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(installationIDDidChangeNotificationReceived:)
             name:FIRInstallationIDDidChangeNotification
           object:nil];
}

@end
