/*
 * Copyright 2022 Google LLC
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

@class FIRAggregateQuery;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AggregateQuerySnapshot)
@interface FIRAggregateQuerySnapshot : NSObject
/** :nodoc: */
- (id)init NS_UNAVAILABLE;

@property(nonatomic, readonly) FIRAggregateQuery *query;

- (nullable NSNumber*)count;

@end

NS_ASSUME_NONNULL_END
