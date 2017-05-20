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
#import "FTreeNode.h"
#import "FPath.h"

@interface FTree : NSObject

- (id)init;
- (id)initWithName:(NSString*)aName withParent:(FTree *)aParent withNode:(FTreeNode *)aNode;

- (FTree *) subTree:(FPath*)path;
- (id)getValue;
- (void)setValue:(id)value;
- (void) clear;
- (BOOL) hasChildren;
- (BOOL) isEmpty;
- (void) forEachChildMutationSafe:(void (^)(FTree *))action;
- (void) forEachChild:(void (^)(FTree *))action;
- (void) forEachDescendant:(void (^)(FTree *))action;
- (void) forEachDescendant:(void (^)(FTree *))action includeSelf:(BOOL)incSelf childrenFirst:(BOOL)childFirst;
- (BOOL) forEachAncestor:(BOOL (^)(FTree *))action;
- (BOOL) forEachAncestor:(BOOL (^)(FTree *))action includeSelf:(BOOL)incSelf;
- (void) forEachImmediateDescendantWithValue:(void (^)(FTree *))action;
- (BOOL) valueExistsAtOrAbove:(FPath *)path;
- (FPath *)path;
- (void) updateParents;
- (void) updateChild:(NSString*)childName withNode:(FTree *)child;

@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) FTree* parent;
@property (nonatomic, strong) FTreeNode* node;

@end
