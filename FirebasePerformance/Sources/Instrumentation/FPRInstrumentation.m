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

#import "FirebasePerformance/Sources/Instrumentation/FPRInstrumentation.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLConnectionInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLSessionInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/UIKit/FPRUIViewControllerInstrument.h"

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

// The instrumentation group keys.
NSString *const kFPRInstrumentationGroupNetworkKey = @"network";
NSString *const kFPRInstrumentationGroupUIKitKey = @"uikit";

/** Use ivars instead of properties to reduce message sending overhead. */
@interface FPRInstrumentation () {
  // A dictionary of the instrument groups.
  NSDictionary<NSString *, NSMutableArray *> *_instrumentGroups;
}

/** Registers an instrument in the given group.
 *
 *  @param instrument The instrument to register.
 *  @param group The group to register the instrument in.
 */
- (void)registerInstrument:(FPRInstrument *)instrument group:(NSString *)group;

@end

@implementation FPRInstrumentation

- (instancetype)init {
  self = [super init];
  if (self) {
    _instrumentGroups = @{
      kFPRInstrumentationGroupNetworkKey : [[NSMutableArray alloc] init],
      kFPRInstrumentationGroupUIKitKey : [[NSMutableArray alloc] init]
    };
  }
  return self;
}

- (void)registerInstrument:(FPRInstrument *)instrument group:(NSString *)group {
  FPRAssert(instrument, @"Instrument must be non-nil.");
  FPRAssert(_instrumentGroups[group], @"groups and group must be non-nil, and groups[group] must be"
                                       "non-nil.");
  if (instrument != nil) {
    [_instrumentGroups[group] addObject:instrument];
  }
  [instrument registerInstrumentors];
}

- (NSUInteger)registerInstrumentGroup:(NSString *)group {
  FPRAssert(_instrumentGroups[group], @"The group key does not exist", group);
  FPRAssert(_instrumentGroups[group].count == 0, @"This group is already instrumented");

  if ([group isEqualToString:kFPRInstrumentationGroupNetworkKey]) {
    [self registerInstrument:[[FPRNSURLSessionInstrument alloc] init] group:group];
    [self registerInstrument:[[FPRNSURLConnectionInstrument alloc] init] group:group];
  }

  if ([group isEqualToString:kFPRInstrumentationGroupUIKitKey]) {
    [self registerInstrument:[[FPRUIViewControllerInstrument alloc] init] group:group];
  }

  return _instrumentGroups[group].count;
}

- (BOOL)deregisterInstrumentGroup:(NSString *)group {
  FPRAssert(_instrumentGroups[group], @"You're attempting to deregister an invalid group key.");
  for (FPRInstrument *instrument in _instrumentGroups[group]) {
    [instrument deregisterInstrumentors];
  }
  [_instrumentGroups[group] removeAllObjects];
  return _instrumentGroups[group].count == 0;
}

@end
