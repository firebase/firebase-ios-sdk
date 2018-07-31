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

#import "FIRDatabaseQuery.h"
#import "FIRDatabaseQuery_Private.h"
#import "FValidation.h"
#import "FQueryParams.h"
#import "FQuerySpec.h"
#import "FValueEventRegistration.h"
#import "FChildEventRegistration.h"
#import "FPath.h"
#import "FKeyIndex.h"
#import "FPathIndex.h"
#import "FPriorityIndex.h"
#import "FValueIndex.h"
#import "FLeafNode.h"
#import "FSnapshotUtilities.h"
#import "FConstants.h"

@implementation FIRDatabaseQuery

@synthesize repo;
@synthesize path;
@synthesize queryParams;

#define INVALID_QUERY_PARAM_ERROR @"InvalidQueryParameter"


+ (dispatch_queue_t)sharedQueue
{
    // We use this shared queue across all of the FQueries so things happen FIFO (as opposed to dispatch_get_global_queue(0, 0) which is concurrent)
    static dispatch_once_t pred;
    static dispatch_queue_t sharedDispatchQueue;

    dispatch_once(&pred, ^{
        sharedDispatchQueue = dispatch_queue_create("FirebaseWorker", NULL);
    });

    return sharedDispatchQueue;
}

- (id) initWithRepo:(FRepo *)theRepo path:(FPath *)thePath {
    return [self initWithRepo:theRepo path:thePath params:nil orderByCalled:NO priorityMethodCalled:NO];
}

- (id) initWithRepo:(FRepo *)theRepo
               path:(FPath *)thePath
             params:(FQueryParams *)theParams
      orderByCalled:(BOOL)orderByCalled
priorityMethodCalled:(BOOL)priorityMethodCalled {
    self = [super init];
    if (self) {
        self.repo = theRepo;
        self.path = thePath;
        if (!theParams) {
            theParams = [FQueryParams defaultInstance];
        }
        if (![theParams isValid]) {
            @throw [[NSException alloc] initWithName:@"InvalidArgumentError" reason:@"Queries are limited to two constraints" userInfo:nil];
        }
        self.queryParams = theParams;
        self.orderByCalled = orderByCalled;
        self.priorityMethodCalled = priorityMethodCalled;
    }
    return self;
}

- (FQuerySpec *)querySpec {
    return [[FQuerySpec alloc] initWithPath:self.path params:self.queryParams];
}

- (void)validateQueryEndpointsForParams:(FQueryParams *)params {
    if ([params.index isEqual:[FKeyIndex keyIndex]]) {
        if ([params hasStart]) {
            if (params.indexStartKey != [FUtilities minName]) {
                [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Can't use queryStartingAtValue:childKey: or queryEqualTo:andChildKey: in combination with queryOrderedByKey"];
            }
            if (![params.indexStartValue.val isKindOfClass:[NSString class]]) {
                [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Can't use queryStartingAtValue: with other types than string in combination with queryOrderedByKey"];
            }
        }
        if ([params hasEnd]) {
            if (params.indexEndKey != [FUtilities maxName]) {
                [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Can't use queryEndingAtValue:childKey: or queryEqualToValue:childKey: in combination with queryOrderedByKey"];
            }
            if (![params.indexEndValue.val isKindOfClass:[NSString class]]) {
                [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Can't use queryEndingAtValue: with other types than string in combination with queryOrderedByKey"];
            }
        }
    } else if ([params.index isEqual:[FPriorityIndex priorityIndex]]) {
        if (([params hasStart] && ![FValidation validatePriorityValue:params.indexStartValue.val]) ||
            ([params hasEnd] && ![FValidation validatePriorityValue:params.indexEndValue.val])) {
            [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"When using queryOrderedByPriority, values provided to queryStartingAtValue:, queryEndingAtValue:, or queryEqualToValue: must be valid priorities."];
        }
    }
}

- (void)validateEqualToCall {
    if ([self.queryParams hasStart]) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Cannot combine queryEqualToValue: and queryStartingAtValue:"];
    }
    if ([self.queryParams hasEnd]) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Cannot combine queryEqualToValue: and queryEndingAtValue:"];
    }
}

- (void)validateNoPreviousOrderByCalled {
    if (self.orderByCalled) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Cannot use multiple queryOrderedBy calls!"];
    }
}

- (void)validateIndexValueType:(id)type fromMethod:(NSString *)method {
    if (type != nil &&
        ![type isKindOfClass:[NSNumber class]] &&
        ![type isKindOfClass:[NSString class]] &&
        ![type isKindOfClass:[NSNull class]]) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"You can only pass nil, NSString or NSNumber to %@", method];
    }
}

- (FIRDatabaseQuery *)queryStartingAtValue:(id)startValue {
    return [self queryStartingAtInternal:startValue childKey:nil from:@"queryStartingAtValue:" priorityMethod:NO];
}

- (FIRDatabaseQuery *)queryStartingAtValue:(id)startValue childKey:(NSString *)childKey {
    if ([self.queryParams.index isEqual:[FKeyIndex keyIndex]]) {
        @throw [[NSException alloc] initWithName:INVALID_QUERY_PARAM_ERROR
                                          reason:@"You must use queryStartingAtValue: instead of queryStartingAtValue:childKey: when using queryOrderedByKey:"
                                        userInfo:nil];
    }
    return [self queryStartingAtInternal:startValue
                                childKey:childKey
                                    from:@"queryStartingAtValue:childKey:"
                          priorityMethod:NO];
}

- (FIRDatabaseQuery *)queryStartingAtInternal:(id<FNode>)startValue
                                     childKey:(NSString *)childKey
                                         from:(NSString *)methodName
                               priorityMethod:(BOOL)priorityMethod {
    [self validateIndexValueType:startValue fromMethod:methodName];
    if (childKey != nil) {
         [FValidation validateFrom:methodName validKey:childKey];
    }
    if ([self.queryParams hasStart]) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR
                    format:@"Can't call %@ after queryStartingAtValue or queryEqualToValue was previously called", methodName];
    }
    id<FNode> startNode = [FSnapshotUtilities nodeFrom:startValue];
    FQueryParams* params = [self.queryParams startAt:startNode childKey:childKey];
    [self validateQueryEndpointsForParams:params];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:self.orderByCalled
                             priorityMethodCalled:priorityMethod || self.priorityMethodCalled];
}

- (FIRDatabaseQuery *)queryEndingAtValue:(id)endValue {
    return [self queryEndingAtInternal:endValue
                              childKey:nil
                                  from:@"queryEndingAtValue:"
                        priorityMethod:NO];
}

- (FIRDatabaseQuery *)queryEndingAtValue:(id)endValue childKey:(NSString *)childKey {
    if ([self.queryParams.index isEqual:[FKeyIndex keyIndex]]) {
        @throw [[NSException alloc] initWithName:INVALID_QUERY_PARAM_ERROR
                                          reason:@"You must use queryEndingAtValue: instead of queryEndingAtValue:childKey: when using queryOrderedByKey:"
                                        userInfo:nil];
    }

    return [self queryEndingAtInternal:endValue
                           childKey:childKey
                                  from:@"queryEndingAtValue:childKey:"
                        priorityMethod:NO];
}

- (FIRDatabaseQuery *)queryEndingAtInternal:(id)endValue
                                   childKey:(NSString *)childKey
                                       from:(NSString *)methodName
                             priorityMethod:(BOOL)priorityMethod {
    [self validateIndexValueType:endValue fromMethod:methodName];
    if (childKey != nil) {
        [FValidation validateFrom:methodName validKey:childKey];
    }
    if ([self.queryParams hasEnd]) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR
                    format:@"Can't call %@ after queryEndingAtValue or queryEqualToValue was previously called", methodName];
    }
    id<FNode> endNode = [FSnapshotUtilities nodeFrom:endValue];
    FQueryParams* params = [self.queryParams endAt:endNode childKey:childKey];
    [self validateQueryEndpointsForParams:params];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:self.orderByCalled
                             priorityMethodCalled:priorityMethod || self.priorityMethodCalled];
}

- (FIRDatabaseQuery *)queryEqualToValue:(id)value {
    return [self queryEqualToInternal:value childKey:nil from:@"queryEqualToValue:" priorityMethod:NO];
}

- (FIRDatabaseQuery *)queryEqualToValue:(id)value childKey:(NSString *)childKey {
    if ([self.queryParams.index isEqual:[FKeyIndex keyIndex]]) {
        @throw [[NSException alloc] initWithName:INVALID_QUERY_PARAM_ERROR
                                          reason:@"You must use queryEqualToValue: instead of queryEqualTo:childKey: when using queryOrderedByKey:"
                                        userInfo:nil];
    }
    return [self queryEqualToInternal:value childKey:childKey from:@"queryEqualToValue:childKey:" priorityMethod:NO];
}

- (FIRDatabaseQuery *)queryEqualToInternal:(id)value
                                  childKey:(NSString *)childKey
                                      from:(NSString *)methodName
                            priorityMethod:(BOOL)priorityMethod {
    [self validateIndexValueType:value fromMethod:methodName];
    if (childKey != nil) {
        [FValidation validateFrom:methodName validKey:childKey];
    }
    if ([self.queryParams hasEnd] || [self.queryParams hasStart]) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR
                    format:@"Can't call %@ after queryStartingAtValue, queryEndingAtValue or queryEqualToValue was previously called", methodName];
    }
    id<FNode> node = [FSnapshotUtilities nodeFrom:value];
    FQueryParams* params = [[self.queryParams startAt:node childKey:childKey] endAt:node childKey:childKey];
    [self validateQueryEndpointsForParams:params];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:self.orderByCalled
                             priorityMethodCalled:priorityMethod || self.priorityMethodCalled];
}

- (void)validateLimitRange:(NSUInteger)limit
{
    // No need to check for negative ranges, since limit is unsigned
    if (limit == 0) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Limit can't be zero"];
    }
    if (limit >= 1ul<<31) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Limit must be less than 2,147,483,648"];
    }
}

- (FIRDatabaseQuery *)queryLimitedToFirst:(NSUInteger)limit {
    if (self.queryParams.limitSet) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Can't call queryLimitedToFirst: if a limit was previously set"];
    }
    [self validateLimitRange:limit];
    FQueryParams* params = [self.queryParams limitToFirst:limit];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:self.orderByCalled
                             priorityMethodCalled:self.priorityMethodCalled];
}

- (FIRDatabaseQuery *)queryLimitedToLast:(NSUInteger)limit {
    if (self.queryParams.limitSet) {
        [NSException raise:INVALID_QUERY_PARAM_ERROR format:@"Can't call queryLimitedToLast: if a limit was previously set"];
    }
    [self validateLimitRange:limit];
    FQueryParams* params = [self.queryParams limitToLast:limit];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:self.orderByCalled
                             priorityMethodCalled:self.priorityMethodCalled];
}

- (FIRDatabaseQuery *)queryOrderedByChild:(NSString *)indexPathString {
    if ([indexPathString isEqualToString:@"$key"] || [indexPathString isEqualToString:@".key"]) {
        @throw [[NSException alloc] initWithName:INVALID_QUERY_PARAM_ERROR
                                          reason:[NSString stringWithFormat:@"(queryOrderedByChild:) %@ is invalid.  Use queryOrderedByKey: instead.", indexPathString]
                                        userInfo:nil];
    } else if ([indexPathString isEqualToString:@"$priority"] || [indexPathString isEqualToString:@".priority"]) {
        @throw [[NSException alloc] initWithName:INVALID_QUERY_PARAM_ERROR
                                          reason:[NSString stringWithFormat:@"(queryOrderedByChild:) %@ is invalid.  Use queryOrderedByPriority: instead.", indexPathString]
                                        userInfo:nil];
    } else if ([indexPathString isEqualToString:@"$value"] || [indexPathString isEqualToString:@".value"]) {
        @throw [[NSException alloc] initWithName:INVALID_QUERY_PARAM_ERROR
                                          reason:[NSString stringWithFormat:@"(queryOrderedByChild:) %@ is invalid.  Use queryOrderedByValue: instead.", indexPathString]
                                        userInfo:nil];
    }
    [self validateNoPreviousOrderByCalled];

    [FValidation validateFrom:@"queryOrderedByChild:" validPathString:indexPathString];
    FPath *indexPath = [FPath pathWithString:indexPathString];
    if (indexPath.isEmpty) {
        @throw [[NSException alloc] initWithName:INVALID_QUERY_PARAM_ERROR
                                          reason:[NSString stringWithFormat:@"(queryOrderedByChild:) with an empty path is invalid.  Use queryOrderedByValue: instead."]
                                        userInfo:nil];
    }
    id<FIndex> index = [[FPathIndex alloc] initWithPath:indexPath];

    FQueryParams *params = [self.queryParams orderBy:index];
    [self validateQueryEndpointsForParams:params];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:YES
                             priorityMethodCalled:self.priorityMethodCalled];
}

- (FIRDatabaseQuery *) queryOrderedByKey {
    [self validateNoPreviousOrderByCalled];
    FQueryParams *params = [self.queryParams orderBy:[FKeyIndex keyIndex]];
    [self validateQueryEndpointsForParams:params];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:YES
                             priorityMethodCalled:self.priorityMethodCalled];
}

- (FIRDatabaseQuery *) queryOrderedByValue {
    [self validateNoPreviousOrderByCalled];
    FQueryParams *params = [self.queryParams orderBy:[FValueIndex valueIndex]];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:YES
                             priorityMethodCalled:self.priorityMethodCalled];
}

- (FIRDatabaseQuery *) queryOrderedByPriority {
    [self validateNoPreviousOrderByCalled];
    FQueryParams *params = [self.queryParams orderBy:[FPriorityIndex priorityIndex]];
    return [[FIRDatabaseQuery alloc] initWithRepo:self.repo
                                             path:self.path
                                           params:params
                                    orderByCalled:YES
                             priorityMethodCalled:self.priorityMethodCalled];
}

- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType withBlock:(void (^)(FIRDataSnapshot *))block {
    [FValidation validateFrom:@"observeEventType:withBlock:" knownEventType:eventType];
    return [self observeEventType:eventType withBlock:block withCancelBlock:nil];
}


- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block {
    [FValidation validateFrom:@"observeEventType:andPreviousSiblingKeyWithBlock:" knownEventType:eventType];
    return [self observeEventType:eventType andPreviousSiblingKeyWithBlock:block withCancelBlock:nil];
}


- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType withBlock:(fbt_void_datasnapshot)block withCancelBlock:(fbt_void_nserror)cancelBlock {
    [FValidation validateFrom:@"observeEventType:withBlock:withCancelBlock:" knownEventType:eventType];

    if (eventType == FIRDataEventTypeValue) {
        // Handle FIRDataEventTypeValue specially because they shouldn't have prevName callbacks
        NSUInteger handle = [[FUtilities LUIDGenerator] integerValue];
        [self observeValueEventWithHandle:handle withBlock:block cancelCallback:cancelBlock];
        return handle;
    } else {
        // Wrap up the userCallback so we can treat everything as a callback that has a prevName
        fbt_void_datasnapshot userCallback = [block copy];
        return [self observeEventType:eventType andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
            if (userCallback != nil) {
                userCallback(snapshot);
            }
        } withCancelBlock:cancelBlock];
    }
}

- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block withCancelBlock:(fbt_void_nserror)cancelBlock {
    [FValidation validateFrom:@"observeEventType:andPreviousSiblingKeyWithBlock:withCancelBlock:" knownEventType:eventType];


    if (eventType == FIRDataEventTypeValue) {
        // TODO: This gets hit by observeSingleEventOfType.  Need to fix.
        /*
        @throw [[NSException alloc] initWithName:@"InvalidEventTypeForObserver"
                                          reason:@"(observeEventType:andPreviousSiblingKeyWithBlock:withCancelBlock:) Cannot use observeEventType:andPreviousSiblingKeyWithBlock:withCancelBlock: with FIRDataEventTypeValue. Use observeEventType:withBlock:withCancelBlock: instead."
                                        userInfo:nil];
        */
    }

    NSUInteger handle = [[FUtilities LUIDGenerator] integerValue];
    NSDictionary *callbacks = @{[NSNumber numberWithInteger:eventType]: [block copy]};
    [self observeChildEventWithHandle:handle withCallbacks:callbacks cancelCallback:cancelBlock];

    return handle;
}

// If we want to distinguish between value event listeners and child event listeners, like in the Java client, we can
// consider exporting this. If we do, add argument validation. Otherwise, arguments are validated in the public-facing
// portions of the API. Also, move the FIRDatabaseHandle logic.
- (void)observeValueEventWithHandle:(FIRDatabaseHandle)handle withBlock:(fbt_void_datasnapshot)block cancelCallback:(fbt_void_nserror)cancelBlock {
    // Note that we don't need to copy the callbacks here, FEventRegistration callback properties set to copy
    FValueEventRegistration *registration = [[FValueEventRegistration alloc] initWithRepo:self.repo
                                                                                   handle:handle
                                                                                 callback:block
                                                                           cancelCallback:cancelBlock];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
        [self.repo addEventRegistration:registration forQuery:self.querySpec];
    });
}

// Note: as with the above method, we may wish to expose this at some point.
- (void)observeChildEventWithHandle:(FIRDatabaseHandle)handle withCallbacks:(NSDictionary *)callbacks cancelCallback:(fbt_void_nserror)cancelBlock {
    // Note that we don't need to copy the callbacks here, FEventRegistration callback properties set to copy
    FChildEventRegistration *registration = [[FChildEventRegistration alloc] initWithRepo:self.repo
                                                                                   handle:handle
                                                                                callbacks:callbacks
                                                                           cancelCallback:cancelBlock];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
        [self.repo addEventRegistration:registration forQuery:self.querySpec];
    });
}


- (void) removeObserverWithHandle:(FIRDatabaseHandle)handle {
    FValueEventRegistration *event = [[FValueEventRegistration alloc] initWithRepo:self.repo
                                                                            handle:handle
                                                                          callback:nil
                                                                    cancelCallback:nil];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
        [self.repo removeEventRegistration:event forQuery:self.querySpec];
    });
}


- (void) removeAllObservers {
    [self removeObserverWithHandle:NSNotFound];
}

- (void)keepSynced:(BOOL)keepSynced {
    if ([self.path.getFront isEqualToString:kDotInfoPrefix]) {
        [NSException raise:NSInvalidArgumentException format:@"Can't keep query on .info tree synced (this already is the case)."];
    }
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
        [self.repo keepQuery:self.querySpec synced:keepSynced];
    });
}

- (void)observeSingleEventOfType:(FIRDataEventType)eventType withBlock:(fbt_void_datasnapshot)block {

    [self observeSingleEventOfType:eventType withBlock:block withCancelBlock:nil];
}


- (void)observeSingleEventOfType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block {

    [self observeSingleEventOfType:eventType andPreviousSiblingKeyWithBlock:block withCancelBlock:nil];
}


- (void)observeSingleEventOfType:(FIRDataEventType)eventType withBlock:(fbt_void_datasnapshot)block withCancelBlock:(fbt_void_nserror)cancelBlock {

    // XXX: user reported memory leak in method

    // "When you copy a block, any references to other blocks from within that block are copied if necessary—an entire tree may be copied (from the top). If you have block variables and you reference a block from within the block, that block will be copied."
    // http://developer.apple.com/library/ios/#documentation/cocoa/Conceptual/Blocks/Articles/bxVariables.html#//apple_ref/doc/uid/TP40007502-CH6-SW1
    // So... we don't need to do this since inside the on: we copy this block off the stack to the heap.
    // __block fbt_void_datasnapshot userCallback = [callback copy];

    [self observeSingleEventOfType:eventType andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
        if (block != nil) {
            block(snapshot);
        }
    } withCancelBlock:cancelBlock];
}

/**
* Attaches a listener, waits for the first event, and then removes the listener
*/
- (void)observeSingleEventOfType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block withCancelBlock:(fbt_void_nserror)cancelBlock {

    // XXX: user reported memory leak in method

    // "When you copy a block, any references to other blocks from within that block are copied if necessary—an entire tree may be copied (from the top). If you have block variables and you reference a block from within the block, that block will be copied."
    // http://developer.apple.com/library/ios/#documentation/cocoa/Conceptual/Blocks/Articles/bxVariables.html#//apple_ref/doc/uid/TP40007502-CH6-SW1
    // So... we don't need to do this since inside the on: we copy this block off the stack to the heap.
    // __block fbt_void_datasnapshot userCallback = [callback copy];

    __block FIRDatabaseHandle handle;
    __block BOOL firstCall = YES;

    fbt_void_datasnapshot_nsstring callback = [block copy];
    fbt_void_datasnapshot_nsstring wrappedCallback = ^(FIRDataSnapshot *snap, NSString* prevName) {
        if (firstCall) {
            firstCall = NO;
            [self removeObserverWithHandle:handle];
            callback(snap, prevName);
        }
    };

    fbt_void_nserror cancelCallback = [cancelBlock copy];
    handle = [self observeEventType:eventType andPreviousSiblingKeyWithBlock:wrappedCallback withCancelBlock:^(NSError* error){

        [self removeObserverWithHandle:handle];

        if (cancelCallback) {
            cancelCallback(error);
        }
    }];
}

- (NSString *) description {
    return [NSString stringWithFormat:@"(%@ %@)", self.path, self.queryParams.description];
}

- (FIRDatabaseReference *) ref {
    return [[FIRDatabaseReference alloc] initWithRepo:self.repo path:self.path];
}

@end
