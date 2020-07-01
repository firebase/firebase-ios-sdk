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

#import "FIRMessagingTokenManager.h"

#import <FirebaseInstallations/FIRInstallations.h>

#import "FIRInstanceIDTokenInfo.h"
#import "FIRMessagingAuthKeyChain.h"
#import "FIRMessagingAuthService.h"
#import "FIRMessagingCheckinPreferences.h"
#import "FIRMessagingConstants.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingStore.h"
#import "FIRMessagingTokenDeleteOperation.h"
#import "FIRMessagingTokenFetchOperation.h"
#import "FIRMessagingTokenOperation.h"
#import "NSError+FIRMessaging.h"

@interface FIRMessagingTokenManager () <FIRMessagingStoreDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingStore *instanceIDStore;
@property(nonatomic, readwrite, strong) FIRMessagingAuthService *authService;
@property(nonatomic, readonly, strong) NSOperationQueue *tokenOperations;

@property(nonatomic, readwrite, strong) FIRInstanceIDAPNSInfo *currentAPNSInfo;
@property(nonatomic, readwrite) FIRInstallations *installations;

@end

@implementation FIRMessagingTokenManager

- (instancetype)init {
  self = [super init];
  if (self) {
    if (![FIRMessagingStore hasSubDirectory:kFIRInstanceIDSubDirectoryName]) {
      [FIRMessagingStore createSubDirectory:kFIRInstanceIDSubDirectoryName];
    }
    _instanceIDStore = [[FIRMessagingStore alloc] initWithDelegate:self];
    _authService = [[FIRMessagingAuthService alloc] initWithStore:_instanceIDStore];

    [self configureTokenOperations];
    _installations = [FIRInstallations installations];
  }
  return self;
}

- (void)dealloc {
  [self stopAllTokenOperations];
  _fcmSenderID = nil;
  _currentAPNSInfo = nil;
  [super dealloc];
}

- (NSString *)token {
  if (!self.fcmSenderID.length) {
    return nil;
  }

  FIRInstanceIDTokenInfo *cachedTokenInfo =
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
        [_installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                       NSError *_Nullable error) {
          FIRMessaging_STRONGIFY(self);

          if (error) {
            newHandler(nil, error);
          } else {
            FIRInstanceIDTokenInfo *cachedTokenInfo =
                [self cachedTokenInfoWithAuthorizedEntity:authorizedEntity scope:scope];
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
        NSString *firebaseAppID = options[kFIRMessagingTokenOptionsFirebaseAppIDKey];
        FIRInstanceIDTokenInfo *tokenInfo =
            [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:authorizedEntity
                                                               scope:scope
                                                               token:token
                                                          appVersion:FIRMessagingCurrentAppVersion()
                                                       firebaseAppID:firebaseAppID];
        tokenInfo.APNSInfo = [[FIRInstanceIDAPNSInfo alloc] initWithTokenOptionsDictionary:options];

        [self.instanceIDStore
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

- (FIRInstanceIDTokenInfo *)cachedTokenInfoWithAuthorizedEntity:(NSString *)authorizedEntity
                                                          scope:(NSString *)scope {
  return [self.instanceIDStore tokenInfoWithAuthorizedEntity:authorizedEntity scope:scope];
}

- (void)deleteTokenWithAuthorizedEntity:(NSString *)authorizedEntity
                                  scope:(NSString *)scope
                             instanceID:(NSString *)instanceID
                                handler:(FIRMessagingDeleteFCMTokenCompletion)handler {
  if ([self.instanceIDStore tokenInfoWithAuthorizedEntity:authorizedEntity scope:scope]) {
    [self.instanceIDStore removeCachedTokenWithAuthorizedEntity:authorizedEntity scope:scope];
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
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
      });
    }];
  }
  [self.tokenOperations addOperation:operation];
}

- (void)deleteAllTokensWithInstanceID:(NSString *)instanceID handler:(void (^)(NSError *))handler {
  // delete all tokens
  FIRMessagingCheckinPreferences *checkinPreferences = self.authService.checkinPreferences;
  if (!checkinPreferences) {
    // The checkin is already deleted. No need to trigger the token delete operation as client no
    // longer has the checkin information for server to delete.
    dispatch_async(dispatch_get_main_queue(), ^{
      handler(nil);
    });
    return;
  }
  FIRMessagingTokenDeleteOperation *operation =
      [self createDeleteOperationWithAuthorizedEntity:kFIRMessagingKeychainWildcardIdentifier
                                                scope:kFIRMessagingKeychainWildcardIdentifier
                                   checkinPreferences:checkinPreferences
                                           instanceID:instanceID
                                               action:FIRMessagingTokenActionDeleteTokenAndIID];
  if (handler) {
    [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                      NSString *_Nullable token, NSError *_Nullable error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
      });
    }];
  }
  [self.tokenOperations addOperation:operation];
}

- (void)deleteAllTokensLocallyWithHandler:(void (^)(NSError *error))handler {
  [self.instanceIDStore removeAllCachedTokensWithHandler:handler];
}

- (void)stopAllTokenOperations {
  [self.authService stopCheckinRequest];
  [self.tokenOperations cancelAllOperations];
}

#pragma mark - FIRMessagingStoreDelegate

- (void)store:(FIRMessagingStore *)store
    didDeleteFCMScopedTokensForCheckin:(FIRMessagingCheckinPreferences *)checkin {
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
  NSArray<FIRInstanceIDTokenInfo *> *tokenInfos = [self.instanceIDStore cachedTokenInfos];

  NSMutableArray<FIRInstanceIDTokenInfo *> *tokenInfosToDelete =
      [NSMutableArray arrayWithCapacity:tokenInfos.count];
  for (FIRInstanceIDTokenInfo *tokenInfo in tokenInfos) {
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
  for (FIRInstanceIDTokenInfo *tokenInfoToDelete in tokenInfosToDelete) {
    [self.instanceIDStore removeCachedTokenWithAuthorizedEntity:tokenInfoToDelete.authorizedEntity
                                                          scope:tokenInfoToDelete.scope];
  }
  return shouldFetchDefaultToken;
}

- (NSArray<FIRInstanceIDTokenInfo *> *)updateTokensToAPNSDeviceToken:(NSData *)deviceToken
                                                           isSandbox:(BOOL)isSandbox {
  // Each cached IID token that is missing an APNSInfo, or has an APNSInfo associated should be
  // checked and invalidated if needed.
  FIRInstanceIDAPNSInfo *APNSInfo = [[FIRInstanceIDAPNSInfo alloc] initWithDeviceToken:deviceToken
                                                                             isSandbox:isSandbox];
  if ([self.currentAPNSInfo isEqualToAPNSInfo:APNSInfo]) {
    return @[];
  }
  self.currentAPNSInfo = APNSInfo;

  NSArray<FIRInstanceIDTokenInfo *> *tokenInfos = [self.instanceIDStore cachedTokenInfos];
  NSMutableArray<FIRInstanceIDTokenInfo *> *tokenInfosToDelete =
      [NSMutableArray arrayWithCapacity:tokenInfos.count];
  for (FIRInstanceIDTokenInfo *cachedTokenInfo in tokenInfos) {
    // Check if the cached APNSInfo is nil, or if it is an old APNSInfo.
    if (!cachedTokenInfo.APNSInfo ||
        ![cachedTokenInfo.APNSInfo isEqualToAPNSInfo:self.currentAPNSInfo]) {
      // Mark for invalidation.
      [tokenInfosToDelete addObject:cachedTokenInfo];
    }
  }
  for (FIRInstanceIDTokenInfo *tokenInfoToDelete in tokenInfosToDelete) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManagerAPNSChangedTokenInvalidated,
                            @"Invalidating cached token for %@ (%@) due to APNs token change.",
                            tokenInfoToDelete.authorizedEntity, tokenInfoToDelete.scope);
    [self.instanceIDStore removeCachedTokenWithAuthorizedEntity:tokenInfoToDelete.authorizedEntity
                                                          scope:tokenInfoToDelete.scope];
  }
  return tokenInfosToDelete;
}

#pragma mark - APNS Token
- (void)setAPNSToken:(NSData *)APNSToken withUserInfo:(NSDictionary *)userInfo {
  if (!APNSToken || ![APNSToken isKindOfClass:[NSData class]]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeInternal002, @"Invalid APNS token type %@",
                            NSStringFromClass([APNSToken class]));
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
  self.currentAPNSInfo = [[FIRInstanceIDAPNSInfo alloc] initWithDeviceToken:[APNSToken copy]
                                                                  isSandbox:isSandboxApp];

  // Pro-actively invalidate the default token, if the APNs change makes it
  // invalid. Previously, we invalidated just before fetching the token.
  NSArray<FIRInstanceIDTokenInfo *> *invalidatedTokens =
      [self updateTokensToAPNSDeviceToken:APNSToken isSandbox:isSandboxApp];

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

          for (FIRInstanceIDTokenInfo *tokenInfo in invalidatedTokens) {
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
