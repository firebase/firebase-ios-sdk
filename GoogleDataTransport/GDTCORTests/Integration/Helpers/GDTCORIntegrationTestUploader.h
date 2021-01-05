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

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORUploader.h"

@class GDTCORTestServer;

/** An integration test uploader. */
@interface GDTCORIntegrationTestUploader : NSObject <GDTCORUploader>

/** Instantiates an instance of this uploader with the given server URL.
 *
 * @param serverURL The server URL this uploader should upload to.
 * @return An instance of this class.
 */
- (instancetype)initWithServer:(GDTCORTestServer *)serverURL;

@end
