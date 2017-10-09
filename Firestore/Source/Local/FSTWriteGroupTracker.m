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

#import "FSTWriteGroupTracker.h"

#import "FSTAssert.h"
#import "FSTWriteGroup.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTWriteGroupTracker ()
@property(nonatomic, strong, nullable) FSTWriteGroup *activeGroup;
@end

@implementation FSTWriteGroupTracker

+ (instancetype)tracker {
  return [[FSTWriteGroupTracker alloc] init];
}

- (FSTWriteGroup *)startGroupWithAction:(NSString *)action {
  // NOTE: We can relax this to allow nesting if/when we find we need it.
  FSTAssert(!self.activeGroup,
            @"Attempt to create write group (%@) while existing write group (%@) still active.",
            action, self.activeGroup.action);
  self.activeGroup = [FSTWriteGroup groupWithAction:action];
  return self.activeGroup;
}

- (void)endGroup:(FSTWriteGroup *)group {
  FSTAssert(self.activeGroup == group,
            @"Attempted to end write group (%@) which is different from active group (%@)",
            group.action, self.activeGroup.action);
  self.activeGroup = nil;
}

@end

NS_ASSUME_NONNULL_END
