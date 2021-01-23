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

#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseReference.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Api/FIRDatabaseConfig.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseReference_Private.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabase.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FNextPushId.h"
#import "FirebaseDatabase/Sources/Utilities/FStringUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FValidation.h"

@implementation FIRDatabaseReference

#pragma mark -
#pragma mark Constructors

- (id)initWithConfig:(FIRDatabaseConfig *)config {
    FParsedUrl *parsedUrl =
        [FUtilities parseUrl:[[FIRApp defaultApp] options].databaseURL];
    [FValidation validateFrom:@"initWithUrl:" validURL:parsedUrl];
    return [self initWithRepo:[FRepoManager getRepo:parsedUrl.repoInfo
                                             config:config]
                         path:parsedUrl.path];
}

- (id)initWithRepo:(FRepo *)repo path:(FPath *)path {
    return [super initWithRepo:repo
                          path:path
                        params:[FQueryParams defaultInstance]
                 orderByCalled:NO
          priorityMethodCalled:NO];
}

#pragma mark -
#pragma mark Ancillary methods

- (nullable NSString *)key {
    if ([self.path isEmpty]) {
        return nil;
    } else {
        return [self.path getBack];
    }
}

- (FIRDatabase *)database {
    return self.repo.database;
}

- (FIRDatabaseReference *)parent {
    FPath *parentPath = [self.path parent];
    FIRDatabaseReference *parent = nil;
    if (parentPath != nil) {
        parent = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                       path:parentPath];
    }
    return parent;
}

- (NSString *)URL {
    FIRDatabaseReference *parent = [self parent];
    return parent == nil
               ? [self.repo description]
               : [NSString
                     stringWithFormat:@"%@/%@", [parent description],
                                      [FStringUtilities urlEncoded:self.key]];
}

- (NSString *)description {
    return [self URL];
}

- (FIRDatabaseReference *)root {
    return [[FIRDatabaseReference alloc]
        initWithRepo:self.repo
                path:[[FPath alloc] initWith:@""]];
}

#pragma mark -
#pragma mark Child methods

- (FIRDatabaseReference *)child:(NSString *)pathString {
    if ([self.path getFront] == nil) {
        // we're at the root
        [FValidation validateFrom:@"child:" validRootPathString:pathString];
    } else {
        [FValidation validateFrom:@"child:" validPathString:pathString];
    }
    FPath *path = [self.path childFromString:pathString];
    FIRDatabaseReference *firebaseRef =
        [[FIRDatabaseReference alloc] initWithRepo:self.repo path:path];
    return firebaseRef;
}

- (FIRDatabaseReference *)childByAutoId {
    [FValidation validateFrom:@"childByAutoId:" writablePath:self.path];

    NSString *name = [FNextPushId get:self.repo.serverTime];
    return [self child:name];
}

#pragma mark -
#pragma mark Basic write methods

- (void)setValue:(id)value {
    [self setValueInternal:value
                andPriority:nil
        withCompletionBlock:nil
                       from:@"setValue:"];
}

- (void)setValue:(id)value withCompletionBlock:(fbt_void_nserror_ref)block {
    [self setValueInternal:value
                andPriority:nil
        withCompletionBlock:block
                       from:@"setValue:withCompletionBlock:"];
}

- (void)setValue:(id)value andPriority:(id)priority {
    [self setValueInternal:value
                andPriority:priority
        withCompletionBlock:nil
                       from:@"setValue:andPriority:"];
}

- (void)setValue:(id)value
            andPriority:(id)priority
    withCompletionBlock:(fbt_void_nserror_ref)block {
    [self setValueInternal:value
                andPriority:priority
        withCompletionBlock:block
                       from:@"setValue:andPriority:withCompletionBlock:"];
}

- (void)setValueInternal:(id)value
             andPriority:(id)priority
     withCompletionBlock:(fbt_void_nserror_ref)block
                    from:(NSString *)fn {
    [FValidation validateFrom:fn writablePath:self.path];

    fbt_void_nserror_ref userCallback = [block copy];
    id<FNode> newNode = [FSnapshotUtilities nodeFrom:value
                                            priority:priority
                                  withValidationFrom:fn];

    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self.repo set:self.path withNode:newNode withCallback:userCallback];
    });
}

- (void)removeValue {
    [self setValueInternal:nil
                andPriority:nil
        withCompletionBlock:nil
                       from:@"removeValue:"];
}

- (void)removeValueWithCompletionBlock:(fbt_void_nserror_ref)block {
    [self setValueInternal:nil
                andPriority:nil
        withCompletionBlock:block
                       from:@"removeValueWithCompletionBlock:"];
}

- (void)setPriority:(id)priority {
    [self setPriorityInternal:priority
          withCompletionBlock:nil
                         from:@"setPriority:"];
}

- (void)setPriority:(id)priority
    withCompletionBlock:(fbt_void_nserror_ref)block {

    [self setPriorityInternal:priority
          withCompletionBlock:block
                         from:@"setPriority:withCompletionBlock:"];
}

- (void)setPriorityInternal:(id)priority
        withCompletionBlock:(fbt_void_nserror_ref)block
                       from:(NSString *)fn {
    [FValidation validateFrom:fn writablePath:self.path];

    fbt_void_nserror_ref userCallback = [block copy];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self.repo set:[self.path childFromString:@".priority"]
              withNode:[FSnapshotUtilities nodeFrom:priority]
          withCallback:userCallback];
    });
}

- (void)updateChildValues:(NSDictionary *)values {
    [self updateChildValuesInternal:values
                withCompletionBlock:nil
                               from:@"updateChildValues:"];
}

- (void)updateChildValues:(NSDictionary *)values
      withCompletionBlock:(fbt_void_nserror_ref)block {
    [self updateChildValuesInternal:values
                withCompletionBlock:block
                               from:@"updateChildValues:withCompletionBlock:"];
}

- (void)updateChildValuesInternal:(NSDictionary *)values
              withCompletionBlock:(fbt_void_nserror_ref)block
                             from:(NSString *)fn {
    [FValidation validateFrom:fn writablePath:self.path];

    FCompoundWrite *merge =
        [FSnapshotUtilities compoundWriteFromDictionary:values
                                     withValidationFrom:fn];

    fbt_void_nserror_ref userCallback = [block copy];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self.repo update:self.path withNodes:merge withCallback:userCallback];
    });
}

#pragma mark -
#pragma mark Disconnect Operations

- (void)onDisconnectSetValue:(id)value {
    [self onDisconnectSetValueInternal:value
                           andPriority:nil
                   withCompletionBlock:nil
                                  from:@"onDisconnectSetValue:"];
}

- (void)onDisconnectSetValue:(id)value
         withCompletionBlock:(fbt_void_nserror_ref)block {
    [self onDisconnectSetValueInternal:value
                           andPriority:nil
                   withCompletionBlock:block
                                  from:@"onDisconnectSetValue:"
                                       @"withCompletionBlock:"];
}

- (void)onDisconnectSetValue:(id)value andPriority:(id)priority {
    [self onDisconnectSetValueInternal:value
                           andPriority:priority
                   withCompletionBlock:nil
                                  from:@"onDisconnectSetValue:andPriority:"];
}

- (void)onDisconnectSetValue:(id)value
                 andPriority:(id)priority
         withCompletionBlock:(fbt_void_nserror_ref)block {
    [self onDisconnectSetValueInternal:value
                           andPriority:priority
                   withCompletionBlock:block
                                  from:@"onDisconnectSetValue:andPriority:"
                                       @"withCompletionBlock:"];
}

- (void)onDisconnectSetValueInternal:(id)value
                         andPriority:(id)priority
                 withCompletionBlock:(fbt_void_nserror_ref)block
                                from:(NSString *)fn {
    [FValidation validateFrom:fn writablePath:self.path];

    id<FNode> newNodeUnresolved = [FSnapshotUtilities nodeFrom:value
                                                      priority:priority
                                            withValidationFrom:fn];

    fbt_void_nserror_ref userCallback = [block copy];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self.repo onDisconnectSet:self.path
                        withNode:newNodeUnresolved
                    withCallback:userCallback];
    });
}

- (void)onDisconnectRemoveValue {
    [self onDisconnectSetValueInternal:nil
                           andPriority:nil
                   withCompletionBlock:nil
                                  from:@"onDisconnectRemoveValue:"];
}

- (void)onDisconnectRemoveValueWithCompletionBlock:(fbt_void_nserror_ref)block {
    [self onDisconnectSetValueInternal:nil
                           andPriority:nil
                   withCompletionBlock:block
                                  from:@"onDisconnectRemoveValueWithCompletionB"
                                       @"lock:"];
}

- (void)onDisconnectUpdateChildValues:(NSDictionary *)values {
    [self
        onDisconnectUpdateChildValuesInternal:values
                          withCompletionBlock:nil
                                         from:
                                             @"onDisconnectUpdateChildValues:"];
}

- (void)onDisconnectUpdateChildValues:(NSDictionary *)values
                  withCompletionBlock:(fbt_void_nserror_ref)block {
    [self onDisconnectUpdateChildValuesInternal:values
                            withCompletionBlock:block
                                           from:@"onDisconnectUpdateChildValues"
                                                @":withCompletionBlock:"];
}

- (void)onDisconnectUpdateChildValuesInternal:(NSDictionary *)values
                          withCompletionBlock:(fbt_void_nserror_ref)block
                                         from:(NSString *)fn {
    [FValidation validateFrom:fn writablePath:self.path];

    FCompoundWrite *merge =
        [FSnapshotUtilities compoundWriteFromDictionary:values
                                     withValidationFrom:fn];

    fbt_void_nserror_ref userCallback = [block copy];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self.repo onDisconnectUpdate:self.path
                          withNodes:merge
                       withCallback:userCallback];
    });
}

- (void)cancelDisconnectOperations {
    [self cancelDisconnectOperationsWithCompletionBlock:nil];
}

- (void)cancelDisconnectOperationsWithCompletionBlock:
    (fbt_void_nserror_ref)block {
    fbt_void_nserror_ref callback = nil;
    if (block != nil) {
        callback = [block copy];
    }
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self.repo onDisconnectCancel:self.path withCallback:callback];
    });
}

#pragma mark -
#pragma mark Connection management methods

+ (void)goOffline {
    [FRepoManager interruptAll];
}

+ (void)goOnline {
    [FRepoManager resumeAll];
}

#pragma mark -
#pragma mark Data reading methods deferred to FQuery

- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType
                            withBlock:(fbt_void_datasnapshot)block {
    return [self observeEventType:eventType
                        withBlock:block
                  withCancelBlock:nil];
}

- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType
       andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block {
    return [self observeEventType:eventType
        andPreviousSiblingKeyWithBlock:block
                       withCancelBlock:nil];
}

- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType
                            withBlock:(fbt_void_datasnapshot)block
                      withCancelBlock:(fbt_void_nserror)cancelBlock {
    return [super observeEventType:eventType
                         withBlock:block
                   withCancelBlock:cancelBlock];
}

- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType
       andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block
                      withCancelBlock:(fbt_void_nserror)cancelBlock {
    return [super observeEventType:eventType
        andPreviousSiblingKeyWithBlock:block
                       withCancelBlock:cancelBlock];
}

- (void)removeObserverWithHandle:(FIRDatabaseHandle)handle {
    [super removeObserverWithHandle:handle];
}

- (void)removeAllObservers {
    [super removeAllObservers];
}

- (void)keepSynced:(BOOL)keepSynced {
    [super keepSynced:keepSynced];
}

- (void)observeSingleEventOfType:(FIRDataEventType)eventType
                       withBlock:(fbt_void_datasnapshot)block {
    [self observeSingleEventOfType:eventType
                         withBlock:block
                   withCancelBlock:nil];
}

- (void)observeSingleEventOfType:(FIRDataEventType)eventType
    andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block {
    [self observeSingleEventOfType:eventType
        andPreviousSiblingKeyWithBlock:block
                       withCancelBlock:nil];
}

- (void)observeSingleEventOfType:(FIRDataEventType)eventType
                       withBlock:(fbt_void_datasnapshot)block
                 withCancelBlock:(fbt_void_nserror)cancelBlock {
    [super observeSingleEventOfType:eventType
                          withBlock:block
                    withCancelBlock:cancelBlock];
}

- (void)observeSingleEventOfType:(FIRDataEventType)eventType
    andPreviousSiblingKeyWithBlock:(fbt_void_datasnapshot_nsstring)block
                   withCancelBlock:(fbt_void_nserror)cancelBlock {
    [super observeSingleEventOfType:eventType
        andPreviousSiblingKeyWithBlock:block
                       withCancelBlock:cancelBlock];
}

#pragma mark -
#pragma mark Query methods
// These methods suppress warnings from having method definitions in
// FIRDatabaseReference.h for docs generation.

- (FIRDatabaseQuery *)queryLimitedToFirst:(NSUInteger)limit {
    return [super queryLimitedToFirst:limit];
}

- (FIRDatabaseQuery *)queryLimitedToLast:(NSUInteger)limit {
    return [super queryLimitedToLast:limit];
}

- (FIRDatabaseQuery *)queryOrderedByChild:(NSString *)key {
    return [super queryOrderedByChild:key];
}

- (FIRDatabaseQuery *)queryOrderedByKey {
    return [super queryOrderedByKey];
}

- (FIRDatabaseQuery *)queryOrderedByPriority {
    return [super queryOrderedByPriority];
}

- (FIRDatabaseQuery *)queryStartingAtValue:(id)startValue {
    return [super queryStartingAtValue:startValue];
}

- (FIRDatabaseQuery *)queryStartingAtValue:(id)startValue
                                  childKey:(NSString *)childKey {
    return [super queryStartingAtValue:startValue childKey:childKey];
}

- (FIRDatabaseQuery *)queryStartingAfterValue:(id)startAfterValue {
    return [super queryStartingAfterValue:startAfterValue];
}

- (FIRDatabaseQuery *)queryStartingAfterValue:(id)startAfterValue
                                     childKey:(NSString *)childKey {
    return [super queryStartingAfterValue:startAfterValue childKey:childKey];
}

- (FIRDatabaseQuery *)queryEndingAtValue:(id)endValue {
    return [super queryEndingAtValue:endValue];
}

- (FIRDatabaseQuery *)queryEndingAtValue:(id)endValue
                                childKey:(NSString *)childKey {
    return [super queryEndingAtValue:endValue childKey:childKey];
}

- (FIRDatabaseQuery *)queryEqualToValue:(id)value {
    return [super queryEqualToValue:value];
}

- (FIRDatabaseQuery *)queryEqualToValue:(id)value
                               childKey:(NSString *)childKey {
    return [super queryEqualToValue:value childKey:childKey];
}

#pragma mark -
#pragma mark Transaction methods

- (void)runTransactionBlock:(fbt_transactionresult_mutabledata)block {
    [FValidation validateFrom:@"runTransactionBlock:" writablePath:self.path];
    [self runTransactionBlock:block andCompletionBlock:nil withLocalEvents:YES];
}

- (void)runTransactionBlock:(fbt_transactionresult_mutabledata)update
         andCompletionBlock:
             (fbt_void_nserror_bool_datasnapshot)completionBlock {
    [FValidation validateFrom:@"runTransactionBlock:andCompletionBlock:"
                 writablePath:self.path];
    [self runTransactionBlock:update
           andCompletionBlock:completionBlock
              withLocalEvents:YES];
}

- (void)runTransactionBlock:(fbt_transactionresult_mutabledata)block
         andCompletionBlock:(fbt_void_nserror_bool_datasnapshot)completionBlock
            withLocalEvents:(BOOL)localEvents {
    [FValidation
        validateFrom:@"runTransactionBlock:andCompletionBlock:withLocalEvents:"
        writablePath:self.path];
    fbt_transactionresult_mutabledata updateCopy = [block copy];
    fbt_void_nserror_bool_datasnapshot onCompleteCopy = [completionBlock copy];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self.repo startTransactionOnPath:self.path
                                 update:updateCopy
                             onComplete:onCompleteCopy
                        withLocalEvents:localEvents];
    });
}

@end
