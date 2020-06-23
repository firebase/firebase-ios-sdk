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

#import "FirebaseDatabase/Sources/FViewProcessorResult.h"
#import "FirebaseDatabase/Sources/Core/View/FViewCache.h"

@interface FViewProcessorResult ()
@property(nonatomic, strong, readwrite) FViewCache *viewCache;
@property(nonatomic, strong, readwrite) NSArray *changes;
@end

@implementation FViewProcessorResult
- (id)initWithViewCache:(FViewCache *)viewCache changes:(NSArray *)changes {
    self = [super init];
    if (self) {
        self.viewCache = viewCache;
        self.changes = changes;
    }
    return self;
}

@end
