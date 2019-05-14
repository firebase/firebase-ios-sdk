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

#import "GDTTests/Unit/Helpers/GDTTestPrioritizer.h"

#import "GDTTests/Unit/Helpers/GDTTestUploadPackage.h"

@implementation GDTTestPrioritizer

- (instancetype)init {
  self = [super init];
  if (self) {
    _uploadPackage = [[GDTTestUploadPackage alloc] initWithTarget:kGDTTargetTest];
  }
  return self;
}

- (GDTUploadPackage *)uploadPackageWithConditions:(GDTUploadConditions)conditions {
  if (_uploadPackageWithConditionsBlock) {
    _uploadPackageWithConditionsBlock();
  }
  return _uploadPackage;
}

- (void)prioritizeEvent:(GDTStoredEvent *)event {
  if (_prioritizeEventBlock) {
    _prioritizeEventBlock(event);
  }
}

- (void)appWillBackground:(UIApplication *)app {
}

- (void)appWillForeground:(UIApplication *)app {
}

- (void)appWillTerminate:(UIApplication *)application {
}

@end
