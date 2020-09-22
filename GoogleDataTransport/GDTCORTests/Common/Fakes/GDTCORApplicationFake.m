/*
 * Copyright 2020 Google LLC
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

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORApplicationFake.h"

@implementation GDTCORApplicationFake

@synthesize isRunningInBackground;

- (GDTCORBackgroundIdentifier)beginBackgroundTaskWithName:(NSString *)name
                                        expirationHandler:(void (^__nullable)(void))handler {
  return self.beginTaskHandler(name, handler);
}

- (void)endBackgroundTask:(GDTCORBackgroundIdentifier)bgID {
  self.endTaskHandler(bgID);
}

@end
