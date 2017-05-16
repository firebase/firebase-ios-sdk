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

#import "FMaxNode.h"
#import "FUtilities.h"
#import "FEmptyNode.h"


@implementation FMaxNode {

}
- (id) init {
    self = [super init];
    if (self) {

    }
    return self;
}

+ (id<FNode>) maxNode {
    static FMaxNode *maxNode = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        maxNode = [[FMaxNode alloc] init];
    });
    return maxNode;
}

- (NSComparisonResult) compare:(id<FNode>)other {
    if (other == self) {
        return NSOrderedSame;
    } else {
        return NSOrderedDescending;
    }
}

- (BOOL)isEqual:(id)other {
    return other == self;
}

- (id<FNode>) getImmediateChild:(NSString *) childName {
    return [FEmptyNode emptyNode];
}

- (BOOL) isEmpty {
    return NO;
}
@end
