/*
 * Copyright 2017 Google
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

#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRAuthBackend.h"

/** @var FIRAuthFakeBackendExpectedAPIKey
    @brief The only API Key the fake backend assumes is valid. Calls to the backend must be made
        using this API Key or they will fail with the expected response for an API Key which doesn't
        exist.
 */
extern NSString *const FIRAuthFakeBackendExpectedAPIKey;

/** @class FIRAuthFakeBackendImplementation
    @brief A fake in-memory backend for use with unit tests and UI tests.
 */
@interface FIRAuthFakeBackendImplementation : NSObject <FIRAuthBackendImplementation>

/** @fn reset
    @brief Clears all stored state for the backend.
 */
- (void)reset;

/** @fn install
    @brief Begins using the fake backend implementation.
 */
- (void)install;

/** @fn uninstall
    @brief Stops using the fake backend implementation and resumes using the default backend
        implementation.
 */
- (void)uninstall;

@end
