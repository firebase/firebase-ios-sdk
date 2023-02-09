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

/* List of options the session cares about. */
typedef NS_OPTIONS(NSUInteger, FPRSessionOptions) {
  FPRSessionOptionsNone = 0,
  FPRSessionOptionsGauges = (1 << 0),
  FPRSessionOptionsEvents = (1 << 1),
};

/* Class that contains the details of a session including the sessionId and session options. */
@interface FPRSessionDetails : NSObject

/* The sessionId with which the session details is initialized with. */
@property(nonatomic, nonnull, readonly) NSString *sessionId;

/* List of options enabled for the session. */
@property(nonatomic, readonly) FPRSessionOptions options;

/* Length of the session in minutes. */
- (NSUInteger)sessionLengthInMinutesFromDate:(nonnull NSDate *)now;

/**
 * Creates an instance of FPRSessionDetails with the provided sessionId and the list of available
 * options.
 *
 * @param sessionId Session Id for which the object is created.
 * @param options Options enabled for the session.
 * @return Instance of the object FPRSessionDetails.
 */
- (nonnull instancetype)initWithSessionId:(nonnull NSString *)sessionId
                                  options:(FPRSessionOptions)options NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)init NS_UNAVAILABLE;

/**
 * Checks and returns if the session is verbose.
 *
 * @return Return YES if verbose, NO otherwise.
 */
- (BOOL)isVerbose;

@end
