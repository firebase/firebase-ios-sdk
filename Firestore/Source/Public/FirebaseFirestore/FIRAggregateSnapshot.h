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

#import "FIRAggregateField.h"
#import "FIRDocumentSnapshot.h"

@class FIRTimestamp;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AggregateSnapshot)
@interface FIRAggregateSnapshot : NSObject
/** :nodoc: */
- (id)init __attribute__((unavailable("FIRAggregateSnapshot cannot be created directly.")));

- (NSDictionary<FIRAggregateField *, id> *)aggregations;

// Based on NSUserDefaults
- (NSDictionary<FIRAggregateField *, id> *)aggregationsWithServerTimestampBehavior:
    (FIRServerTimestampBehavior)serverTimestampBehavior;

- (nullable NSNumber*)count;

- (nullable id)valueForAggregateField:(FIRAggregateField *)aggregateField
    NS_SWIFT_NAME(value(forAggregateField:));

- (nullable id)valueForAggregateField:(FIRAggregateField *)aggregateField
     serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior
    NS_SWIFT_NAME(value(forAggregateField:serverTimestampBehavior:));

- (nullable NSString*)stringForAggregateField:(FIRAggregateField *)aggregateField
    NS_SWIFT_NAME(string(forAggregateField:));

- (nullable NSNumber*)numberForAggregateField:(FIRAggregateField *)aggregateField
    NS_SWIFT_NAME(integer(forAggregateField:));

- (nullable NSArray*)arrayForAggregateField:(FIRAggregateField *)aggregateField
    NS_SWIFT_NAME(array(forAggregateField:));

- (nullable FIRTimestamp*)timestampForAggregateField:(FIRAggregateField *)aggregateField
     serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior
               NS_SWIFT_NAME(timestamp(aggregateField:serverTimestampBehavior:));

- (nullable id)objectForKeyedSubscript:(FIRAggregateField *)aggregateField;

@end

NS_ASSUME_NONNULL_END
