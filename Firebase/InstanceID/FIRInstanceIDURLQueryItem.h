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

NS_ASSUME_NONNULL_BEGIN

@interface FIRInstanceIDURLQueryItem : NSObject

@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSString *value;

+ (instancetype)queryItemWithName:(NSString *)name value:(NSString *)value;
- (instancetype)initWithName:(NSString *)name value:(NSString *)value;

@end

/**
 *  Given an array of query items, construct a URL query.
 */
NSString *FIRInstanceIDQueryFromQueryItems(NSArray<FIRInstanceIDURLQueryItem *> *queryItems);

NS_ASSUME_NONNULL_END
