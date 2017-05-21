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

#import "FCacheNode.h"
#import "FNode.h"
#import "FPath.h"
#import "FEmptyNode.h"
#import "FIndexedNode.h"

@interface FCacheNode ()
@property (nonatomic, readwrite) BOOL isFullyInitialized;
@property (nonatomic, readwrite) BOOL isFiltered;
@property (nonatomic, strong, readwrite) FIndexedNode *indexedNode;
@end

@implementation FCacheNode
- (id) initWithIndexedNode:(FIndexedNode *)indexedNode
        isFullyInitialized:(BOOL)fullyInitialized
                isFiltered:(BOOL)filtered
{
    self = [super init];
    if (self) {
        self.indexedNode = indexedNode;
        self.isFullyInitialized = fullyInitialized;
        self.isFiltered = filtered;
    }
    return self;
}

- (BOOL)isCompleteForPath:(FPath *)path {
    if (path.isEmpty) {
        return self.isFullyInitialized && !self.isFiltered;
    } else {
        NSString *childKey = [path getFront];
        return [self isCompleteForChild:childKey];
    }
}

- (BOOL)isCompleteForChild:(NSString *)childKey {
    return (self.isFullyInitialized && !self.isFiltered) || [self.node hasChild:childKey];
}

- (id<FNode>)node {
    return self.indexedNode.node;
}

@end
