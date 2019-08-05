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

#import "FChildChangeAccumulator.h"
#import "FChange.h"
#import "FIndex.h"

@interface FChildChangeAccumulator ()
@property(nonatomic, strong) NSMutableDictionary *changeMap;
@end

@implementation FChildChangeAccumulator

- (id)init {
    self = [super init];
    if (self) {
        self.changeMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)trackChildChange:(FChange *)change {
    FIRDataEventType type = change.type;
    NSString *childKey = change.childKey;
    NSAssert(type == FIRDataEventTypeChildAdded ||
                 type == FIRDataEventTypeChildChanged ||
                 type == FIRDataEventTypeChildRemoved,
             @"Only child changes supported for tracking.");
    NSAssert(![change.childKey isEqualToString:@".priority"],
             @"Changes not tracked on priority");
    if (self.changeMap[childKey] != nil) {
        FChange *oldChange = [self.changeMap objectForKey:childKey];
        FIRDataEventType oldType = oldChange.type;
        if (type == FIRDataEventTypeChildAdded &&
            oldType == FIRDataEventTypeChildRemoved) {
            FChange *newChange =
                [[FChange alloc] initWithType:FIRDataEventTypeChildChanged
                                  indexedNode:change.indexedNode
                                     childKey:childKey
                               oldIndexedNode:oldChange.indexedNode];
            [self.changeMap setObject:newChange forKey:childKey];
        } else if (type == FIRDataEventTypeChildRemoved &&
                   oldType == FIRDataEventTypeChildAdded) {
            [self.changeMap removeObjectForKey:childKey];
        } else if (type == FIRDataEventTypeChildRemoved &&
                   oldType == FIRDataEventTypeChildChanged) {
            FChange *newChange =
                [[FChange alloc] initWithType:FIRDataEventTypeChildRemoved
                                  indexedNode:oldChange.oldIndexedNode
                                     childKey:childKey];
            [self.changeMap setObject:newChange forKey:childKey];
        } else if (type == FIRDataEventTypeChildChanged &&
                   oldType == FIRDataEventTypeChildAdded) {
            FChange *newChange =
                [[FChange alloc] initWithType:FIRDataEventTypeChildAdded
                                  indexedNode:change.indexedNode
                                     childKey:childKey];
            [self.changeMap setObject:newChange forKey:childKey];
        } else if (type == FIRDataEventTypeChildChanged &&
                   oldType == FIRDataEventTypeChildChanged) {
            FChange *newChange =
                [[FChange alloc] initWithType:FIRDataEventTypeChildChanged
                                  indexedNode:change.indexedNode
                                     childKey:childKey
                               oldIndexedNode:oldChange.oldIndexedNode];
            [self.changeMap setObject:newChange forKey:childKey];
        } else {
            NSString *reason = [NSString
                stringWithFormat:
                    @"Illegal combination of changes: %@ occurred after %@",
                    change, oldChange];
            @throw [[NSException alloc]
                initWithName:@"FirebaseDatabaseInternalError"
                      reason:reason
                    userInfo:nil];
        }
    } else {
        [self.changeMap setObject:change forKey:childKey];
    }
}

- (NSArray *)changes {
    return [self.changeMap allValues];
}

@end
