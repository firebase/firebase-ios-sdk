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

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"

/** Logs assert information. This shouldn't be called by anything except FPRAssert.
 *
 *  @param object The object (or class) that is asserting.
 *  @param condition The condition that is being asserted to be true.
 *  @param func The value of the __func__ variable.
 */
FOUNDATION_EXTERN void __FPRAssert(id object, BOOL condition, const char *func);

/** This protocol defines the selectors that are invoked when a diagnostics event occurs. */
@protocol FPRDiagnosticsProtocol

@optional

/** Emits class-level diagnostic information. */
+ (void)emitDiagnostics;

/** Emits object-level diagnostic information. */
- (void)emitDiagnostics;

@end

// Use this define in implementations of +/-emitDiagnostics.
#define EMIT_DIAGNOSTIC(...) FPRLogNotice(kFPRDiagnosticLog, __VA_ARGS__)

// This assert adds additional functionality to the normal NSAssert, including printing out
// information when NSAsserts are stripped. A __builtin_expect is utilized to keep running speed
// as fast as possible.
#define FPRAssert(condition, ...)                 \
  {                                               \
    do {                                          \
      __FPRAssert(self, !!(condition), __func__); \
      NSAssert(condition, __VA_ARGS__);           \
    } while (0);                                  \
  }

/** This class handles the control of diagnostics in the SDK. */
@interface FPRDiagnostics : NSObject

/** YES if diagnostics are enabled, NO otherwise. */
@property(class, nonatomic, readonly, getter=isEnabled) BOOL enabled;

@end
