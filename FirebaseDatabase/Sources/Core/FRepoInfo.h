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

@property(nonatomic, readwrite, copy) NSString *emulatedHost;
@property(nonatomic, readonly, copy) NSString *host;
@property(nonatomic, readonly, copy) NSString *namespace;
@property(nonatomic, readonly, copy) NSString *internalHost;
@property(nonatomic, readonly, assign) BOOL secure;

/// Returns `host`, unless `emulatedHost` is set.
@property(nonatomic, readonly, copy) NSString *activeHost;

- (instancetype)initWithHost:(NSString *)host
                    isSecure:(BOOL)secure
               withNamespace:(NSString *)namespace;

- (instancetype)initWithHost:(NSString *)host
                    isSecure:(BOOL)secure
               withNamespace:(NSString *)namespace
                emulatedHost:(NSString *_Nullable)emulatedHost NS_DESIGNATED_INITIALIZER;

- (NSString *)connectionURLWithLastSessionID:(NSString *_Nullable)lastSessionID;
- (NSString *)connectionURL;
- (void)clearInternalHostCache;
- (BOOL)isDemoHost;
- (BOOL)isCustomHost;

- (id)copyWithZone:(NSZone *)zone;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)anObject;

@end

NS_ASSUME_NONNULL_END
