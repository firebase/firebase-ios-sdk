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
#import "FPath.h"
#import "FNode.h"

@interface FTupleNodePath : NSObject

@property (nonatomic, strong) FPath* path;
@property (nonatomic, strong) id<FNode> node;

- (id) initWithNode:(id<FNode>)aNode andPath:(FPath *)aPath;

@end
