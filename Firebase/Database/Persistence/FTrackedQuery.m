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

#import "FTrackedQuery.h"

#import "FQuerySpec.h"

@interface FTrackedQuery ()

@property (nonatomic, readwrite) NSUInteger queryId;
@property (nonatomic, strong, readwrite) FQuerySpec *query;
@property (nonatomic, readwrite) NSTimeInterval lastUse;
@property (nonatomic, readwrite) BOOL isComplete;
@property (nonatomic, readwrite) BOOL isActive;

@end


@implementation FTrackedQuery

- (id)initWithId:(NSUInteger)queryId
           query:(FQuerySpec *)query
         lastUse:(NSTimeInterval)lastUse
        isActive:(BOOL)isActive
      isComplete:(BOOL)isComplete {
    self = [super init];
    if (self != nil) {
        self->_queryId = queryId;
        self->_query = query;
        self->_lastUse = lastUse;
        self->_isComplete = isComplete;
        self->_isActive = isActive;
    }
    return self;
}

- (id)initWithId:(NSUInteger)queryId query:(FQuerySpec *)query lastUse:(NSTimeInterval)lastUse isActive:(BOOL)isActive {
    return [self initWithId:queryId query:query lastUse:lastUse isActive:isActive isComplete:NO];
}

- (FTrackedQuery *)updateLastUse:(NSTimeInterval)lastUse {
    return [[FTrackedQuery alloc] initWithId:self.queryId
                                       query:self.query
                                     lastUse:lastUse
                                    isActive:self.isActive
                                  isComplete:self.isComplete];
}

- (FTrackedQuery *)setComplete {
    return [[FTrackedQuery alloc] initWithId:self.queryId
                                       query:self.query
                                     lastUse:self.lastUse
                                    isActive:self.isActive
                                  isComplete:YES];
}

- (FTrackedQuery *)setActiveState:(BOOL)isActive {
    return [[FTrackedQuery alloc] initWithId:self.queryId
                                       query:self.query
                                     lastUse:self.lastUse
                                    isActive:isActive
                                  isComplete:self.isComplete];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[FTrackedQuery class]]) {
        return NO;
    }
    FTrackedQuery *other = (FTrackedQuery *)object;
    if (self.queryId != other.queryId) return NO;
    if (self.query != other.query && ![self.query isEqual:other.query]) return NO;
    if (self.lastUse != other.lastUse) return NO;
    if (self.isComplete != other.isComplete) return NO;
    if (self.isActive != other.isActive) return NO;

    return YES;
}

- (NSUInteger)hash {
    NSUInteger hash = self.queryId;
    hash = hash * 31 + self.query.hash;
    hash = hash * 31 + (self.isActive ? 1 : 0);
    hash = hash * 31 + (NSUInteger)self.lastUse;
    hash = hash * 31 + (self.isComplete ? 1 : 0);
    hash = hash * 31 + (self.isActive ? 1 : 0);
    return hash;
}

@end
