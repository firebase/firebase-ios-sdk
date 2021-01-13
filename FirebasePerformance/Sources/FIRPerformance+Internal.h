// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/Public/FIRPerformance.h"
#import "FirebasePerformance/Sources/Public/FIRPerformanceAttributable.h"

/**
 * Extension that is added on top of the class FIRPerformance to make certain methods used
 * internally within the SDK, but not public facing. A category could be ideal, but Firebase
 * recommends not using categories as that mandates including -ObjC flag for build which is an extra
 * step for the developer.
 */

@interface FIRPerformance (Attributable) <FIRPerformanceAttributable>

@end
