/** @file FIRAuthFakeBackendImplementation.h
    @brief Firebase Auth SDK
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
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
