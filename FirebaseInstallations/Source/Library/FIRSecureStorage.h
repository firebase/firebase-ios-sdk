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

@class FBLPromise<ValueType>;

NS_ASSUME_NONNULL_BEGIN

@interface FIRSecureStorage : NSObject

- (instancetype)initWithService:(NSString *)service;

- (FBLPromise<id<NSSecureCoding>> *)getObjectForKey:(NSString *)key
                                        objectClass:(Class)objectClass
                                        accessGroup:(nullable NSString *)accessGroup;

- (FBLPromise<NSNull *> *)setObject:(id<NSSecureCoding>)object
                             forKey:(NSString *)key
                        accessGroup:(nullable NSString *)accessGroup;

- (FBLPromise<NSNull *> *)removeObjectForKey:(NSString *)key
                                 accessGroup:(nullable NSString *)accessGroup;

// TODO: May be needed to read write legacy IID keychain items.
//- (FBLPromise<NSString *> *)getStringForKey:(NSString *)key;
//- (FBLPromise<id> *)setString:(NSString *)string forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
