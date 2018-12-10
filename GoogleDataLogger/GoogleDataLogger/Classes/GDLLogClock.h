/*
 * Copyright 2018 Google
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

NS_ASSUME_NONNULL_BEGIN

/** A struct to hold data pertaining to a snapshot in time. */
typedef struct {
  /** The current time in millis. */
  int64_t timeMillis;

  /** The device uptime in millis. */
  int64_t uptimeMillis;

  /** The timezone offset in millis. */
  int64_t timezoneOffsetMillis;
} GDLLogClockSnapshot;

/** This class manages the device clock and produces snapshots of the current time. */
@interface GDLLogClock : NSObject

// TODO(mikehaney24): - (GDLLogClockSnapshot)snapshot;

@end

NS_ASSUME_NONNULL_END
