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
@property(nonatomic, readwrite, copy) NSString *internalHost;
@property(nonatomic, readonly, assign) BOOL secure;

/// Returns YES if the host is not a *.firebaseio.com host.
@property(nonatomic, readonly) BOOL isCustomHost;

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
