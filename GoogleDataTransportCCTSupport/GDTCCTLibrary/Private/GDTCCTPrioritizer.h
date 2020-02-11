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

#import <GoogleDataTransport/GDTCORClock.h>
#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORPrioritizer.h>
#import <GoogleDataTransport/GDTCORTargets.h>

NS_ASSUME_NONNULL_BEGIN

/** Manages the prioritization of events from GoogleDataTransport. */
@interface GDTCCTPrioritizer : NSObject <GDTCORPrioritizer>

/** The queue on which this prioritizer operates. */
@property(nonatomic) dispatch_queue_t queue;

/** All CCT events that have been processed by this prioritizer. */
@property(nonatomic) NSMutableSet<GDTCOREvent *> *CCTEvents;

/** All FLL events that have been processed by this prioritizer. */
@property(nonatomic) NSMutableSet<GDTCOREvent *> *FLLEvents;

/** All CSH events that have been processed by this prioritizer. */
@property(nonatomic) NSMutableSet<GDTCOREvent *> *CSHEvents;

/** The most recent attempted upload of CCT daily uploaded logs. */
@property(nonatomic) GDTCORClock *CCTTimeOfLastDailyUpload;

/** The most recent attempted upload of FLL daily uploaded logs*/
@property(nonatomic) GDTCORClock *FLLOfLastDailyUpload;

/** Creates and/or returns the singleton instance of this class.
 *
 * @return The singleton instance of this class.
 */
+ (instancetype)sharedInstance;

NS_ASSUME_NONNULL_END

@end
