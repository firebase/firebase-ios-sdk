// Copyright 2017 Google
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

#import "Private/FIRSwizzledObject.h"

#import "Private/FIRObjectSwizzler.h"
#import "Private/FIRSwizzledObject.h"

NSString *kSwizzlerAssociatedObjectKey = @"fpr_objectSwizzler";

@interface FIRSwizzledObject ()

@end

@implementation FIRSwizzledObject

+ (void)copyDonorSelectorsUsingObjectSwizzler:(FIRObjectSwizzler *)objectSwizzler {
  [objectSwizzler copySelector:@selector(fpr_objectSwizzler) fromClass:self isClassSelector:NO];
  [objectSwizzler copySelector:@selector(fpr_class) fromClass:self isClassSelector:NO];
}

- (instancetype)init {
  NSAssert(NO, @"Do not instantiate this class, it's only a donor class");
  return nil;
}

- (FIRObjectSwizzler *)fpr_objectSwizzler {
  return [FIRObjectSwizzler getAssociatedObject:self key:kSwizzlerAssociatedObjectKey];
}

#pragma mark - Donor methods

- (Class)fpr_class {
  return [[self fpr_objectSwizzler] generatedClass];
}

@end
