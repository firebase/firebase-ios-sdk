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

#import <Foundation/Foundation.h>

@class FIRMessagingAPNSInfo;
@class FIRMessagingAuthKeychain;
@class FIRMessagingTokenInfo;

/**
 *  This class is responsible for retrieving and saving `FIRMessagingTokenInfo` objects from the
 *  keychain. The keychain keys that are used are:
 *  Account: <Main App Bundle ID> (e.g. com.mycompany.myapp)
 *  Service: <Sender ID>:<Scope> (e.g. 1234567890:*)
 */
@interface FIRMessagingTokenStore : NSObject

NS_ASSUME_NONNULL_BEGIN

- (instancetype)init;

#pragma mark - Get

/**
 *  Get the cached token from the Keychain.
 *
 *  @param authorizedEntity The authorized entity for the token.
 *  @param scope            The scope for the token.
 *
 *  @return The cached token info if any for the given authorizedEntity and scope else
 *          nil.
 */
- (nullable FIRMessagingTokenInfo *)tokenInfoWithAuthorizedEntity:(NSString *)authorizedEntity
                                                            scope:(NSString *)scope;

/**
 *  Return all cached token infos from the Keychain.
 *
 *  @return The cached token infos, if any, that are stored in the Keychain.
 */
- (NSArray<FIRMessagingTokenInfo *> *)cachedTokenInfos;

#pragma mark - Save

/**
 *  Save the instanceID token info to the persistent store.
 *
 *  @param tokenInfo        The token info to store.
 *  @param handler          The callback handler which is invoked when token saving is complete,
 *                          with an error if there is any.
 */
- (void)saveTokenInfo:(FIRMessagingTokenInfo *)tokenInfo
              handler:(nullable void (^)(NSError *))handler;

#pragma mark - Delete

/**
 *  Remove the cached token from Keychain.
 *
 *  @param authorizedEntity The authorized entity for the token.
 *  @param scope            The scope for the token.
 *
 */
- (void)removeTokenWithAuthorizedEntity:(NSString *)authorizedEntity scope:(NSString *)scope;

/**
 *  Remove all the cached tokens from the Keychain.
 *  @param handler          The callback handler which is invoked when tokens deletion is complete,
 *                          with an error if there is any.
 *
 */
- (void)removeAllTokensWithHandler:(nullable void (^)(NSError *))handler;

/*
 *  Only save to local cache but not keychain. This is used when old
 *  InstanceID SDK updates the token in the keychain, Messaging
 *  should update its cache without writing to keychain again.
 *  @param tokenInfo   The token info need to be updated in the cache.
 */
- (void)saveTokenInfoInCache:(FIRMessagingTokenInfo *)tokenInfo;

NS_ASSUME_NONNULL_END

@end
