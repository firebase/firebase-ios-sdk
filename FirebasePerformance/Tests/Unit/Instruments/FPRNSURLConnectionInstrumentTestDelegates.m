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

#import "FirebasePerformance/Tests/Unit/Instruments/FPRNSURLConnectionInstrumentTestDelegates.h"

#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"

@implementation FPRNSURLConnectionDidReceiveDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  self.connectionDidReceiveDataCalled = YES;
}

// Is required to cause connection:didReceiveData: to be called.
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  self.connectionDidFinishLoadingCalled = YES;
}

@end

@implementation FPRNSURLConnectionTestDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  self.connectionDidFailWithErrorCalled = YES;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(nonnull NSURLRequest *)request
            redirectResponse:(nullable NSURLResponse *)response {
  self.connectionWillSendRequestRedirectResponseCalled = YES;
  return request;
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection
                        destinationURL:(NSURL *)destinationURL {
  self.connectionDidFinishDownloadingDestinationURLCalled = YES;
}

@end

@implementation FPRNSURLConnectionOperationTestDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  self.connectionDidFailWithErrorCalled = YES;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(nonnull NSURLRequest *)request
            redirectResponse:(nullable NSURLResponse *)response {
  self.connectionWillSendRequestRedirectResponseCalled = YES;
  return request;
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection
                        destinationURL:(NSURL *)destinationURL {
  self.connectionDidFinishDownloadingDestinationURLCalled = YES;
}

@end

@implementation FPRNSURLConnectionDataTestDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  self.connectionDidFinishLoadingCalled = YES;
}

@end

@implementation FPRNSURLConnectionDownloadTestDelegate

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection
                        destinationURL:(NSURL *)destinationURL {
  self.connectionDidFinishDownloadingDestinationURLCalled = YES;
}

@end

@implementation FPRNSURLConnectionCompleteTestDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  self.connectionDidFailWithErrorCalled = YES;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(nonnull NSURLRequest *)request
            redirectResponse:(nullable NSURLResponse *)response {
  // If response is nil, this is being called by iOS for URL canonicalization, not for a redirect.
  if (response) {
    self.connectionWillSendRequestRedirectResponseCalled = YES;
  }
  return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  self.connectionDidReceiveResponseCalled = YES;
}

- (void)connection:(NSURLConnection *)connection
              didSendBodyData:(NSInteger)bytesWritten
            totalBytesWritten:(NSInteger)totalBytesWritten
    totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
  self.connectionDidSendBodyDataTotalBytesWrittenTotalBytesExpectedToWriteCalled = YES;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  self.connectionDidFinishLoadingCalled = YES;
}

- (void)connection:(NSURLConnection *)connection
          didWriteData:(long long)bytesWritten
     totalBytesWritten:(long long)totalBytesWritten
    expectedTotalBytes:(long long)expectedTotalBytes {
  self.connectionDidWriteDataTotalBytesWrittenExpectedTotalBytesCalled = YES;
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection
                        destinationURL:(NSURL *)destinationURL {
  self.connectionDidFinishDownloadingDestinationURLCalled = YES;
}

@end
