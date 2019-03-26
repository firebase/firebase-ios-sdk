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

#import <Foundation/Foundation.h>

@class FIRIAMDisplayExecutor;
NS_ASSUME_NONNULL_BEGIN

// Parent class for modeling different flows in which we would trigger the check to see if there
// is appropriate in-app messaging to be rendered. Notice that the flow only triggers the check
// and whether it turns out to have any eligible message to be displayed depending on if certain
// conditions are met
@interface FIRIAMDisplayCheckTriggerFlow : NSObject

// Accessed by subclasses, not intended by other clients
@property(nonatomic, nonnull, readonly) FIRIAMDisplayExecutor *displayExecutor;
- (instancetype)initWithDisplayFlow:(FIRIAMDisplayExecutor *)displayExecutor;

// subclasses should implement the follow two methods to start/stop their concrete
// display check flow
- (void)start;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
