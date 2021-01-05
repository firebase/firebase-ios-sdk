/*
 * Copyright 2019 Google
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

#import "GoogleDataTransport/GDTCORTests/Unit/GDTCORTestCase.h"

#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORFlatFileStorage+Testing.h"
#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORUploadCoordinator+Testing.h"

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORReachability_Private.h"

@implementation GDTCORTestCase

- (void)setUp {
  [GDTCORReachability sharedInstance].flags = kSCNetworkReachabilityFlagsReachable;
  [[GDTCORUploadCoordinator sharedInstance] stopTimer];
  [[GDTCORUploadCoordinator sharedInstance] reset];
  [[GDTCORFlatFileStorage sharedInstance] reset];
}

- (void)tearDown {
  [GDTCORAssertHelper setAssertionBlock:nil];
}

@end
