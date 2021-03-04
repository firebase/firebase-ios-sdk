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

/** Different background states of a trace. */
typedef NS_ENUM(NSInteger, FPRTraceState) {
  FPRTraceStateUnknown,

  /** Background only trace. */
  FPRTraceStateBackgroundOnly,

  /** Foreground only trace. */
  FPRTraceStateForegroundOnly,

  /** Background and foreground trace. */
  FPRTraceStateBackgroundAndForeground,
};

/**
 * This class is used to track the app activity and track the background and foreground state of the
 * object. This object will be used by a trace to determine its application state if the lifecycle
 * of the trace is backgrounded, foregrounded or both.
 */
@interface FPRTraceBackgroundActivityTracker : NSObject

/** Background state of the tracker. */
@property(nonatomic, readonly) FPRTraceState traceBackgroundState;

@end
