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

#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

#import "OCMock.h"

@implementation FIRURLSessionOCMockStub

+ (id)stubURLSessionDataTaskWithResponse:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error
                          URLSessionMock:(id)URLSessionMock
                  requestValidationBlock:(FIRRequestValidationBlock)requestValidationBlock {
  id mockDataTask = OCMStrictClassMock([NSURLSessionDataTask class]);

  // Validate request content.
  FIRRequestValidationBlock nonOptionalRequestValidationBlock =
      requestValidationBlock ?: ^BOOL(id request) {
        return YES;
      };

  id URLRequestValidationArg = [OCMArg checkWithBlock:nonOptionalRequestValidationBlock];

  // Save task completion to be called on the `[NSURLSessionDataTask resume]`
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // Expect `dataTaskWithRequest` to be called.
  OCMExpect([URLSessionMock dataTaskWithRequest:URLRequestValidationArg
                              completionHandler:completionArg])
      .andReturn(mockDataTask);

  // Expect the task to be resumed and call the task completion.
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]).andDo(^(NSInvocation *invocation) {
    taskCompletion(body, response, error);
  });

  return mockDataTask;
}

+ (NSHTTPURLResponse *)HTTPResponseWithCode:(NSInteger)statusCode {
  return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost"]
                                     statusCode:statusCode
                                    HTTPVersion:@"HTTP/1.1"
                                   headerFields:nil];
}

@end
