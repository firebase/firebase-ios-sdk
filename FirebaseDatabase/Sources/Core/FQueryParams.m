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

#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FIndexedFilter.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FLimitedFilter.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FNodeFilter.h"
#import "FirebaseDatabase/Sources/FIndex.h"
#import "FirebaseDatabase/Sources/FPriorityIndex.h"
#import "FirebaseDatabase/Sources/FRangedFilter.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FValidation.h"

@interface FQueryParams ()

@property(nonatomic, readwrite) BOOL limitSet;
@property(nonatomic, readwrite) NSInteger limit;

@property(nonatomic, strong, readwrite) NSString *viewFrom;
/**
 * indexStartValue is anything you can store as a priority / value.
 */
@property(nonatomic, strong, readwrite) id<FNode> indexStartValue;
@property(nonatomic, strong, readwrite) NSString *indexStartKey;
/**
 * indexStartValue is anything you can store as a priority / value.
 */
@property(nonatomic, strong, readwrite) id<FNode> indexEndValue;
@property(nonatomic, strong, readwrite) NSString *indexEndKey;

@property(nonatomic, strong, readwrite) id<FIndex> index;

@end

@implementation FQueryParams

+ (FQueryParams *)defaultInstance {
    static FQueryParams *defaultParams = nil;
    static dispatch_once_t defaultParamsToken;
    dispatch_once(&defaultParamsToken, ^{
      defaultParams = [[FQueryParams alloc] init];
    });
    return defaultParams;
}

- (id)init {
    self = [super init];
    if (self) {
        self->_limitSet = NO;
        self->_limit = 0;

        self->_viewFrom = nil;
        self->_indexStartValue = nil;
        self->_indexStartKey = nil;
        self->_indexEndValue = nil;
        self->_indexEndKey = nil;

        self->_index = [FPriorityIndex priorityIndex];
    }
    return self;
}

/**
 * Only valid if hasStart is true
 */
- (id)indexStartValue {
    NSAssert([self hasStart], @"Only valid if start has been set");
    return _indexStartValue;
}

/**
 * Only valid if hasStart is true.
 * @return The starting key name for the range defined by these query parameters
 */
- (NSString *)indexStartKey {
    NSAssert([self hasStart], @"Only valid if start has been set");
    if (_indexStartKey == nil) {
        return [FUtilities minName];
    } else {
        return _indexStartKey;
    }
}

/**
 * Only valid if hasEnd is true.
 */
- (id)indexEndValue {
    NSAssert([self hasEnd], @"Only valid if end has been set");
    return _indexEndValue;
}

/**
 * Only valid if hasEnd is true.
 * @return The end key name for the range defined by these query parameters
 */
- (NSString *)indexEndKey {
    NSAssert([self hasEnd], @"Only valid if end has been set");
    if (_indexEndKey == nil) {
        return [FUtilities maxName];
    } else {
        return _indexEndKey;
    }
}

/**
 * @return true if a limit has been set and has been explicitly anchored
 */
- (BOOL)hasAnchoredLimit {
    return self.limitSet && self.viewFrom != nil;
}

/**
 * Only valid to call if limitSet returns true
 */
- (NSInteger)limit {
    NSAssert(self.limitSet, @"Only valid if limit has been set");
    return _limit;
}

- (BOOL)hasStart {
    return self->_indexStartValue != nil;
}

- (BOOL)hasEnd {
    return self->_indexEndValue != nil;
}

- (id)copyWithZone:(NSZone *)zone {
    // Immutable
    return self;
}

- (id)mutableCopy {
    FQueryParams *other = [[[self class] alloc] init];
    // Maybe need to do extra copying here
    other->_limitSet = _limitSet;
    other->_limit = _limit;
    other->_indexStartValue = _indexStartValue;
    other->_indexStartKey = _indexStartKey;
    other->_indexEndValue = _indexEndValue;
    other->_indexEndKey = _indexEndKey;
    other->_viewFrom = _viewFrom;
    other->_index = _index;
    return other;
}

- (FQueryParams *)limitTo:(NSInteger)newLimit {
    FQueryParams *newParams = [self mutableCopy];
    newParams->_limitSet = YES;
    newParams->_limit = newLimit;
    newParams->_viewFrom = nil;
    return newParams;
}

- (FQueryParams *)limitToFirst:(NSInteger)newLimit {
    FQueryParams *newParams = [self mutableCopy];
    newParams->_limitSet = YES;
    newParams->_limit = newLimit;
    newParams->_viewFrom = kFQPViewFromLeft;
    return newParams;
}

- (FQueryParams *)limitToLast:(NSInteger)newLimit {
    FQueryParams *newParams = [self mutableCopy];
    newParams->_limitSet = YES;
    newParams->_limit = newLimit;
    newParams->_viewFrom = kFQPViewFromRight;
    return newParams;
}

- (FQueryParams *)startAt:(id<FNode>)indexValue childKey:(NSString *)key {
    NSAssert([indexValue isLeafNode] || [indexValue isEmpty], nil);
    FQueryParams *newParams = [self mutableCopy];
    newParams->_indexStartValue = indexValue;
    newParams->_indexStartKey = key;
    return newParams;
}

- (FQueryParams *)startAt:(id<FNode>)indexValue {
    return [self startAt:indexValue childKey:nil];
}

- (FQueryParams *)endAt:(id<FNode>)indexValue childKey:(NSString *)key {
    NSAssert([indexValue isLeafNode] || [indexValue isEmpty], nil);
    FQueryParams *newParams = [self mutableCopy];
    newParams->_indexEndValue = indexValue;
    newParams->_indexEndKey = key;
    return newParams;
}

- (FQueryParams *)endAt:(id<FNode>)indexValue {
    return [self endAt:indexValue childKey:nil];
}

- (FQueryParams *)orderBy:(id)newIndex {
    FQueryParams *newParams = [self mutableCopy];
    newParams->_index = newIndex;
    return newParams;
}

- (NSDictionary *)wireProtocolParams {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if ([self hasStart]) {
        [dict setObject:[self.indexStartValue valForExport:YES]
                 forKey:kFQPIndexStartValue];

        // Don't use property as it will be [MIN-NAME]
        if (self->_indexStartKey != nil) {
            [dict setObject:self->_indexStartKey forKey:kFQPIndexStartName];
        }
    }

    if ([self hasEnd]) {
        [dict setObject:[self.indexEndValue valForExport:YES]
                 forKey:kFQPIndexEndValue];

        // Don't use property as it will be [MAX-NAME]
        if (self->_indexEndKey != nil) {
            [dict setObject:self->_indexEndKey forKey:kFQPIndexEndName];
        }
    }

    if (self.limitSet) {
        [dict setObject:[NSNumber numberWithInteger:self.limit]
                 forKey:kFQPLimit];
        NSString *vf = self.viewFrom;
        if (vf == nil) {
            // limit() rather than limitToFirst or limitToLast was called.
            // This means that only one of startSet or endSet is true. Use them
            // to calculate which side of the view to anchor to. If neither is
            // set, Anchor to end
            if ([self hasStart]) {
                vf = kFQPViewFromLeft;
            } else {
                vf = kFQPViewFromRight;
            }
        }
        [dict setObject:vf forKey:kFQPViewFrom];
    }

    // For now, priority index is the default, so we only specify if it's some
    // other index.
    if (![self.index isEqual:[FPriorityIndex priorityIndex]]) {
        [dict setObject:[self.index queryDefinition] forKey:kFQPIndex];
    }

    return dict;
}

+ (FQueryParams *)fromQueryObject:(NSDictionary *)dict {
    if (dict.count == 0) {
        return [FQueryParams defaultInstance];
    }

    FQueryParams *params = [[FQueryParams alloc] init];
    if (dict[kFQPLimit] != nil) {
        params->_limitSet = YES;
        params->_limit = [dict[kFQPLimit] integerValue];
    }

    if (dict[kFQPIndexStartValue] != nil) {
        params->_indexStartValue =
            [FSnapshotUtilities nodeFrom:dict[kFQPIndexStartValue]];
        if (dict[kFQPIndexStartName] != nil) {
            params->_indexStartKey = dict[kFQPIndexStartName];
        }
    }

    if (dict[kFQPIndexEndValue] != nil) {
        params->_indexEndValue =
            [FSnapshotUtilities nodeFrom:dict[kFQPIndexEndValue]];
        if (dict[kFQPIndexEndName] != nil) {
            params->_indexEndKey = dict[kFQPIndexEndName];
        }
    }

    if (dict[kFQPViewFrom] != nil) {
        NSString *viewFrom = dict[kFQPViewFrom];
        if (![viewFrom isEqualToString:kFQPViewFromLeft] &&
            ![viewFrom isEqualToString:kFQPViewFromRight]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"Unknown view from paramter: %@", viewFrom];
        }
        params->_viewFrom = viewFrom;
    }

    NSString *index = dict[kFQPIndex];
    if (index != nil) {
        params->_index = [FIndex indexFromQueryDefinition:index];
    }

    return params;
}

- (BOOL)isViewFromLeft {
    if (self.viewFrom != nil) {
        // Not null, we can just check
        return [self.viewFrom isEqualToString:kFQPViewFromLeft];
    } else {
        // If start is set, it's view from left. Otherwise not.
        return self.hasStart;
    }
}

- (id<FNodeFilter>)nodeFilter {
    if (self.loadsAllData) {
        return [[FIndexedFilter alloc] initWithIndex:self.index];
    } else if (self.limitSet) {
        return [[FLimitedFilter alloc] initWithQueryParams:self];
    } else {
        return [[FRangedFilter alloc] initWithQueryParams:self];
    }
}

- (BOOL)isValid {
    return !(self.hasStart && self.hasEnd && self.limitSet &&
             !self.hasAnchoredLimit);
}

- (BOOL)loadsAllData {
    return !(self.hasStart || self.hasEnd || self.limitSet);
}

- (BOOL)isDefault {
    return [self loadsAllData] &&
           [self.index isEqual:[FPriorityIndex priorityIndex]];
}

- (NSString *)description {
    return [[self wireProtocolParams] description];
}

- (BOOL)isEqual:(id)obj {
    if (self == obj) {
        return YES;
    }
    if (![obj isKindOfClass:[self class]]) {
        return NO;
    }
    FQueryParams *other = (FQueryParams *)obj;
    if (self->_limitSet != other->_limitSet)
        return NO;
    if (self->_limit != other->_limit)
        return NO;
    if ((self->_index != other->_index) &&
        ![self->_index isEqual:other->_index])
        return NO;
    if ((self->_indexStartKey != other->_indexStartKey) &&
        ![self->_indexStartKey isEqualToString:other->_indexStartKey])
        return NO;
    if ((self->_indexStartValue != other->_indexStartValue) &&
        ![self->_indexStartValue isEqual:other->_indexStartValue])
        return NO;
    if ((self->_indexEndKey != other->_indexEndKey) &&
        ![self->_indexEndKey isEqualToString:other->_indexEndKey])
        return NO;
    if ((self->_indexEndValue != other->_indexEndValue) &&
        ![self->_indexEndValue isEqual:other->_indexEndValue])
        return NO;
    if ([self isViewFromLeft] != [other isViewFromLeft])
        return NO;

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = _limitSet ? _limit : 0;
    result = 31 * result + ([self isViewFromLeft] ? 1231 : 1237);
    result = 31 * result + [_indexStartKey hash];
    result = 31 * result + [_indexStartValue hash];
    result = 31 * result + [_indexEndKey hash];
    result = 31 * result + [_indexEndValue hash];
    result = 31 * result + [_index hash];
    return result;
}

@end
