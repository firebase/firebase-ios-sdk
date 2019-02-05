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

#import "GDLLogProto.h"

NS_ASSUME_NONNULL_BEGIN

/** The different possible log quality of service specifiers. High values indicate high priority. */
typedef NS_ENUM(NSInteger, GDLLogQoS) {
  /** The QoS tier wasn't set, and won't ever be sent. */
  GDLLogQoSUnknown = 0,

  /** This log is internal telemetry data that should not be sent on its own if possible. */
  GDLLogQoSTelemetry = 1,

  /** This log should be sent, but in a batch only roughly once per day. */
  GDLLogQoSDaily = 2,

  /** This log should be sent when requested by the uploader. */
  GDLLogQosDefault = 3,

  /** This log should be sent immediately along with any other data that can be batched. */
  GDLLogQoSFast = 4,

  /** This log should only be uploaded on wifi. */
  GDLLogQoSWifiOnly = 5,
};

@interface GDLLogEvent : NSObject <NSSecureCoding>

/** The log map identifier, to allow backends to map the extension property to a proto. */
@property(readonly, nonatomic) NSString *logMapID;

/** The identifier for the backend this log will eventually be sent to. */
@property(readonly, nonatomic) NSInteger logTarget;

/** The log object itself, encapsulated in the transport of your choice, as long as it implements
 * the GDLLogProto protocol. */
@property(nullable, nonatomic) id<GDLLogProto> extension;

/** The quality of service tier this log belongs to. */
@property(nonatomic) GDLLogQoS qosTier;

/** A dictionary provided to aid prioritizers by allowing the passing of arbitrary data. It will be
 * retained by a copy in -copy, but not used for -hash.
 */
@property(nullable, nonatomic) NSDictionary *customPrioritizationParams;

// Please use the designated initializer.
- (instancetype)init NS_UNAVAILABLE;

/** Initializes an instance using the given logMapID.
 *
 * @param logMapID The log map identifier.
 * @param logTarget The log's target identifier.
 * @return An instance of this class.
 */
- (instancetype)initWithLogMapID:(NSString *)logMapID
                       logTarget:(NSInteger)logTarget NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
