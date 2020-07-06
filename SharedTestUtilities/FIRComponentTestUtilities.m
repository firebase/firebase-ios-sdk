/*
 * Copyright 2018 Google
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

#import "SharedTestUtilities/FIRComponentTestUtilities.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRComponentContainer (TestingPrivate)
// Expose the private property in FIRComponentContainer for manually setting in the custom
// constructor.
@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRComponentCreationBlock> *components;

@end

@implementation FIRComponentContainer (TestingPrivate)

// Dynamic so the internal property exposed above doesn't get overridden by compiler generated
// getters and setters.
@dynamic components;

- (instancetype)initWithApp:(FIRApp *)app
                 components:(NSDictionary<NSString *, FIRComponentCreationBlock> *)components {
  self = [self initWithApp:app registrants:[[NSMutableSet alloc] init]];
  if (self) {
    // Explicitly use `self.components` here since we don't have access to the ivar underneath.
    self.components = [components mutableCopy];
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
