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

#import <GoogleDataLogger/GDLLogPrioritizer.h>

NS_ASSUME_NONNULL_BEGIN

/** This class implements the log prioritizer protocol for testing purposes, providing APIs to allow
 * tests to alter the prioritizer behavior without creating a bunch of specialized classes.
 */
@interface GDLTestPrioritizer : NSObject <GDLLogPrioritizer>

/** The return value of -logsForNextUpload. */
@property(nullable, nonatomic) NSSet<NSNumber *> *logsForNextUploadFake;

/** Allows the running of a block of code during -prioritizeLog. */
@property(nullable, nonatomic) void (^prioritizeLogBlock)(GDLLogEvent *logEvent);

@end

NS_ASSUME_NONNULL_END
