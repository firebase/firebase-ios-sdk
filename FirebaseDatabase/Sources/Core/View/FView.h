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

@protocol FNode;
@protocol FOperation;
@protocol FEventRegistration;
@class FWriteTreeRef;
@class FQuerySpec;
@class FChange;
@class FPath;
@class FViewCache;

@interface FViewOperationResult : NSObject

@property(nonatomic, strong, readonly) NSArray *changes;
@property(nonatomic, strong, readonly) NSArray *events;

@end

@interface FView : NSObject

@property(nonatomic, strong, readonly) FQuerySpec *query;

- (id)initWithQuery:(FQuerySpec *)query
    initialViewCache:(FViewCache *)initialViewCache;

- (id<FNode>)eventCache;
- (id<FNode>)serverCache;
- (id<FNode>)completeServerCacheFor:(FPath *)path;
- (BOOL)isEmpty;

- (void)addEventRegistration:(id<FEventRegistration>)eventRegistration;
- (NSArray *)removeEventRegistration:(id<FEventRegistration>)eventRegistration
                         cancelError:(NSError *)cancelError;

- (FViewOperationResult *)applyOperation:(id<FOperation>)operation
                             writesCache:(FWriteTreeRef *)writesCache
                             serverCache:(id<FNode>)optCompleteServerCache;
- (NSArray *)initialEvents:(id<FEventRegistration>)registration;

@end
