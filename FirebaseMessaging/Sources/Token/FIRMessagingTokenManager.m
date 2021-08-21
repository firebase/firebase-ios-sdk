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

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthKeychain.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenDeleteOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenFetchOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenStore.h"

@interface FIRMessagingTokenManager () {
  FIRMessagingTokenStore *_tokenStore;
  NSString *_defaultFCMToken;
}

@property(nonatomic, readwrite, strong) FIRMessagingCheckinStore *checkinStore;
@property(nonatomic, readwrite, strong) FIRMessagingAuthService *authService;
@property(nonatomic, readonly, strong) NSOperationQueue *tokenOperations;

@property(nonatomic, readwrite, strong) FIRMessagingAPNSInfo *currentAPNSInfo;
@property(nonatomic, readwrite) FIRInstallations *installations;

@end

@implementation FIRMessagingTokenManager

- (instancetype)init {
  self = [super init];
  if (self) {
    _tokenStore = [[FIRMessagingTokenStore alloc] init];
    _authService = [[FIRMessagingAuthService alloc] init];
    [self resetCredentialsIfNeeded];
    [self configureTokenOperations];
    _installations = [FIRInstallations installations];
  }
  return self;
}

- (void)dealloc {
  [self stopAllTokenOperations];
}

- (NSString *)tokenAndRequestIfNotExist {
  if (!self.fcmSenderID.length) {
    return nil;
  }

  if (_defaultFCMToken.length) {
    return _defaultFCMToken;
  }

  FIRMessagingTokenInfo *cachedTokenInfo =
      [self cachedTokenInfoWithAuthorizedEntity:self.fcmSenderID
                                          scope:kFIRMessagingDefaultTokenScope];
  NSString *cachedToken = cachedTokenInfo.token;

  if (cachedToken) {
    return cachedToken;
  } else {
    [self tokenWithAuthorizedEntity:self.fcmSenderID
                              scope:kFIRMessagingDefaultTokenScope
                            options:[self tokenOptions]
                            handler:^(NSString *_Nullable FCMToken, NSError *_Nullable error){

                            }];
    return nil;
  }
}

- (NSString *)defaultFCMToken {
  return _defaultFCMToken;
}

- (void)postTokenRefreshNotificationWithDefaultFCMToken:(NSString *)defaultFCMToken {
  // Should always trigger the token refresh notification when the delegate method is called
  // No need to check if the token has changed, it's handled in the notification receiver.
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center postNotificationName:kFIRMessagingRegistrationTokenRefreshNotification
                        object:defaultFCMToken];
}

- (void)saveDefaultTokenInfoInKeychain:(NSString *)defaultFcmToken {
  if ([self hasTokenChangedFromOldToken:_defaultFCMToken toNewToken:defaultFcmToken]) {
    _defaultFCMToken = [defaultFcmToken copy];
    FIRMessagingTokenInfo *tokenInfo =
        [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:_fcmSenderID
                                                          scope:kFIRMessagingDefaultTokenScope
                                                          token:defaultFcmToken
                                                     appVersion:FIRMessagingCurrentAppVersion()
                                                  firebaseAppID:_firebaseAppID];
    tokenInfo.APNSInfo =
        [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:[self tokenOptions]];

    [self->_tokenStore saveTokenInfoInCache:tokenInfo];
  }
}

- (BOOL)hasTokenChangedFromOldToken:(NSString *)oldToken toNewToken:(NSString *)newToken {
  return oldToken.length != newToken.length ||
         (oldToken.length && newToken.length && ![oldToken isEqualToString:newToken]);
}

- (NSDictionary *)tokenOptions {
  NSDictionary *instanceIDOptions = @{};
  NSData *apnsTokenData = self.currentAPNSInfo.deviceToken;
  if (apnsTokenData) {
    instanceIDOptions = @{
      kFIRMessagingTokenOptionsAPNSKey : apnsTokenData,
      kFIRMessagingTokenOptionsAPNSIsSandboxKey : @(self.currentAPNSInfo.isSandbox),
    };
  }

  return instanceIDOptions;
}

- (NSString *)deviceAuthID {
  return [_authService checkinPreferences].deviceID;
}

- (NSString *)secretToken {
  return [_authService checkinPreferences].secretToken;
}

- (NSString *)versionInfo {
  return [_authService checkinPreferences].versionInfo;
}

- (void)configureTokenOperations {
  _tokenOperations = [[NSOperationQueue alloc] init];
  _tokenOperations.name = @"com.google.iid-token-operations";
  // For now, restrict the operations to be serial, because in some cases (like if the
  // authorized entity and scope are the same), order matters.
  // If we have to deal with several different token requests simultaneously, it would be a good
  // idea to add some better intelligence around this (performing unrelated token operations
  // simultaneously, etc.).
  _tokenOperations.maxConcurrentOperationCount = 1;
  if ([_tokenOperations respondsToSelector:@selector(qualityOfService)]) {
    _tokenOperations.qualityOfService = NSOperationQualityOfServiceUtility;
  }
}

- (void)tokenWithAuthorizedEntity:(NSString *)authorizedEntity
                            scope:(NSString *)scope
                          options:(NSDictionary *)options
                          handler:(FIRMessagingFCMTokenFetchCompletion)handler {
  if (!handler) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID000, @"Invalid nil handler");
    return;
  }

  // Add internal options
  NSMutableDictionary *tokenOptions = [NSMutableDictionary dictionary];
  if (options.count) {
    [tokenOptions addEntriesFromDictionary:options];
  }

  if (tokenOptions[kFIRMessagingTokenOptionsAPNSKey] != nil &&
      tokenOptions[kFIRMessagingTokenOptionsAPNSIsSandboxKey] == nil) {
    // APNS key was given, but server type is missing. Supply the server type with automatic
    // checking. This can happen when the token is requested from FCM, which does not include a
    // server type during its request.
    tokenOptions[kFIRMessagingTokenOptionsAPNSIsSandboxKey] = @(FIRMessagingIsSandboxApp());
  }
  if (self.firebaseAppID) {
    tokenOptions[kFIRMessagingTokenOptionsFirebaseAppIDKey] = self.firebaseAppID;
  }

  // comparing enums to ints directly throws a warning
  FIRMessagingErrorCode noError = INT_MAX;
  FIRMessagingErrorCode errorCode = noError;
  if (![authorizedEntity length]) {
    errorCode = kFIRMessagingErrorCodeMissingAuthorizedEntity;
  } else if (![scope length]) {
    errorCode = kFIRMessagingErrorCodeMissingScope;
  } else if (!self.installations) {
    errorCode = kFIRMessagingErrorCodeMissingFid;
  }

  FIRMessagingFCMTokenFetchCompletion newHandler = ^(NSString *token, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      handler(token, error);
    });
  };

  if (errorCode != noError) {
    newHandler(
        nil,
        [NSError messagingErrorWithCode:errorCode
                          failureReason:@"Failed to send token request, missing critical info."]);
    return;
  }

  FIRMessaging_WEAKIFY(self);
  [_authService
      fetchCheckinInfoWithHandler:^(FIRMessagingCheckinPreferences *preferences, NSError *error) {
        FIRMessaging_STRONGIFY(self);
        if (error) {
          newHandler(nil, error);
          return;
        }

        FIRMessaging_WEAKIFY(self);
        [self->_installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                             NSError *_Nullable error) {
          FIRMessaging_STRONGIFY(self);

          if (error) {
            newHandler(nil, error);
          } else {
            FIRMessagingTokenInfo *cachedTokenInfo =
                [self cachedTokenInfoWithAuthorizedEntity:authorizedEntity scope:scope];
            if (cachedTokenInfo) {
              FIRMessagingAPNSInfo *optionsAPNSInfo =
                  [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:tokenOptions];
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
            [self fetchNewTokenWithAuthorizedEntity:[authorizedEntity copy]
                                              scope:[scope copy]
                                         instanceID:identifier
                                            options:tokenOptions
                                            handler:newHandler];
          }
        }];
      }];
}

- (void)fetchNewTokenWithAuthorizedEntity:(NSString *)authorizedEntity
                                    scope:(NSString *)scope
                               instanceID:(NSString *)instanceID
                                  options:(NSDictionary *)options
                                  handler:(FIRMessagingFCMTokenFetchCompletion)handler {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManager000,
                          @"Fetch new token for authorizedEntity: %@, scope: %@", authorizedEntity,
                          scope);
  FIRMessagingTokenFetchOperation *operation =
      [self createFetchOperationWithAuthorizedEntity:authorizedEntity
                                               scope:scope
                                             options:options
                                          instanceID:instanceID];
  FIRMessaging_WEAKIFY(self);
  FIRMessagingTokenOperationCompletion completion =
      ^(FIRMessagingTokenOperationResult result, NSString *_Nullable token,
        NSError *_Nullable error) {
        FIRMessaging_STRONGIFY(self);
        if (error) {
          handler(nil, error);
          return;
        }
        if ([self isDefaultTokenWithAuthorizedEntity:authorizedEntity scope:scope]) {
          [self postTokenRefreshNotificationWithDefaultFCMToken:token];
        }
        NSString *firebaseAppID = options[kFIRMessagingTokenOptionsFirebaseAppIDKey];
        FIRMessagingTokenInfo *tokenInfo =
            [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:authorizedEntity
                                                              scope:scope
                                                              token:token
                                                         appVersion:FIRMessagingCurrentAppVersion()
                                                      firebaseAppID:firebaseAppID];
        tokenInfo.APNSInfo = [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:options];

        [self->_tokenStore
            saveTokenInfo:tokenInfo
                  handler:^(NSError *error) {
                    if (!error) {
                      // Do not send the token back in case the save was unsuccessful. Since with
                      // the new asychronous fetch mechanism this can lead to infinite loops, for
                      // example, we will return a valid token even though we weren't able to store
                      // it in our cache. The first token will lead to a onTokenRefresh callback
                      // wherein the user again calls `getToken` but since we weren't able to save
                      // it we won't hit the cache but hit the server again leading to an infinite
                      // loop.
                      FIRMessagingLoggerDebug(
                          kFIRMessagingMessageCodeTokenManager001,
                          @"Token fetch successful, token: %@, authorizedEntity: %@, scope:%@",
                          token, authorizedEntity, scope);

                      if (handler) {
                        handler(token, nil);
                      }
                    } else {
                      if (handler) {
                        handler(nil, error);
                      }
                    }
                  }];
      };
  // Add completion handler, and ensure it's called on the main queue
  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(result, token, error);
    });
  }];
  [self.tokenOperations addOperation:operation];
}

- (FIRMessagingTokenInfo *)cachedTokenInfoWithAuthorizedEntity:(NSString *)authorizedEntity
                                                         scope:(NSString *)scope {
  FIRMessagingTokenInfo *tokenInfo = [_tokenStore tokenInfoWithAuthorizedEntity:authorizedEntity
                                                                          scope:scope];
  return tokenInfo;
}

- (BOOL)isDefaultTokenWithAuthorizedEntity:(NSString *)authorizedEntity scope:(NSString *)scope {
  if (_fcmSenderID.length != authorizedEntity.length) {
    return NO;
  }
  if (![_fcmSenderID isEqualToString:authorizedEntity]) {
    return NO;
  }
  return [scope isEqualToString:kFIRMessagingDefaultTokenScope];
}

- (void)deleteTokenWithAuthorizedEntity:(NSString *)authorizedEntity
                                  scope:(NSString *)scope
                             instanceID:(NSString *)instanceID
                                handler:(FIRMessagingDeleteFCMTokenCompletion)handler {
  if ([_tokenStore tokenInfoWithAuthorizedEntity:authorizedEntity scope:scope]) {
    [_tokenStore removeTokenWithAuthorizedEntity:authorizedEntity scope:scope];
  }
  // Does not matter if we cannot find it in the cache. Still make an effort to unregister
  // from the server.
  FIRMessagingCheckinPreferences *checkinPreferences = self.authService.checkinPreferences;
  FIRMessagingTokenDeleteOperation *operation =
      [self createDeleteOperationWithAuthorizedEntity:authorizedEntity
                                                scope:scope
                                   checkinPreferences:checkinPreferences
                                           instanceID:instanceID
                                               action:FIRMessagingTokenActionDeleteToken];

  if (handler) {
    [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                      NSString *_Nullable token, NSError *_Nullable error) {
      if ([self isDefaultTokenWithAuthorizedEntity:authorizedEntity scope:scope]) {
        [self postTokenRefreshNotificationWithDefaultFCMToken:nil];
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
      });
    }];
  }
  [self.tokenOperations addOperation:operation];
}

- (void)deleteAllTokensWithHandler:(void (^)(NSError *))handler {
  FIRMessaging_WEAKIFY(self);

  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        FIRMessaging_STRONGIFY(self);
        if (error) {
          if (handler) {
            dispatch_async(dispatch_get_main_queue(), ^{
              handler(error);
            });
          }
          return;
        }
        // delete all tokens
        FIRMessagingCheckinPreferences *checkinPreferences = self.authService.checkinPreferences;
        if (!checkinPreferences) {
          // The checkin is already deleted. No need to trigger the token delete operation as client
          // no longer has the checkin information for server to delete.
          dispatch_async(dispatch_get_main_queue(), ^{
            handler(nil);
          });
          return;
        }
        FIRMessagingTokenDeleteOperation *operation = [self
            createDeleteOperationWithAuthorizedEntity:kFIRMessagingKeychainWildcardIdentifier
                                                scope:kFIRMessagingKeychainWildcardIdentifier
                                   checkinPreferences:checkinPreferences
                                           instanceID:identifier
                                               action:FIRMessagingTokenActionDeleteTokenAndIID];
        if (handler) {
          [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                            NSString *_Nullable token, NSError *_Nullable error) {
            self->_defaultFCMToken = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
              handler(error);
            });
          }];
        }
        [self.tokenOperations addOperation:operation];
      }];
}

- (void)deleteAllTokensLocallyWithHandler:(void (^)(NSError *error))handler {
  [_tokenStore removeAllTokensWithHandler:handler];
}

- (void)stopAllTokenOperations {
  [self.authService stopCheckinRequest];
  [self.tokenOperations cancelAllOperations];
}

- (void)deleteWithHandler:(void (^)(NSError *))handler {
  FIRMessaging_WEAKIFY(self);
  [self deleteAllTokensWithHandler:^(NSError *_Nullable error) {
    FIRMessaging_STRONGIFY(self);
    if (error) {
      handler(error);
      return;
    }
    [self deleteAllTokensLocallyWithHandler:^(NSError *localError) {
      [self postTokenRefreshNotificationWithDefaultFCMToken:nil];
      self->_defaultFCMToken = nil;
      if (localError) {
        handler(localError);
        return;
      }
      [self.authService resetCheckinWithHandler:^(NSError *_Nonnull authError) {
        handler(authError);
      }];
    }];
  }];
}

#pragma mark - CheckinStore

/**
 *  Reset the keychain preferences if the app had been deleted earlier and then reinstalled.
 *  Keychain preferences are not cleared in the above scenario so explicitly clear them.
 *
 *  In case of an iCloud backup and restore the Keychain preferences should already be empty
 *  since the Keychain items are marked with `*BackupThisDeviceOnly`.
 */
- (void)resetCredentialsIfNeeded {
  BOOL checkinPlistExists = [_authService hasCheckinPlist];
  // Checkin info existed in backup excluded plist. Should not be a fresh install.
  if (checkinPlistExists) {
    return;
  }
  // Keychain can still exist even if app is uninstalled.
  FIRMessagingCheckinPreferences *oldCheckinPreferences = _authService.checkinPreferences;

  if (!oldCheckinPreferences) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeStore009,
                            @"App reset detected but no valid checkin auth preferences found."
                            @" Will not delete server token registrations.");
    return;
  }
  [_authService resetCheckinWithHandler:^(NSError *_Nonnull error) {
    if (!error) {
      FIRMessagingLoggerDebug(
          kFIRMessagingMessageCodeStore002,
          @"Removed cached checkin preferences from Keychain because this is a fresh install.");
    } else {
      FIRMessagingLoggerError(
          kFIRMessagingMessageCodeStore003,
          @"Couldn't remove cached checkin preferences for a fresh install. Error: %@", error);
    }

    if (oldCheckinPreferences.deviceID.length && oldCheckinPreferences.secretToken.length) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeStore006,
                              @"Resetting old checkin and deleting server token registrations.");
      // We don't really need to delete old FCM tokens created via IID auth tokens since
      // those tokens are already hashed by APNS token as the has so creating a new
      // token should automatically delete the old-token.
      [self didDeleteFCMScopedTokensForCheckin:oldCheckinPreferences];
    }
  }];
}

- (void)didDeleteFCMScopedTokensForCheckin:(FIRMessagingCheckinPreferences *)checkin {
  // Make a best effort try to delete the old client related state on the FCM server. This is
  // required to delete old pubusb registrations which weren't cleared when the app was deleted.
  //
  // This is only a one time effort. If this call fails the client would still receive duplicate
  // pubsub notifications if he is again subscribed to the same topic.
  //
  // The client state should be cleared on the server for the provided checkin preferences.
  FIRMessagingTokenDeleteOperation *operation =
      [self createDeleteOperationWithAuthorizedEntity:nil
                                                scope:nil
                                   checkinPreferences:checkin
                                           instanceID:nil
                                               action:FIRMessagingTokenActionDeleteToken];
  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    if (error) {
      FIRMessagingMessageCode code =
          kFIRMessagingMessageCodeTokenManagerErrorDeletingFCMTokensOnAppReset;
      FIRMessagingLoggerDebug(code, @"Failed to delete GCM server registrations on app reset.");
    } else {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManagerDeletedFCMTokensOnAppReset,
                              @"Successfully deleted GCM server registrations on app reset");
    }
  }];

  [self.tokenOperations addOperation:operation];
}

#pragma mark - Unit Testing Stub Helpers
// We really have this method so that we can more easily stub it out for unit testing
- (FIRMessagingTokenFetchOperation *)
    createFetchOperationWithAuthorizedEntity:(NSString *)authorizedEntity
                                       scope:(NSString *)scope
                                     options:(NSDictionary<NSString *, NSString *> *)options
                                  instanceID:(NSString *)instanceID {
  FIRMessagingCheckinPreferences *checkinPreferences = self.authService.checkinPreferences;
  FIRMessagingTokenFetchOperation *operation =
      [[FIRMessagingTokenFetchOperation alloc] initWithAuthorizedEntity:authorizedEntity
                                                                  scope:scope
                                                                options:options
                                                     checkinPreferences:checkinPreferences
                                                             instanceID:instanceID];
  return operation;
}

// We really have this method so that we can more easily stub it out for unit testing
- (FIRMessagingTokenDeleteOperation *)
    createDeleteOperationWithAuthorizedEntity:(NSString *)authorizedEntity
                                        scope:(NSString *)scope
                           checkinPreferences:(FIRMessagingCheckinPreferences *)checkinPreferences
                                   instanceID:(NSString *)instanceID
                                       action:(FIRMessagingTokenAction)action {
  FIRMessagingTokenDeleteOperation *operation =
      [[FIRMessagingTokenDeleteOperation alloc] initWithAuthorizedEntity:authorizedEntity
                                                                   scope:scope
                                                      checkinPreferences:checkinPreferences
                                                              instanceID:instanceID
                                                                  action:action];
  return operation;
}

#pragma mark - Invalidating Cached Tokens
- (BOOL)checkTokenRefreshPolicyWithIID:(NSString *)IID {
  // We know at least one cached token exists.
  BOOL shouldFetchDefaultToken = NO;
  NSArray<FIRMessagingTokenInfo *> *tokenInfos = [_tokenStore cachedTokenInfos];

  NSMutableArray<FIRMessagingTokenInfo *> *tokenInfosToDelete =
      [NSMutableArray arrayWithCapacity:tokenInfos.count];
  for (FIRMessagingTokenInfo *tokenInfo in tokenInfos) {
    if ([tokenInfo isFreshWithIID:IID]) {
      // Token is fresh and in right format, do nothing
      continue;
    }
    if ([tokenInfo isDefaultToken]) {
      // Default token is expired, do not mark for deletion. Fetch directly from server to
      // replace the current one.
      shouldFetchDefaultToken = YES;
    } else {
      // Non-default token is expired, mark for deletion.
      [tokenInfosToDelete addObject:tokenInfo];
    }
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeTokenManagerInvalidateStaleToken,
        @"Invalidating cached token for %@ (%@) due to token is no longer fresh.",
        tokenInfo.authorizedEntity, tokenInfo.scope);
  }
  for (FIRMessagingTokenInfo *tokenInfoToDelete in tokenInfosToDelete) {
    [_tokenStore removeTokenWithAuthorizedEntity:tokenInfoToDelete.authorizedEntity
                                           scope:tokenInfoToDelete.scope];
  }
  return shouldFetchDefaultToken;
}

- (NSArray<FIRMessagingTokenInfo *> *)updateTokensToAPNSDeviceToken:(NSData *)deviceToken
                                                          isSandbox:(BOOL)isSandbox {
  // Each cached IID token that is missing an APNSInfo, or has an APNSInfo associated should be
  // checked and invalidated if needed.
  FIRMessagingAPNSInfo *APNSInfo = [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:deviceToken
                                                                           isSandbox:isSandbox];
  if ([self.currentAPNSInfo isEqualToAPNSInfo:APNSInfo]) {
    return @[];
  }
  self.currentAPNSInfo = APNSInfo;

  NSArray<FIRMessagingTokenInfo *> *tokenInfos = [_tokenStore cachedTokenInfos];
  NSMutableArray<FIRMessagingTokenInfo *> *tokenInfosToDelete =
      [NSMutableArray arrayWithCapacity:tokenInfos.count];
  for (FIRMessagingTokenInfo *cachedTokenInfo in tokenInfos) {
    // Check if the cached APNSInfo is nil, or if it is an old APNSInfo.
    if (!cachedTokenInfo.APNSInfo ||
        ![cachedTokenInfo.APNSInfo isEqualToAPNSInfo:self.currentAPNSInfo]) {
      // Mark for invalidation.
      [tokenInfosToDelete addObject:cachedTokenInfo];
    }
  }
  for (FIRMessagingTokenInfo *tokenInfoToDelete in tokenInfosToDelete) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManagerAPNSChangedTokenInvalidated,
                            @"Invalidating cached token for %@ (%@) due to APNs token change.",
                            tokenInfoToDelete.authorizedEntity, tokenInfoToDelete.scope);
    [_tokenStore removeTokenWithAuthorizedEntity:tokenInfoToDelete.authorizedEntity
                                           scope:tokenInfoToDelete.scope];
  }
  return tokenInfosToDelete;
}

#pragma mark - APNS Token
- (void)setAPNSToken:(NSData *)APNSToken withUserInfo:(NSDictionary *)userInfo {
  if (!APNSToken || ![APNSToken isKindOfClass:[NSData class]]) {
    if ([APNSToken class]) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeInternal002, @"Invalid APNS token type %@",
                              NSStringFromClass([APNSToken class]));
    } else {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeInternal002, @"Empty APNS token type");
    }
    return;
  }
  NSInteger type = [userInfo[kFIRMessagingAPNSTokenType] integerValue];

  // The APNS token is being added, or has changed (rare)
  if ([self.currentAPNSInfo.deviceToken isEqualToData:APNSToken]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeInstanceID011,
                            @"Trying to reset APNS token to the same value. Will return");
    return;
  }
  // Use this token type for when we have to automatically fetch tokens in the future
  BOOL isSandboxApp = (type == FIRMessagingAPNSTokenTypeSandbox);
  if (type == FIRMessagingAPNSTokenTypeUnknown) {
    isSandboxApp = FIRMessagingIsSandboxApp();
  }

  // Pro-actively invalidate the default token, if the APNs change makes it
  // invalid. Previously, we invalidated just before fetching the token.
  NSArray<FIRMessagingTokenInfo *> *invalidatedTokens =
      [self updateTokensToAPNSDeviceToken:APNSToken isSandbox:isSandboxApp];

  self.currentAPNSInfo = [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:[APNSToken copy]
                                                                 isSandbox:isSandboxApp];

  // Re-fetch any invalidated tokens automatically, this time with the current APNs token, so that
  // they are up-to-date.
  if (invalidatedTokens.count > 0) {
    FIRMessaging_WEAKIFY(self);

    [self.installations
        installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
          FIRMessaging_STRONGIFY(self);
          if (self == nil) {
            FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID017,
                                    @"Instance ID shut down during token reset. Aborting");
            return;
          }
          if (self.currentAPNSInfo == nil) {
            FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID018,
                                    @"apnsTokenData was set to nil during token reset. Aborting");
            return;
          }

          NSMutableDictionary *tokenOptions = [@{
            kFIRMessagingTokenOptionsAPNSKey : self.currentAPNSInfo.deviceToken,
            kFIRMessagingTokenOptionsAPNSIsSandboxKey : @(isSandboxApp)
          } mutableCopy];
          if (self.firebaseAppID) {
            tokenOptions[kFIRMessagingTokenOptionsFirebaseAppIDKey] = self.firebaseAppID;
          }

          for (FIRMessagingTokenInfo *tokenInfo in invalidatedTokens) {
            [self fetchNewTokenWithAuthorizedEntity:tokenInfo.authorizedEntity
                                              scope:tokenInfo.scope
                                         instanceID:identifier
                                            options:tokenOptions
                                            handler:^(NSString *_Nullable token,
                                                      NSError *_Nullable error){

                                            }];
          }
        }];
  }
}

#pragma mark - checkin
- (BOOL)hasValidCheckinInfo {
  return self.authService.checkinPreferences.hasValidCheckinInfo;
}

@end
