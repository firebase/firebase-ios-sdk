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

@class FViewCache;
@class FViewProcessorResult;
@class FChildChangeAccumulator;
@protocol FNode;
@class FWriteTreeRef;
@class FPath;
@protocol FOperation;
@protocol FNodeFilter;

@interface FViewProcessor : NSObject

- (id)initWithFilter:(id<FNodeFilter>)nodeFilter;

- (FViewProcessorResult *)applyOperationOn:(FViewCache *)oldViewCache
                                 operation:(id<FOperation>)operation
                               writesCache:(FWriteTreeRef *)writesCache
                             completeCache:(id<FNode>)optCompleteCache;
- (FViewCache *)revertUserWriteOn:(FViewCache *)viewCache
                             path:(FPath *)path
                      writesCache:(FWriteTreeRef *)writesCache
                    completeCache:(id<FNode>)optCompleteCache
                      accumulator:(FChildChangeAccumulator *)accumulator;

@end
