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

#define RED @true
#define BLACK @false

typedef NSNumber FLLRBColor;

@protocol FLLRBNode <NSObject>

- (id)copyWith:(id) aKey withValue:(id) aValue withColor:(FLLRBColor*) aColor withLeft:(id<FLLRBNode>)aLeft withRight:(id<FLLRBNode>)aRight;
- (id<FLLRBNode>) insertKey:(id) aKey forValue:(id)aValue withComparator:(NSComparator)aComparator;
- (id<FLLRBNode>) remove:(id) key withComparator:(NSComparator)aComparator;
- (int) count;
- (BOOL) isEmpty;
- (BOOL) inorderTraversal:(BOOL (^)(id key, id value))action;
- (BOOL) reverseTraversal:(BOOL (^)(id key, id value))action;
- (id<FLLRBNode>) min;
- (id) minKey;
- (id) maxKey;
- (BOOL) isRed;
- (int) check;

@property (nonatomic, strong) id key;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) FLLRBColor* color;
@property (nonatomic, strong) id<FLLRBNode> left;
@property (nonatomic, strong) id<FLLRBNode> right;

@end
