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

#import "FirebaseDatabase/Sources/Core/Utilities/FTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FTreeNode.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

@implementation FTree

@synthesize name;
@synthesize parent;
@synthesize node;

- (id)init {
    self = [super init];
    if (self) {
        self.name = @"";
        self.parent = nil;
        self.node = [[FTreeNode alloc] init];
    }
    return self;
}

- (id)initWithName:(NSString *)aName
        withParent:(FTree *)aParent
          withNode:(FTreeNode *)aNode {
    self = [super init];
    if (self) {
        self.name = aName != nil ? aName : @"";
        self.parent = aParent != nil ? aParent : nil;
        self.node = aNode != nil ? aNode : [[FTreeNode alloc] init];
    }
    return self;
}

- (FTree *)subTree:(FPath *)path {
    FTree *child = self;
    NSString *next = [path getFront];
    while (next != nil) {
        FTreeNode *childNode = child.node.children[next];
        if (childNode == nil) {
            childNode = [[FTreeNode alloc] init];
        }
        child = [[FTree alloc] initWithName:next
                                 withParent:child
                                   withNode:childNode];
        path = [path popFront];
        next = [path getFront];
    }
    return child;
}

- (id)getValue {
    return self.node.value;
}

- (void)setValue:(id)value {
    self.node.value = value;
    [self updateParents];
}

- (void)clear {
    self.node.value = nil;
    [self.node.children removeAllObjects];
    self.node.childCount = 0;
    [self updateParents];
}

- (BOOL)hasChildren {
    return self.node.childCount > 0;
}

- (BOOL)isEmpty {
    return [self getValue] == nil && ![self hasChildren];
}

- (void)forEachChild:(void (^)(FTree *))action {
    for (NSString *key in self.node.children) {
        action([[FTree alloc]
            initWithName:key
              withParent:self
                withNode:[self.node.children objectForKey:key]]);
    }
}

- (void)forEachChildMutationSafe:(void (^)(FTree *))action {
    for (NSString *key in [self.node.children copy]) {
        action([[FTree alloc]
            initWithName:key
              withParent:self
                withNode:[self.node.children objectForKey:key]]);
    }
}

- (void)forEachDescendant:(void (^)(FTree *))action {
    [self forEachDescendant:action includeSelf:NO childrenFirst:NO];
}

- (void)forEachDescendant:(void (^)(FTree *))action
              includeSelf:(BOOL)incSelf
            childrenFirst:(BOOL)childFirst {
    if (incSelf && !childFirst) {
        action(self);
    }

    [self forEachChild:^(FTree *child) {
      [child forEachDescendant:action includeSelf:YES childrenFirst:childFirst];
    }];

    if (incSelf && childFirst) {
        action(self);
    }
}

- (BOOL)forEachAncestor:(BOOL (^)(FTree *))action {
    return [self forEachAncestor:action includeSelf:NO];
}

- (BOOL)forEachAncestor:(BOOL (^)(FTree *))action includeSelf:(BOOL)incSelf {
    FTree *aNode = (incSelf) ? self : self.parent;
    while (aNode != nil) {
        if (action(aNode)) {
            return YES;
        }
        aNode = aNode.parent;
    }
    return NO;
}

- (void)forEachImmediateDescendantWithValue:(void (^)(FTree *))action {
    [self forEachChild:^(FTree *child) {
      if ([child getValue] != nil) {
          action(child);
      } else {
          [child forEachImmediateDescendantWithValue:action];
      }
    }];
}

- (BOOL)valueExistsAtOrAbove:(FPath *)path {
    FTreeNode *aNode = self.node;
    while (aNode != nil) {
        if (aNode.value != nil) {
            return YES;
        }
        aNode = [aNode.children objectForKey:path.getFront];
        path = [path popFront];
    }
    // XXX Check with Michael if this is correct; deviates from JS.
    return NO;
}

- (FPath *)path {
    return [[FPath alloc]
        initWith:(self.parent == nil)
                     ? self.name
                     : [NSString stringWithFormat:@"%@/%@", [self.parent path],
                                                  self.name]];
}

- (void)updateParents {
    [self.parent updateChild:self.name withNode:self];
}

- (void)updateChild:(NSString *)childName withNode:(FTree *)child {
    BOOL childEmpty = [child isEmpty];
    BOOL childExists = self.node.children[childName] != nil;
    if (childEmpty && childExists) {
        [self.node.children removeObjectForKey:childName];
        self.node.childCount = self.node.childCount - 1;
        [self updateParents];
    } else if (!childEmpty && !childExists) {
        [self.node.children setObject:child.node forKey:childName];
        self.node.childCount = self.node.childCount + 1;
        [self updateParents];
    }
}

@end
