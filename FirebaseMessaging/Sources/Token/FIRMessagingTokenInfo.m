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

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

/**
 *  @enum Token Info Dictionary Key Constants
 *  @discussion The keys that are checked when a token info is
 *              created from a dictionary. The same keys are used
 *              when decoding/encoding an archive.
 */
/// Specifies a dictionary key whose value represents the authorized entity, or
/// Sender ID for the token.
static NSString *const kFIRInstanceIDAuthorizedEntityKey = @"authorized_entity";
/// Specifies a dictionary key whose value represents the scope of the token,
/// typically "*".
static NSString *const kFIRInstanceIDScopeKey = @"scope";
/// Specifies a dictionary key which represents the token value itself.
static NSString *const kFIRInstanceIDTokenKey = @"token";
/// Specifies a dictionary key which represents the app version associated
/// with the token.
static NSString *const kFIRInstanceIDAppVersionKey = @"app_version";
/// Specifies a dictionary key which represents the GMP App ID associated with
/// the token.
static NSString *const kFIRInstanceIDFirebaseAppIDKey = @"firebase_app_id";
/// Specifies a dictionary key representing an archive for a
/// `FIRInstanceIDAPNSInfo` object.
static NSString *const kFIRInstanceIDAPNSInfoKey = @"apns_info";
/// Specifies a dictionary key representing the "last cached" time for the token.
static NSString *const kFIRInstanceIDCacheTimeKey = @"cache_time";
/// Default interval that token stays fresh.
static const NSTimeInterval kDefaultFetchTokenInterval = 7 * 24 * 60 * 60;  // 7 days.

@implementation FIRMessagingTokenInfo

- (instancetype)initWithAuthorizedEntity:(NSString *)authorizedEntity
                                   scope:(NSString *)scope
                                   token:(NSString *)token
                              appVersion:(NSString *)appVersion
                           firebaseAppID:(NSString *)firebaseAppID {
  self = [super init];
  if (self) {
    _authorizedEntity = [authorizedEntity copy];
    _scope = [scope copy];
    _token = [token copy];
    _appVersion = [appVersion copy];
    _firebaseAppID = [firebaseAppID copy];
  }
  return self;
}

- (BOOL)isFreshWithIID:(NSString *)IID {
  // Last fetch token cache time could be null if token is from legacy storage format. Then token is
  // considered not fresh and should be refreshed and overwrite with the latest storage format.
  if (!IID) {
    return NO;
  }
  if (!_cacheTime) {
    return NO;
  }

  // Check if it's consistent with IID
  if (![self.token hasPrefix:IID]) {
    return NO;
  }

  if ([self hasDenylistedScope]) {
    return NO;
  }

  // Check if app has just been updated to a new version.
  NSString *currentAppVersion = FIRMessagingCurrentAppVersion();
  if (!_appVersion || ![_appVersion isEqualToString:currentAppVersion]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManager004,
                            @"Invalidating cached token for %@ (%@) due to app version change.",
                            _authorizedEntity, _scope);
    return NO;
  }

  // Check if GMP App ID has changed
  NSString *currentFirebaseAppID = FIRMessagingFirebaseAppID();
  if (!_firebaseAppID || ![_firebaseAppID isEqualToString:currentFirebaseAppID]) {
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeTokenInfoFirebaseAppIDChanged,
        @"Invalidating cached token due to Firebase App IID change from %@ to %@", _firebaseAppID,
        currentFirebaseAppID);
    return NO;
  }

  // Check whether locale has changed, if yes, token needs to be updated with server for locale
  // information.
  if (FIRMessagingHasLocaleChanged()) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenInfoLocaleChanged,
                            @"Invalidating cached token due to locale change");
    return NO;
  }

  // Locale is not changed, check whether token has been fetched within 7 days.
  NSTimeInterval lastFetchTokenTimestamp = [_cacheTime timeIntervalSince1970];
  NSTimeInterval currentTimestamp = FIRMessagingCurrentTimestampInSeconds();
  NSTimeInterval timeSinceLastFetchToken = currentTimestamp - lastFetchTokenTimestamp;
  return (timeSinceLastFetchToken < kDefaultFetchTokenInterval);
}

- (BOOL)hasDenylistedScope {
  /// The token with fiam scope is set by old FIAM SDK(s) which will remain in keychain for ever. So
  /// we need to remove these tokens to deny its usage.
  if ([self.scope isEqualToString:kFIRMessagingFIAMTokenScope]) {
    return YES;
  }

  return NO;
}

- (BOOL)isDefaultToken {
  return [self.scope isEqualToString:kFIRMessagingDefaultTokenScope];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  BOOL needsMigration = NO;
  // These value cannot be nil

  NSString *authorizedEntity = [aDecoder decodeObjectOfClass:[NSString class]
                                                      forKey:kFIRInstanceIDAuthorizedEntityKey];
  if (!authorizedEntity) {
    return nil;
  }

  NSString *scope = [aDecoder decodeObjectOfClass:[NSString class] forKey:kFIRInstanceIDScopeKey];
  if (!scope) {
    return nil;
  }

  NSString *token = [aDecoder decodeObjectOfClass:[NSString class] forKey:kFIRInstanceIDTokenKey];
  if (!token) {
    return nil;
  }

  // These values are nullable, so don't fail on nil.

  NSString *appVersion = [aDecoder decodeObjectOfClass:[NSString class]
                                                forKey:kFIRInstanceIDAppVersionKey];
  NSString *firebaseAppID = [aDecoder decodeObjectOfClass:[NSString class]
                                                   forKey:kFIRInstanceIDFirebaseAppIDKey];

  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingAPNSInfo.class ]];
  FIRMessagingAPNSInfo *rawAPNSInfo = [aDecoder decodeObjectOfClasses:classes
                                                               forKey:kFIRInstanceIDAPNSInfoKey];
  if (rawAPNSInfo && ![rawAPNSInfo isKindOfClass:[FIRMessagingAPNSInfo class]]) {
    // If the decoder fails to decode a FIRMessagingAPNSInfo, check if this was archived by a
    // FirebaseMessaging 10.18.0 or earlier.
    // TODO(#12246) This block may be replaced with `rawAPNSInfo = nil` once we're confident all
    // users have upgraded to at least 10.19.0. Perhaps, after privacy manifests have been required
    // for awhile?
    @try {
      [NSKeyedUnarchiver setClass:[FIRMessagingAPNSInfo class]
                     forClassName:@"FIRInstanceIDAPNSInfo"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      rawAPNSInfo = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)rawAPNSInfo];
      needsMigration = YES;
#pragma clang diagnostic pop
    } @catch (NSException *exception) {
      FIRMessagingLoggerInfo(kFIRMessagingMessageCodeTokenInfoBadAPNSInfo,
                             @"Could not parse raw APNS Info while parsing archived token info.");
      rawAPNSInfo = nil;
    } @finally {
    }
  }

  NSDate *cacheTime = [aDecoder decodeObjectOfClass:[NSDate class]
                                             forKey:kFIRInstanceIDCacheTimeKey];

  self = [super init];
  if (self) {
    _authorizedEntity = [authorizedEntity copy];
    _scope = [scope copy];
    _token = [token copy];
    _appVersion = [appVersion copy];
    _firebaseAppID = [firebaseAppID copy];
    _APNSInfo = [rawAPNSInfo copy];
    _cacheTime = cacheTime;
    _needsMigration = needsMigration;
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.authorizedEntity forKey:kFIRInstanceIDAuthorizedEntityKey];
  [aCoder encodeObject:self.scope forKey:kFIRInstanceIDScopeKey];
  [aCoder encodeObject:self.token forKey:kFIRInstanceIDTokenKey];
  [aCoder encodeObject:self.appVersion forKey:kFIRInstanceIDAppVersionKey];
  [aCoder encodeObject:self.firebaseAppID forKey:kFIRInstanceIDFirebaseAppIDKey];
  if (self.APNSInfo) {
    [aCoder encodeObject:self.APNSInfo forKey:kFIRInstanceIDAPNSInfoKey];
  }
  [aCoder encodeObject:self.cacheTime forKey:kFIRInstanceIDCacheTimeKey];
}

@end
