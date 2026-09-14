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

#import "FTransformedEnumerator.h"

@interface FTransformedEnumerator ()
@property(nonatomic, strong) NSEnumerator *enumerator;
@property(nonatomic, copy) id (^transform)(id);
@end

@implementation FTransformedEnumerator
- (id)initWithEnumerator:(NSEnumerator *)enumerator
            andTransform:(id (^)(id))transform {
    self = [super init];
    if (self) {
        self.enumerator = enumerator;
        self.transform = transform;
    }
    return self;
}

- (id)nextObject {
    id next = self.enumerator.nextObject;
    if (next != nil) {
        return self.transform(next);
    } else {
        return nil;
    }
}

@end
