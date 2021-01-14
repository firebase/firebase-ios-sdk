// Copyright 2019 Google
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

#import "FirebaseSegmentation/Sources/SEGNetworkManager.h"

#import "FirebaseCore/Sources/Private/FIRAppInternal.h"
#import "FirebaseCore/Sources/Private/FIRLogger.h"
#import "FirebaseCore/Sources/Private/FIROptionsInternal.h"

// TODO(dmandar): define in build file.
#define SEG_ALPHA_SERVER

static NSString *const kServerURLDomain = @"https://firebasesegmentation.googleapis.com";

#ifdef SEG_ALPHA_SERVER
static NSString *const kServerURLVersion = @"/v1alpha";
#else
static NSString *const kServerURLVersion = @"/v1";
#endif

static NSString *const kServerURLStringProjects = @"/projects/";
static NSString *const kServerURLStringInstallations = @"/installations/";
static NSString *const kServerURLStringCustomSegmentationData = @"/customSegmentationData";

static NSString *const kHTTPMethodPatch = @"PATCH";
static NSString *const kRequestHeaderAuthorizationValueString = @"FIREBASE_INSTALLATIONS_AUTH";
static NSString *const kRequestDataCustomInstallationIdString = @"custom_installation_id";

// HTTP header names.
static NSString *const kHeaderNameAPIKey = @"x-goog-api-key";
static NSString *const kHeaderNameFirebaseAuthorizationToken = @"Authorization";
static NSString *const kHeaderNameContentType = @"Content-Type";
static NSString *const kHeaderNameContentEncoding = @"Content-Encoding";
static NSString *const kHeaderNameAcceptEncoding = @"Accept-Encoding";

// Sends the bundle ID. Refer to b/130301479 for details.
static NSString *const kiOSBundleIdentifierHeaderName =
    @"X-Ios-Bundle-Identifier";  ///< HTTP Header Field Name

/// Config HTTP request content type JSON
static NSString *const kContentTypeValueJSON = @"application/json";

// TODO: Handle error codes.
/// HTTP status codes. Ref: https://cloud.google.com/apis/design/errors#error_retries
static NSInteger const kSEGResponseHTTPStatusCodeOK = 200;
// static NSInteger const kSEGResponseHTTPStatusCodeConflict = 409;
// static NSInteger const kSEGResponseHTTPStatusTooManyRequests = 429;
// static NSInteger const kSEGResponseHTTPStatusCodeInternalError = 500;
// static NSInteger const kSEGResponseHTTPStatusCodeServiceUnavailable = 503;
// static NSInteger const kSEGResponseHTTPStatusCodeGatewayTimeout = 504;

// HTTP default timeout.
static NSTimeInterval const kSEGHTTPRequestTimeout = 60;

/// Completion handler invoked by URLSession completion handler.
typedef void (^URLSessionCompletion)(NSData *data, NSURLResponse *response, NSError *error);

@implementation SEGNetworkManager {
  FIROptions *_firebaseAppOptions;
  NSURLSession *_URLSession;
}

- (instancetype)initWithOptions:(FIROptions *)options {
  self = [super init];
  if (self) {
    _firebaseAppOptions = options;
    _URLSession = [self newURLSession];
  }
  return self;
}

- (void)dealloc {
  [_URLSession invalidateAndCancel];
}

- (void)makeAssociationRequestToBackendWithData:
            (NSDictionary<NSString *, NSString *> *)associationData
                                          token:(NSString *)token
                                     completion:(SEGRequestCompletion)completionHandler {
  // Construct the server URL.
  NSString *URL = [self constructServerURLWithAssociationData:associationData];
  if (!URL) {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000020", @"Could not construct backend URL.");
    completionHandler(NO, @{kSEGErrorDescription : @"Could not construct backend URL"});
  }

  FIRLogDebug(kFIRLoggerSegmentation, @"I-SEG000019", @"%@",
              [NSString stringWithFormat:@"Making config request: %@", URL]);

  // Construct the request data.
  NSString *customInstallationIdentifier =
      [associationData objectForKey:kSEGCustomInstallationIdentifierKey];
  // TODO: Add tests for nil.
  NSDictionary<NSString *, NSString *> *requestDataDictionary =
      @{kRequestDataCustomInstallationIdString : customInstallationIdentifier};
  NSError *error = nil;
  NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestDataDictionary
                                                        options:0
                                                          error:nil];
  if (!requestData || error) {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000021", @"Could not create request data. %@",
                error.localizedDescription);
    completionHandler(NO,
                      @{kSEGErrorDescription : @"Could not serialize JSON data for network call."});
  }

  // Handle NSURLSession completion.
  __weak SEGNetworkManager *weakSelf = self;
  [self URLSessionDataTaskWithURL:URL
                          content:requestData
                            token:token
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                  SEGNetworkManager *strongSelf = weakSelf;
                  if (!strongSelf) {
                    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000022",
                                @"Internal error making network request.");
                    completionHandler(
                        NO, @{kSEGErrorDescription : @"Internal error making network request."});
                    return;
                  }

                  NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
                  if (!error && (statusCode == kSEGResponseHTTPStatusCodeOK)) {
                    FIRLogDebug(kFIRLoggerSegmentation, @"I-SEG000017",
                                @"SEGNetworkManager: Network request successful.");
                    completionHandler(YES, nil);
                  } else {
                    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000018",
                                @"SEGNetworkManager: Network request failed with status code:%lu",
                                (long)statusCode);
                    completionHandler(NO, @{
                      kSEGErrorDescription :
                          [NSString stringWithFormat:@"Network Error: %lu", (long)statusCode]
                    });
                  };
                }];
}

#pragma mark Private

- (NSURLSession *)newURLSession {
  NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
  config.timeoutIntervalForRequest = kSEGHTTPRequestTimeout;
  config.timeoutIntervalForResource = kSEGHTTPRequestTimeout;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
  return session;
}

- (NSString *)constructServerURLWithAssociationData:
    (NSDictionary<NSString *, NSString *> *)associationData {
  NSString *serverURLStr = [[NSString alloc] initWithString:kServerURLDomain];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLVersion];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLStringProjects];

  if (_firebaseAppOptions.projectID) {
    serverURLStr = [serverURLStr stringByAppendingString:_firebaseAppOptions.projectID];
  } else {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000070",
                @"Missing `projectID` from `FirebaseOptions`, please ensure the configured "
                @"`FirebaseApp` is configured with `FirebaseOptions` that contains a `projectID`.");
    return nil;
  }

  serverURLStr = [serverURLStr stringByAppendingString:kServerURLStringInstallations];

  // Get the FID.
  NSString *firebaseInstallationIdentifier =
      [associationData objectForKey:kSEGFirebaseInstallationIdentifierKey];
  if (!firebaseInstallationIdentifier) {
    FIRLogError(kFIRLoggerSegmentation, @"I-SEG000071",
                @"Missing Firebase installation identifier");
    return nil;
  }
  serverURLStr = [serverURLStr stringByAppendingString:firebaseInstallationIdentifier];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLStringCustomSegmentationData];

  return serverURLStr;
}

- (void)URLSessionDataTaskWithURL:(NSString *)stringURL
                          content:(NSData *)content
                            token:(NSString *)token
                completionHandler:(URLSessionCompletion)completionHandler {
  NSTimeInterval timeoutInterval = kSEGHTTPRequestTimeout;
  NSURL *URL = [NSURL URLWithString:stringURL];
  NSMutableURLRequest *URLRequest =
      [[NSMutableURLRequest alloc] initWithURL:URL
                                   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                               timeoutInterval:timeoutInterval];
  URLRequest.HTTPMethod = kHTTPMethodPatch;

  // Setup headers.
  [URLRequest setValue:_firebaseAppOptions.APIKey forHTTPHeaderField:kHeaderNameAPIKey];
  NSString *authorizationTokenHeaderValue =
      [NSString stringWithFormat:@"%@ %@", kRequestHeaderAuthorizationValueString, token];
  [URLRequest setValue:authorizationTokenHeaderValue
      forHTTPHeaderField:kHeaderNameFirebaseAuthorizationToken];
  // TODO: Check if we accept gzip.
  // [URLRequest setValue:@"gzip" forHTTPHeaderField:kHeaderNameContentEncoding];
  //  [URLRequest setValue:@"gzip" forHTTPHeaderField:kHeaderNameAcceptEncoding];

  // Send the bundleID for API Key restrictions.
  [URLRequest setValue:[[NSBundle mainBundle] bundleIdentifier]
      forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
  [URLRequest setHTTPBody:content];

  NSURLSessionDataTask *task = [_URLSession dataTaskWithRequest:URLRequest
                                              completionHandler:completionHandler];
  [task resume];
}

@end
