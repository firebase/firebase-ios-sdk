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

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRFakeBackendRPCIssuer
    @brief An implementation of @c FIRAuthBackendRPCIssuer which is used to test backend request,
        response, and glue logic.
 */
@interface FIRFakeBackendRPCIssuer : NSObject <FIRAuthBackendRPCIssuer>

/** @property requestURL
    @brief The URL which was requested.
 */
@property(nonatomic, readonly) NSURL *requestURL;

/** @property requestData
    @brief The raw data in the POST body.
 */
@property(nonatomic, readonly) NSData *requestData;

/** @property decodedRequest
    @brief The raw data in the POST body decoded as JSON.
 */
@property(nonatomic, readonly) NSDictionary *decodedRequest;

/** @property contentType
    @brief The value of the content type HTTP header in the request.
 */
@property(nonatomic, readonly) NSString *contentType;

/** @fn respondWithData:error:
    @brief Responds to a pending RPC request with data and an error.
    @remarks This is useful for simulating an error response with bogus data or unexpected data
        (like unexpectedly receiving an HTML body.)
    @param data The data to return as the body of an HTTP response.
    @param error The simulated error to return from GTM.
 */
- (void)respondWithData:(nullable NSData *)data error:(nullable NSError *)error;

/** @fn respondWithJSON:error:
    @brief Responds to a pending RPC request with JSON and an error.
    @remarks This is useful for simulating an error response with error JSON.
    @param JSON The JSON to return.
    @param error The simulated error to return from GTM.
 */
- (NSData *)respondWithJSON:(nullable NSDictionary *)JSON error:(nullable NSError *)error;

/** @fn respondWithJSONError:
    @brief Responds to a pending RPC request with a JSON server error.
    @param JSON A dictionary which should be a server error encoded as JSON for fake response.
 */
- (NSData *)respondWithJSONError:(NSDictionary *)JSON;

/** @fn respondWithError:
    @brief Responds to a pending RPC request with an error. This is useful for simulating things
        like a network timeout or unreachable host.
    @param error The simulated error to return from GTM.
 */
- (NSData *)respondWithError:(NSError *)error;

/** @fn respondWithServerErrorMessage:error:
    @brief Responds to a pending RPC request with a server error message.
    @param errorMessage The simulated error message to return from the server.
    @param error The simulated error to return from GTM.
 */
- (NSData *)respondWithServerErrorMessage:(NSString *)errorMessage error:(NSError *)error;

/** @fn respondWithServerErrorMessage:
    @brief Responds to a pending RPC request with a server error message.
    @param errorMessage The simulated error message to return from the server.
 */
- (NSData *)respondWithServerErrorMessage:(NSString *)errorMessage;

/** @fn respondWithJSON:
    @brief Responds to a pending RPC request with JSON.
    @param JSON A dictionary which should be encoded as JSON for a fake response.
 */
- (NSData *)respondWithJSON:(NSDictionary *)JSON;

@end

NS_ASSUME_NONNULL_END
