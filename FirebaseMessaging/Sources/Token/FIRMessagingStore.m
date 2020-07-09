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

#import "FIRMessagingStore.h"

#import "FIRMessagingCheckinPreferences.h"
#import "FIRMessagingCheckinStore.h"
#import "FIRMessagingConstants.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingTokenStore.h"
#import "FIRMessagingVersionUtilities.h"

// NOTE: These values should be in sync with what InstanceID saves in as.
static NSString *const kCheckinFileName = @"g-checkin";

@interface FIRMessagingStore ()

@property(nonatomic, readwrite, strong) FIRMessagingCheckinStore *checkinStore;
@property(nonatomic, readwrite, strong) FIRMessagingTokenStore *tokenStore;

@end

@implementation FIRMessagingStore

- (instancetype)initWithDelegate:(NSObject<FIRMessagingStoreDelegate> *)delegate {
  FIRMessagingCheckinStore *checkinStore = [[FIRMessagingCheckinStore alloc]
      initWithCheckinPlistFileName:kCheckinFileName
                  subDirectoryName:kFIRInstanceIDSubDirectoryName];

  FIRMessagingTokenStore *tokenStore = [FIRMessagingTokenStore defaultStore];

  return [self initWithCheckinStore:checkinStore tokenStore:tokenStore delegate:delegate];
}

- (instancetype)initWithCheckinStore:(FIRMessagingCheckinStore *)checkinStore
                          tokenStore:(FIRMessagingTokenStore *)tokenStore
                            delegate:(NSObject<FIRMessagingStoreDelegate> *)delegate {
  self = [super init];
  if (self) {
    _checkinStore = checkinStore;
    _tokenStore = tokenStore;
    _delegate = delegate;
    [self resetCredentialsIfNeeded];
  }
  return self;
}

- (void)dealloc {
  [_checkinStore release];
  [_tokenStore release];
  _delegate = nil;
  [super dealloc];
}

#pragma mark - Upgrades

+ (NSSearchPathDirectory)supportedDirectory {
#if TARGET_OS_TV
  return NSCachesDirectory;
#else
  return NSApplicationSupportDirectory;
#endif
}

+ (NSString *)pathForSupportSubDirectory:(NSString *)subDirectoryName {
  NSArray *directoryPaths =
      NSSearchPathForDirectoriesInDomains([self supportedDirectory], NSUserDomainMask, YES);
  NSString *dirPath = directoryPaths.lastObject;
  NSArray *components = @[ dirPath, subDirectoryName ];
  return [NSString pathWithComponents:components];
}

/**
 *  Reset the keychain preferences if the app had been deleted earlier and then reinstalled.
 *  Keychain preferences are not cleared in the above scenario so explicitly clear them.
 *
 *  In case of an iCloud backup and restore the Keychain preferences should already be empty
 *  since the Keychain items are marked with `*BackupThisDeviceOnly`.
 */
- (void)resetCredentialsIfNeeded {
  BOOL checkinPlistExists = [self.checkinStore hasCheckinPlist];
  // Checkin info existed in backup excluded plist. Should not be a fresh install.
  if (checkinPlistExists) {
    return;
  }

  // Resets checkin in keychain if a fresh install.
  // Keychain can still exist even if app is uninstalled.
  FIRMessagingCheckinPreferences *oldCheckinPreferences =
      [self.checkinStore cachedCheckinPreferences];

  if (oldCheckinPreferences) {
    [self.checkinStore removeCheckinPreferencesWithHandler:^(NSError *error) {
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
                                @"App reset detected. Will delete server registrations.");
        // We don't really need to delete old FCM tokens created via IID auth tokens since
        // those tokens are already hashed by APNS token as the has so creating a new
        // token should automatically delete the old-token.
        [self.delegate store:self didDeleteFCMScopedTokensForCheckin:oldCheckinPreferences];
      } else {
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeStore009,
                                @"App reset detected but no valid checkin auth preferences found."
                                @" Will not delete server registrations.");
      }
    }];
  }
}

#pragma mark - Get

- (FIRMessagingTokenInfo *)tokenInfoWithAuthorizedEntity:(NSString *)authorizedEntity
                                                   scope:(NSString *)scope {
  // TODO(chliangGoogle): If we don't have the token plist we should delete all the tokens from
  // the keychain. This is because not having the plist signifies a backup and restore operation.
  // In case the keychain has any tokens these would now be stale and therefore should be
  // deleted.
  if (![authorizedEntity length] || ![scope length]) {
    return nil;
  }
  FIRMessagingTokenInfo *info = [self.tokenStore tokenInfoWithAuthorizedEntity:authorizedEntity
                                                                         scope:scope];
  return info;
}

- (NSArray<FIRMessagingTokenInfo *> *)cachedTokenInfos {
  return [self.tokenStore cachedTokenInfos];
}

#pragma mark - Save

- (void)saveTokenInfo:(FIRMessagingTokenInfo *)tokenInfo handler:(void (^)(NSError *error))handler {
  [self.tokenStore saveTokenInfo:tokenInfo handler:handler];
}

#pragma mark - Delete

- (void)removeCachedTokenWithAuthorizedEntity:(NSString *)authorizedEntity scope:(NSString *)scope {
  if (![authorizedEntity length] || ![scope length]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeStore012,
                            @"Will not delete token with invalid entity: %@, scope: %@",
                            authorizedEntity, scope);
    return;
  }
  [self.tokenStore removeTokenWithAuthorizedEntity:authorizedEntity scope:scope];
}

- (void)removeAllCachedTokensWithHandler:(void (^)(NSError *error))handler {
  [self.tokenStore removeAllTokensWithHandler:handler];
}

#pragma mark - FIRMessagingCheckinCache protocol

- (void)saveCheckinPreferences:(FIRMessagingCheckinPreferences *)preferences
                       handler:(void (^)(NSError *error))handler {
  [self.checkinStore saveCheckinPreferences:preferences handler:handler];
}

- (FIRMessagingCheckinPreferences *)cachedCheckinPreferences {
  return [self.checkinStore cachedCheckinPreferences];
}

- (void)removeCheckinPreferencesWithHandler:(void (^)(NSError *))handler {
  [self.checkinStore removeCheckinPreferencesWithHandler:^(NSError *error) {
    if (handler) {
      handler(error);
    }
  }];
}

@end
