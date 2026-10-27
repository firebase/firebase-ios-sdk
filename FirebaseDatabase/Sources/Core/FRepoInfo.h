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

NS_ASSUME_NONNULL_BEGIN

@interface FRepoInfo : NSObject <NSCopying>

/// The host that the database should connect to.
@property(nonatomic, readonly, copy) NSString *host;

@property(nonatomic, readonly, copy) NSString *namespace;

/// The host to connect to: a host provided by the server, if any, else `host`.
/// It is saved across launches. Setting nil or a host that isn't valid (see
/// `isValidHost:`) has no effect.
@property(nonatomic, readwrite, copy) NSString *internalHost;
@property(nonatomic, readonly, assign) BOOL secure;

/// Returns YES if the host is not a *.firebaseio.com host.
@property(nonatomic, readonly) BOOL isCustomHost;

/// Returns YES if `host` is acceptable as a server-provided host: 1 to 253
/// ASCII letters, digits, '.' or '-', with an optional numeric port. IPv6
/// literals and '_' are rejected. Server hosts look like
/// `s-usc1a-nss-2001.firebaseio.com`; emulator hosts like `localhost:9000`.
+ (BOOL)isValidHost:(nullable id)host;

- (instancetype)initWithHost:(NSString *)host
                    isSecure:(BOOL)secure
               withNamespace:(NSString *)namespace NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithInfo:(FRepoInfo *)info emulatedHost:(NSString *)host;

- (NSString *)connectionURLWithLastSessionID:(NSString *_Nullable)lastSessionID;
- (NSString *)connectionURL;
- (void)clearInternalHostCache;
- (BOOL)isDemoHost;
- (BOOL)isCustomHost;

- (id)copyWithZone:(NSZone *_Nullable)zone;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)anObject;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
