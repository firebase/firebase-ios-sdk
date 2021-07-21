// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLConnectionDelegate.h"

#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"

@implementation FPRNSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  [trace didCompleteRequestWithResponse:nil error:error];
  [FPRNetworkTrace removeNetworkTraceFromObject:connection];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(nonnull NSURLRequest *)request
            redirectResponse:(nullable NSURLResponse *)response {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
  return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    trace.responseCode = (int32_t)((NSHTTPURLResponse *)response).statusCode;
  }
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
  trace.responseSize += data.length;
}

- (void)connection:(NSURLConnection *)connection
              didSendBodyData:(NSInteger)bytesWritten
            totalBytesWritten:(NSInteger)totalBytesWritten
    totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  trace.requestSize = totalBytesWritten;
  if (totalBytesWritten >= totalBytesExpectedToWrite) {
    [trace checkpointState:FPRNetworkTraceCheckpointStateRequestCompleted];
  }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  [trace didCompleteRequestWithResponse:nil error:nil];
  [FPRNetworkTrace removeNetworkTraceFromObject:connection];
}

- (void)connection:(NSURLConnection *)connection
          didWriteData:(long long)bytesWritten
     totalBytesWritten:(long long)totalBytesWritten
    expectedTotalBytes:(long long)expectedTotalBytes {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  trace.requestSize = totalBytesWritten;
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection
                        destinationURL:(NSURL *)destinationURL {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
  [trace didReceiveFileURL:destinationURL];
  [trace didCompleteRequestWithResponse:nil error:nil];
  [FPRNetworkTrace removeNetworkTraceFromObject:connection];
}

@end
