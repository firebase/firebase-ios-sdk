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

#import "FNode.h"

/**
 * Applies a merge of a snap for a given interval of paths.
 * Each leaf in the current node which the relative path lies *after* (the optional) start and lies *before or at*
 * (the optional) end will be deleted. Each leaf in snap that lies in the interval will be added to the resulting node.
 * Nodes outside of the range are ignored. nil for start and end are sentinel values that represent -infinity and
 * +infinity respectively (aka includes any path).
 * Priorities of children nodes are treated as leaf children of that node.
 */
@interface FRangeMerge : NSObject

- (instancetype)initWithStart:(FPath *)start end:(FPath *)end updates:(id<FNode>)updates;

- (id<FNode>)applyToNode:(id<FNode>)node;

@end
