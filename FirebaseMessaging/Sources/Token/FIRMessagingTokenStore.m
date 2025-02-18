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

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenStore.h"

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthKeychain.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"

static NSString *const kFIRMessagingTokenKeychainId = @"com.google.iid-tokens";

@interface FIRMessagingTokenStore ()

@property(nonatomic, readwrite, strong) FIRMessagingAuthKeychain *keychain;

@end

@implementation FIRMessagingTokenStore

- (instancetype)init {
  self = [super init];
  if (self) {
    _keychain = [[FIRMessagingAuthKeychain alloc] initWithIdentifier:kFIRMessagingTokenKeychainId];
  }
  return self;
}

#pragma mark - Get

+ (NSString *)serviceKeyForAuthorizedEntity:(NSString *)authorizedEntity scope:(NSString *)scope {
  return [NSString stringWithFormat:@"%@:%@", authorizedEntity, scope];
}

- (nullable FIRMessagingTokenInfo *)tokenInfoWithAuthorizedEntity:(NSString *)authorizedEntity
                                                            scope:(NSString *)scope {
  // TODO(chliangGoogle): If we don't have the token plist we should delete all the tokens from
  // the keychain. This is because not having the plist signifies a backup and restore operation.
  // In case the keychain has any tokens these would now be stale and therefore should be
  // deleted.
  if (![authorizedEntity length] || ![scope length]) {
    return nil;
  }
  NSString *account = FIRMessagingAppIdentifier();
  NSString *service = [[self class] serviceKeyForAuthorizedEntity:authorizedEntity scope:scope];
  NSData *item = [self.keychain dataForService:service account:account];
  if (!item) {
    return nil;
  }
  // Token infos created from legacy storage don't have appVersion, firebaseAppID, or APNSInfo.
  FIRMessagingTokenInfo *tokenInfo = [[self class] tokenInfoFromKeychainItem:item];
  if ([tokenInfo needsMigration]) {
    [self
        saveTokenInfo:tokenInfo
              handler:^(NSError *error) {
                if (error) {
                  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManager001,
                                          @"Failed to migrate token: %@ account: %@ service %@",
                                          tokenInfo, account, service);
                } else {
                  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManager001,
                                          @"Successful token migration: %@ account: %@ service %@",
                                          tokenInfo, account, service);
                }
              }];
  }
  return tokenInfo;
}

- (NSArray<FIRMessagingTokenInfo *> *)cachedTokenInfos {
  NSString *account = FIRMessagingAppIdentifier();
  NSArray<NSData *> *items =
      [self.keychain itemsMatchingService:kFIRMessagingKeychainWildcardIdentifier account:account];
  NSMutableArray<FIRMessagingTokenInfo *> *tokenInfos =
      [NSMutableArray arrayWithCapacity:items.count];
  for (NSData *item in items) {
    FIRMessagingTokenInfo *tokenInfo = [[self class] tokenInfoFromKeychainItem:item];
    if (tokenInfo) {
      [tokenInfos addObject:tokenInfo];
    }
  }
  return tokenInfos;
}

+ (nullable FIRMessagingTokenInfo *)tokenInfoFromKeychainItem:(NSData *)item {
  // Check if it is saved as an archived FIRMessagingTokenInfo, otherwise return nil.
  FIRMessagingTokenInfo *tokenInfo = nil;
  if (item) {
    @try {
      NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:item
                                                                                  error:nil];
      unarchiver.requiresSecureCoding = NO;
      [unarchiver setClass:[FIRMessagingTokenInfo class] forClassName:@"FIRInstanceIDTokenInfo"];
      tokenInfo = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
      [unarchiver finishDecoding];
    } @catch (NSException *exception) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenStoreExceptionUnarchivingTokenInfo,
                              @"Unable to parse token info from Keychain item; item was in an "
                              @"invalid format");
      tokenInfo = nil;
    } @finally {
    }
  }
  return tokenInfo;
}

#pragma mark - Save
// Token Infos will be saved under these Keychain keys:
// Account: <Main App Bundle ID> (e.g. com.mycompany.myapp)
// Service: <Sender ID>:<Scope> (e.g. 1234567890:*)
- (void)saveTokenInfo:(FIRMessagingTokenInfo *)tokenInfo
              handler:(void (^)(NSError *))handler {  // Keep the cachetime up-to-date.
  tokenInfo.cacheTime = [NSDate date];
  // Always write to the Keychain, so that the cacheTime is up-to-date.
  NSData *tokenInfoData;
  // TODO(chliangGoogle: Use the new API and secureCoding protocol.
  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo" forClass:[FIRMessagingTokenInfo class]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  tokenInfoData = [NSKeyedArchiver archivedDataWithRootObject:tokenInfo];
#pragma clang diagnostic pop
  NSString *account = FIRMessagingAppIdentifier();
  NSString *service = [[self class] serviceKeyForAuthorizedEntity:tokenInfo.authorizedEntity
                                                            scope:tokenInfo.scope];
  [self.keychain setData:tokenInfoData forService:service account:account handler:handler];
}

- (void)saveTokenInfoInCache:(FIRMessagingTokenInfo *)tokenInfo {
  tokenInfo.cacheTime = [NSDate date];
  // TODO(chliangGoogle): Use the new API and secureCoding protocol.
  // Always write to the Keychain, so that the cacheTime is up-to-date.
  NSData *tokenInfoData;
  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo" forClass:[FIRMessagingTokenInfo class]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  tokenInfoData = [NSKeyedArchiver archivedDataWithRootObject:tokenInfo];
#pragma clang diagnostic pop
  NSString *account = FIRMessagingAppIdentifier();
  NSString *service = [[self class] serviceKeyForAuthorizedEntity:tokenInfo.authorizedEntity
                                                            scope:tokenInfo.scope];
  [self.keychain setCacheData:tokenInfoData forService:service account:account];
}

#pragma mark - Delete

- (void)removeTokenWithAuthorizedEntity:(nonnull NSString *)authorizedEntity
                                  scope:(nonnull NSString *)scope {
  if (![authorizedEntity length] || ![scope length]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeStore012,
                            @"Will not delete token with invalid entity: %@, scope: %@",
                            authorizedEntity, scope);
    return;
  }
  NSString *account = FIRMessagingAppIdentifier();
  NSString *service = [[self class] serviceKeyForAuthorizedEntity:authorizedEntity scope:scope];
  [self.keychain removeItemsMatchingService:service account:account handler:nil];
}

- (void)removeAllTokensWithHandler:(void (^)(NSError *error))handler {
  NSString *account = FIRMessagingAppIdentifier();
  [self.keychain removeItemsMatchingService:kFIRMessagingKeychainWildcardIdentifier
                                    account:account
                                    handler:handler];
}

@end
