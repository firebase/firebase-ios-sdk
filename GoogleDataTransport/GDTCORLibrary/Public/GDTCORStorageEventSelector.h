/*
 * Copyright 2020 Google LLC
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

#import <GoogleDataTransport/GDTCORTargets.h>

NS_ASSUME_NONNULL_BEGIN

/** This class enables the finding of events by matching events with the properties of this class.
 */
@interface GDTCORStorageEventSelector : NSObject

/** The target to find events for. Required. */
@property(readonly, nonatomic) GDTCORTarget selectedTarget;

/** Finds a specific event. */
@property(nullable, readonly, nonatomic) NSNumber *selectedEventID;

/** Finds all events of a mappingID. */
@property(nullable, readonly, nonatomic) NSString *selectedMappingID;

/** Finds all events matching the qosTiers in this list. */
@property(nullable, readonly, nonatomic) NSArray<NSNumber *> *selectedQosTiers;

/** Instantiates an event selector.
 *
 * @param target The selected target.
 * @param eventID Optional param to find an event matching this eventID.
 * @param mappingID Optional param to find events matching this mappingID.
 * @param qosTiers Optional param to find events matching the given QoS tiers.
 * @return An immutable event selector instance.
 */
- (instancetype)initWithTarget:(GDTCORTarget)target
                eventIDEqualTo:(nullable NSNumber *)eventID
              mappingIDEqualTo:(nullable NSString *)mappingID
                      qosTiers:(nullable NSArray<NSNumber *> *)qosTiers;
@end

NS_ASSUME_NONNULL_END
