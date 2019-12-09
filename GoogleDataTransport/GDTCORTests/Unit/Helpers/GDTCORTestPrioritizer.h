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

#import <GoogleDataTransport/GDTCORPrioritizer.h>

NS_ASSUME_NONNULL_BEGIN

/** This class implements the event prioritizer protocol for testing purposes, providing APIs to
 * allow tests to alter the prioritizer behavior without creating a bunch of specialized classes.
 */
@interface GDTCORTestPrioritizer : NSObject <GDTCORPrioritizer>

/** The events in the package given by -uploadPackageWithConditions. */
@property(nullable, nonatomic) NSSet<GDTCORStoredEvent *> *events;

/** Allows the running of a block of code during -prioritizeEvent. */
@property(nullable, nonatomic) void (^prioritizeEventBlock)(GDTCORStoredEvent *event);

/** A block that can run before -uploadPackageWithConditions completes. */
@property(nullable, nonatomic) void (^uploadPackageWithConditionsBlock)(void);

@end

NS_ASSUME_NONNULL_END
