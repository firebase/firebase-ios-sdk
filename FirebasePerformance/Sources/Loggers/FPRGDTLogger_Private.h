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

#import "FirebasePerformance/Sources/Loggers/FPRGDTLogger.h"

#import <GoogleDataTransport/GoogleDataTransport.h>
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

/** FPRGDTLogger private definition used for unit testing. */
@interface FPRGDTLogger ()

/** Log source for which the logger is being used. */
@property(nonatomic, readwrite) NSInteger logSource;

/** Google Data Transport instance for FLL. */
@property(nonatomic, readwrite) GDTCORTransport *gdtfllTransport;

/** Serial queue used for logging events to the GDT Transport layer. */
@property(nonatomic, readonly) dispatch_queue_t queue;

/** Boolean to see if the App is running on simulator or actual device.
 * isSimulator is set to YES if environment variable contains SIMULATOR_UDID, NO otherwise.*/
@property(nonatomic, readwrite) BOOL isSimulator;

/** Boolean to see if the App is built in debug mode or release mode.
 * isDebugBuild is set to YES if !NDEBUG, NO otherwise.*/
@property(nonatomic, readwrite) FPRConfigurations *configurations;

/** Seed value decided based on installation ID to determine if the event should be sent to FLL.
 */
@property(nonatomic, readwrite) float instanceSeed;

@end
