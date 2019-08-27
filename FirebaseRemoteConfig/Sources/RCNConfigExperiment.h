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

#import <Foundation/Foundation.h>

@class FIRExperimentController;
@class RCNConfigDBManager;

/// Handles experiment information update and persistence.
@interface RCNConfigExperiment : NSObject

/// Designated initializer;
- (instancetype)initWithDBManager:(RCNConfigDBManager *)DBManager
             experimentController:(FIRExperimentController *)controller NS_DESIGNATED_INITIALIZER;

/// Use `initWithDBManager:` instead.
- (instancetype)init NS_UNAVAILABLE;

/// Update/Persist experiment information from config fetch response.
- (void)updateExperimentsWithResponse:(NSArray<NSDictionary<NSString *, id> *> *)response;

/// Update experiments to Firebase Analytics when activateFetched happens.
- (void)updateExperiments;
@end
