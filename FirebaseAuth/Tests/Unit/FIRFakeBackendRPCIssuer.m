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

#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kFakeErrorDomain
    @brief Fake error domain used for testing.
 */
static NSString *const kFakeErrorDomain = @"fake domain";

@implementation FIRFakeBackendRPCIssuer {
  /** @var _handler
      @brief A block we must invoke when @c respondWithError or @c respondWithJSON are called.
   */
  FIRAuthBackendRPCIssuerCompletionHandler _handler;
}

- (void)asyncPostToURLWithRequestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
                                           URL:(NSURL *)URL
                                          body:(NSData *)body
                                   contentType:(NSString *)contentType
                             completionHandler:(FIRAuthBackendRPCIssuerCompletionHandler)handler {
  _requestURL = [URL copy];
  if (body) {
    _requestData = body;
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
    _decodedRequest = JSON;
  }
  _contentType = contentType;
  _handler = handler;
}

- (void)respondWithData:(NSData *)data error:(NSError *)error {
  NSAssert(_handler, @"There is no pending RPC request.");
  NSAssert(data || error, @"At least one of: data or error should be been non-nil.");
  FIRAuthBackendRPCIssuerCompletionHandler handler = _handler;
  _handler = nil;
  handler(data, error);
}

- (NSData *)respondWithServerErrorMessage:(NSString *)errorMessage error:(NSError *)error {
  return [self respondWithJSON:@{@"error" : @{@"message" : errorMessage}} error:error];
}

- (NSData *)respondWithServerErrorMessage:(NSString *)errorMessage {
  NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
  return [self respondWithServerErrorMessage:errorMessage error:error];
}

- (NSData *)respondWithJSON:(NSDictionary *)JSON error:(NSError *)error {
  NSError *JSONEncodingError;
  NSData *data;
  if (JSON) {
    data = [NSJSONSerialization dataWithJSONObject:JSON
                                           options:NSJSONWritingPrettyPrinted
                                             error:&JSONEncodingError];
  }
  NSAssert(!JSONEncodingError, @"An error occurred encoding the JSON response.");
  [self respondWithData:data error:error];
  return data;
}

- (NSData *)respondWithJSONError:(NSDictionary *)JSONError {
  return [self respondWithJSON:JSONError
                         error:[NSError errorWithDomain:kFakeErrorDomain code:0 userInfo:nil]];
}

- (NSData *)respondWithError:(NSError *)error {
  return [self respondWithJSON:nil error:error];
}

- (NSData *)respondWithJSON:(NSDictionary *)JSON {
  return [self respondWithJSON:JSON error:nil];
}

@end
