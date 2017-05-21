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

#import <Foundation/Foundation.h>

typedef void(^FIRMessagingInstanceIDProxyTokenHandler)(NSString * __nullable token,
    NSError * __nullable error);

typedef void(^FIRMessagingInstanceIDProxyDeleteTokenHandler)(NSError * __nullable error);

typedef NS_ENUM(NSInteger, FIRMessagingInstanceIDProxyAPNSTokenType) {
  /// Unknown token type.
  FIRMessagingInstanceIDProxyAPNSTokenTypeUnknown,
  /// Sandbox token type.
  FIRMessagingInstanceIDProxyAPNSTokenTypeSandbox,
  /// Production token type.
  FIRMessagingInstanceIDProxyAPNSTokenTypeProd,
};

/**
 *  FIRMessaging cannot always depend on FIRInstanceID directly, due to how FIRMessaging is
 *  packaged. To make it easier to make calls to FIRInstanceID, this proxy class, will provide
 *  method names duplicated from FIRInstanceID, while using reflection-based called to proxy
 *  the requests.
 */
@interface FIRMessagingInstanceIDProxy : NSObject

- (void)setAPNSToken:(nonnull NSData *)token type:(FIRMessagingInstanceIDProxyAPNSTokenType)type;

#pragma mark - Tokens

- (nullable NSString *)token;

- (void)tokenWithAuthorizedEntity:(nonnull NSString *)authorizedEntity
                            scope:(nonnull NSString *)scope
                          options:(nullable NSDictionary *)options
                          handler:(nonnull FIRMessagingInstanceIDProxyTokenHandler)handler;

- (void)deleteTokenWithAuthorizedEntity:(nonnull NSString *)authorizedEntity
                                  scope:(nonnull NSString *)scope
                                handler:
      (nonnull FIRMessagingInstanceIDProxyDeleteTokenHandler)handler;
@end
