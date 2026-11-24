/*
 * Copyright 2026 Google LLC
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

#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsFakeBackend.h"

static NSString *const kFakeBackendHost = @"firebaseinstallations.googleapis.com";
static NSString *const kFakeBackendTokenLifetime = @"604800s";

#pragma mark - FIRInstallationsFakeBackendRequest

@implementation FIRInstallationsFakeBackendRequest

- (instancetype)initWithHTTPMethod:(NSString *)HTTPMethod
                              path:(NSString *)path
                           headers:(NSDictionary<NSString *, NSString *> *)headers
                          JSONBody:(nullable NSDictionary *)JSONBody {
  self = [super init];
  if (self) {
    _HTTPMethod = [HTTPMethod copy];
    _path = [path copy];
    _headers = [headers copy];
    _JSONBody = [JSONBody copy];
  }
  return self;
}

- (nullable NSString *)valueForHeader:(NSString *)name {
  for (NSString *key in self.headers) {
    if ([key caseInsensitiveCompare:name] == NSOrderedSame) {
      return self.headers[key];
    }
  }
  return nil;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ %@", self.HTTPMethod, self.path];
}

@end

#pragma mark - FIRInstallationsFakeBackend

@interface FIRInstallationsFakeBackend ()
@property(nonatomic, readonly) NSString *projectID;
@property(nonatomic, readonly) NSString *APIKey;
@property(nonatomic, readonly)
    NSMutableArray<FIRInstallationsFakeBackendRequest *> *mutableRequests;
/// FID -> refresh token.
@property(nonatomic, readonly) NSMutableDictionary<NSString *, NSString *> *refreshTokens;
/// FID -> last issued auth token.
@property(nonatomic, readonly) NSMutableDictionary<NSString *, NSString *> *authTokens;
@property(nonatomic) NSUInteger tokenCounter;

- (NSHTTPURLResponse *)responseForRequest:(NSURLRequest *)request
                                 bodyData:(nullable NSData *)bodyData
                             responseData:(NSData *_Nullable *_Nonnull)responseData;
@end

/// A data task that runs its work when it's resumed, like `NSURLSessionDataTask`.
@interface FIRInstallationsFakeBackendDataTask : NSURLSessionDataTask
- (instancetype)initWithWork:(dispatch_block_t)work;
@end

@implementation FIRInstallationsFakeBackendDataTask {
  dispatch_block_t _work;
}

- (instancetype)initWithWork:(dispatch_block_t)work {
  // `-[NSURLSessionDataTask init]` is deprecated for direct use, but subclasses that override all
  // the methods the SDK calls still need it.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  self = [super init];
#pragma clang diagnostic pop
  if (self) {
    _work = [work copy];
  }
  return self;
}

- (void)resume {
  dispatch_block_t work;
  @synchronized(self) {
    work = _work;
    _work = nil;
  }
  if (work) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), work);
  }
}

- (void)cancel {
  @synchronized(self) {
    _work = nil;
  }
}

@end

/// A URL session that passes requests directly to a `FIRInstallationsFakeBackend`, so they never
/// reach the network. A custom `NSURLProtocol` isn't used because watchOS ignores the
/// `protocolClasses` of a session configuration.
@interface FIRInstallationsFakeBackendURLSession : NSURLSession
- (instancetype)initWithBackend:(FIRInstallationsFakeBackend *)backend;
@end

@implementation FIRInstallationsFakeBackendURLSession {
  __weak FIRInstallationsFakeBackend *_backend;
}

- (instancetype)initWithBackend:(FIRInstallationsFakeBackend *)backend {
  // See `-[FIRInstallationsFakeBackendDataTask initWithWork:]`.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  self = [super init];
#pragma clang diagnostic pop
  if (self) {
    _backend = backend;
  }
  return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:
                                (void (^)(NSData *_Nullable data,
                                          NSURLResponse *_Nullable response,
                                          NSError *_Nullable error))completionHandler {
  NSURLRequest *requestCopy = [request copy];
  __weak FIRInstallationsFakeBackend *weakBackend = _backend;
  return [[FIRInstallationsFakeBackendDataTask alloc] initWithWork:^{
    FIRInstallationsFakeBackend *backend = weakBackend;
    if (backend == nil) {
      completionHandler(nil, nil,
                        [NSError errorWithDomain:NSURLErrorDomain
                                            code:NSURLErrorCannotConnectToHost
                                        userInfo:nil]);
      return;
    }

    NSData *responseData;
    NSHTTPURLResponse *response = [backend responseForRequest:requestCopy
                                                     bodyData:requestCopy.HTTPBody
                                                 responseData:&responseData];
    completionHandler(responseData, response, nil);
  }];
}

@end

@implementation FIRInstallationsFakeBackend

- (instancetype)initWithProjectID:(NSString *)projectID APIKey:(NSString *)APIKey {
  self = [super init];
  if (self) {
    _projectID = [projectID copy];
    _APIKey = [APIKey copy];
    _mutableRequests = [NSMutableArray array];
    _refreshTokens = [NSMutableDictionary dictionary];
    _authTokens = [NSMutableDictionary dictionary];

    _URLSession = [[FIRInstallationsFakeBackendURLSession alloc] initWithBackend:self];
  }
  return self;
}

#pragma mark - State

- (NSArray<FIRInstallationsFakeBackendRequest *> *)requests {
  @synchronized(self) {
    return [self.mutableRequests copy];
  }
}

- (BOOL)hasInstallationWithFID:(NSString *)FID {
  return [self refreshTokenForFID:FID] != nil;
}

- (nullable NSString *)refreshTokenForFID:(NSString *)FID {
  @synchronized(self) {
    return self.refreshTokens[FID];
  }
}

- (nullable NSString *)authTokenForFID:(NSString *)FID {
  @synchronized(self) {
    return self.authTokens[FID];
  }
}

- (void)forgetInstallationWithFID:(NSString *)FID {
  @synchronized(self) {
    [self.refreshTokens removeObjectForKey:FID];
    [self.authTokens removeObjectForKey:FID];
  }
}

#pragma mark - Request handling

- (NSHTTPURLResponse *)responseForRequest:(NSURLRequest *)request
                                 bodyData:(nullable NSData *)bodyData
                             responseData:(NSData *_Nullable *_Nonnull)responseData {
  NSDictionary *JSONBody;
  if (bodyData.length > 0) {
    id JSONObject = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:nil];
    JSONBody = [JSONObject isKindOfClass:[NSDictionary class]] ? JSONObject : nil;
  }

  // `NSURL.path` drops the trailing slash the SDK adds to some paths.
  NSString *path = request.URL.path ?: @"";
  FIRInstallationsFakeBackendRequest *recordedRequest = [[FIRInstallationsFakeBackendRequest alloc]
      initWithHTTPMethod:request.HTTPMethod ?: @""
                    path:path
                 headers:request.allHTTPHeaderFields ?: @{}
                JSONBody:JSONBody];

  NSInteger statusCode;
  NSDictionary *responseJSON;
  @synchronized(self) {
    [self.mutableRequests addObject:recordedRequest];
    statusCode = [self handleRequest:recordedRequest
                                host:request.URL.host
                        responseJSON:&responseJSON];
  }

  *responseData = [NSJSONSerialization dataWithJSONObject:responseJSON ?: @{} options:0 error:nil];
  return [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                     statusCode:statusCode
                                    HTTPVersion:@"HTTP/1.1"
                                   headerFields:@{@"Content-Type" : @"application/json"}];
}

/// Must be called while synchronized on `self`.
- (NSInteger)handleRequest:(FIRInstallationsFakeBackendRequest *)request
                      host:(nullable NSString *)host
              responseJSON:(NSDictionary *_Nullable *_Nonnull)responseJSON {
  if (![host isEqualToString:kFakeBackendHost]) {
    *responseJSON = [self errorJSONWithCode:404 message:@"Unknown host"];
    return 404;
  }

  if (![[request valueForHeader:@"X-Goog-Api-Key"] isEqualToString:self.APIKey]) {
    *responseJSON = [self errorJSONWithCode:403 message:@"Invalid API key"];
    return 403;
  }

  NSString *installationsPath =
      [NSString stringWithFormat:@"/v1/projects/%@/installations", self.projectID];
  if (![request.path hasPrefix:installationsPath]) {
    *responseJSON = [self errorJSONWithCode:404 message:@"Unknown project"];
    return 404;
  }

  // The rest of the path is empty, "/{FID}" or "/{FID}/authTokens:generate".
  NSString *subpath = [request.path substringFromIndex:installationsPath.length];
  NSArray<NSString *> *components = [subpath componentsSeparatedByString:@"/"];

  if (subpath.length == 0 && [request.HTTPMethod isEqualToString:@"POST"]) {
    return [self handleRegistration:request responseJSON:responseJSON];
  }

  if (components.count == 3 && [components[2] isEqualToString:@"authTokens:generate"] &&
      [request.HTTPMethod isEqualToString:@"POST"]) {
    return [self handleGenerateAuthTokenForFID:components[1]
                                       request:request
                                  responseJSON:responseJSON];
  }

  if (components.count == 2 && [request.HTTPMethod isEqualToString:@"DELETE"]) {
    return [self handleDeleteForFID:components[1] request:request responseJSON:responseJSON];
  }

  *responseJSON = [self errorJSONWithCode:404 message:@"Unknown method"];
  return 404;
}

- (NSInteger)handleRegistration:(FIRInstallationsFakeBackendRequest *)request
                   responseJSON:(NSDictionary *_Nullable *_Nonnull)responseJSON {
  NSString *requestedFID = request.JSONBody[@"fid"];
  if (![requestedFID isKindOfClass:[NSString class]] || requestedFID.length == 0 ||
      ![request.JSONBody[@"authVersion"] isEqual:@"FIS_v2"]) {
    *responseJSON = [self errorJSONWithCode:400 message:@"Invalid registration request"];
    return 400;
  }

  NSString *FID = self.FIDForNextRegistration ?: requestedFID;
  self.FIDForNextRegistration = nil;

  NSString *refreshToken = [self nextTokenWithPrefix:@"refresh-token"];
  NSString *authToken = [self nextTokenWithPrefix:@"auth-token"];
  self.refreshTokens[FID] = refreshToken;
  self.authTokens[FID] = authToken;

  *responseJSON = @{
    @"name" : [NSString stringWithFormat:@"projects/%@/installations/%@", self.projectID, FID],
    @"fid" : FID,
    @"refreshToken" : refreshToken,
    @"authToken" : @{@"token" : authToken, @"expiresIn" : kFakeBackendTokenLifetime},
  };
  return 200;
}

- (NSInteger)handleGenerateAuthTokenForFID:(NSString *)FID
                                   request:(FIRInstallationsFakeBackendRequest *)request
                              responseJSON:(NSDictionary *_Nullable *_Nonnull)responseJSON {
  NSInteger authStatus = [self authorizationStatusForFID:FID request:request];
  if (authStatus != 200) {
    *responseJSON = [self errorJSONWithCode:authStatus message:@"Unauthorized"];
    return authStatus;
  }

  NSString *authToken = [self nextTokenWithPrefix:@"auth-token"];
  self.authTokens[FID] = authToken;
  *responseJSON = @{@"token" : authToken, @"expiresIn" : kFakeBackendTokenLifetime};
  return 200;
}

- (NSInteger)handleDeleteForFID:(NSString *)FID
                        request:(FIRInstallationsFakeBackendRequest *)request
                   responseJSON:(NSDictionary *_Nullable *_Nonnull)responseJSON {
  NSInteger authStatus = [self authorizationStatusForFID:FID request:request];
  if (authStatus != 200) {
    *responseJSON = [self errorJSONWithCode:authStatus message:@"Unauthorized"];
    return authStatus;
  }

  [self.refreshTokens removeObjectForKey:FID];
  [self.authTokens removeObjectForKey:FID];
  *responseJSON = @{};
  return 200;
}

/// Returns 200 if the request carries the installation's refresh token, 404 if the installation
/// doesn't exist, or 401 otherwise.
- (NSInteger)authorizationStatusForFID:(NSString *)FID
                               request:(FIRInstallationsFakeBackendRequest *)request {
  NSString *refreshToken = self.refreshTokens[FID];
  if (refreshToken == nil) {
    return 404;
  }

  NSString *expectedHeader = [@"FIS_v2 " stringByAppendingString:refreshToken];
  if (![[request valueForHeader:@"Authorization"] isEqualToString:expectedHeader]) {
    return 401;
  }
  return 200;
}

- (NSString *)nextTokenWithPrefix:(NSString *)prefix {
  self.tokenCounter += 1;
  return [NSString stringWithFormat:@"%@-%lu", prefix, (unsigned long)self.tokenCounter];
}

- (NSDictionary *)errorJSONWithCode:(NSInteger)code message:(NSString *)message {
  return @{@"error" : @{@"code" : @(code), @"message" : message}};
}

@end
