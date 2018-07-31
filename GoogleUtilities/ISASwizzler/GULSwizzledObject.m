// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Private/GULSwizzledObject.h"
#import "Private/GULObjectSwizzler.h"

NSString *kSwizzlerAssociatedObjectKey = @"gul_objectSwizzler";

@interface GULSwizzledObject ()

@end

@implementation GULSwizzledObject

+ (void)copyDonorSelectorsUsingObjectSwizzler:(GULObjectSwizzler *)objectSwizzler {
  [objectSwizzler copySelector:@selector(gul_objectSwizzler) fromClass:self isClassSelector:NO];
  [objectSwizzler copySelector:@selector(gul_class) fromClass:self isClassSelector:NO];
}

- (instancetype)init {
  NSAssert(NO, @"Do not instantiate this class, it's only a donor class");
  return nil;
}

- (GULObjectSwizzler *)gul_objectSwizzler {
  return [GULObjectSwizzler getAssociatedObject:self key:kSwizzlerAssociatedObjectKey];
}

#pragma mark - Donor methods

- (Class)gul_class {
  return [[self gul_objectSwizzler] generatedClass];
}

@end
