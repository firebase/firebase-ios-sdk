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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** This class manages all the screen traces. If initialized, it records the total frames, frozen
 *  frames and slow frames, and if it has been registered as a delegate of FIRAScreenViewReporter,
 *  it also automatically creates screen traces for each UIViewController.
 */
@interface FPRScreenTraceTracker : NSObject

/** Singleton instance of FPRScreenTraceTracker.
 *
 *  @return The shared instance of FPRScreenTraceTracker.
 */
+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
