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

#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
#import <GCDWebServer/GCDWebServerFileResponse.h>

NS_ASSUME_NONNULL_BEGIN

@class GCDWebServerRequest;
@class GCDWebServerResponse;

/** This class provides a hermetic test service that runs on the test device/simulator. */
@interface GDTCORTestServer : NSObject

/** The URL of the server. */
@property(nonatomic, readonly) NSURL *serverURL;

/** Just before responding, this block will be scheduled to run on a global queue. */
@property(nonatomic, copy, nullable) void (^responseCompletedBlock)
    (GCDWebServerRequest *request, GCDWebServerResponse *response);

/** Registers the paths used for testing. */
- (void)registerTestPaths;

/** Starts the server. Can be called after calling `-stop`. */
- (void)start;

/** Stops the server. */
- (void)stop;

/** Returns YES if the server is running, NO otherwise.
 *
 * @return YES if the server is running, NO otherwise.
 */
- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
