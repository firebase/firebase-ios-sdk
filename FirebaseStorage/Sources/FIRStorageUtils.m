// Copyright 2017 Google
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

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <MobileCoreServices/MobileCoreServices.h>
#elif TARGET_OS_OSX || TARGET_OS_WATCH
#import <CoreServices/CoreServices.h>
#endif

#import "FirebaseStorage/Sources/FIRStorageUtils.h"

#import "FirebaseStorage/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorage/Sources/FIRStorageErrors.h"
#import "FirebaseStorage/Sources/FIRStoragePath.h"
#import "FirebaseStorage/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorage/Sources/FIRStorage_Private.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#endif

// This is the list at https://cloud.google.com/storage/docs/json_api/ without &, ; and +.
NSString *const kGCSObjectAllowedCharacterSet =
    @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~!$'()*,=:@";

@implementation FIRStorageUtils

+ (nullable NSString *)GCSEscapedString:(NSString *)string {
  NSCharacterSet *allowedCharacters =
      [NSCharacterSet characterSetWithCharactersInString:kGCSObjectAllowedCharacterSet];

  return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

+ (nullable NSString *)MIMETypeForExtension:(NSString *)extension {
  if (extension == nil) {
    return nil;
  }

  CFStringRef pathExtension = (__bridge_retained CFStringRef)extension;
  CFStringRef type =
      UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, NULL);
  NSString *mimeType =
      (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
  CFRelease(pathExtension);
  if (type != NULL) {
    CFRelease(type);
  }

  return mimeType;
}

+ (NSString *)queryStringForDictionary:(nullable NSDictionary *)dictionary {
  if (!dictionary) {
    return @"";
  }

  __block NSMutableArray *queryItems = [[NSMutableArray alloc] initWithCapacity:[dictionary count]];
  [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull name, NSString *_Nonnull value,
                                                  BOOL *_Nonnull stop) {
    NSString *item =
        [FIRStorageUtils GCSEscapedString:[NSString stringWithFormat:@"%@=%@", name, value]];
    [queryItems addObject:item];
  }];
  return [queryItems componentsJoinedByString:@"&"];
}

+ (NSURLRequest *)defaultRequestForReference:(FIRStorageReference *)reference {
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
  NSURLComponents *components = [[NSURLComponents alloc] init];
  [components setScheme:reference.storage.scheme];
  [components setHost:reference.storage.host];
  [components setPort:reference.storage.port];
  NSString *encodedPath = [self encodedURLForPath:reference.path];
  [components setPercentEncodedPath:encodedPath];
  [request setURL:components.URL];
  return request;
}

+ (NSURLRequest *)defaultRequestForReference:(FIRStorageReference *)reference
                                 queryParams:(NSDictionary<NSString *, NSString *> *)queryParams {
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
  NSURLComponents *components = [[NSURLComponents alloc] init];
  [components setScheme:reference.storage.scheme];
  [components setHost:reference.storage.host];
  [components setPort:reference.storage.port];

  NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray new];
  for (NSString *key in queryParams) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:queryParams[key]]];
  }
  [components setQueryItems:queryItems];
  // NSURLComponents does not encode "+" as "%2B". This is however required by our backend, as
  // it treats "+" as a shorthand encoding for spaces. See also
  // https://stackoverflow.com/questions/31577188/how-to-encode-into-2b-with-nsurlcomponents
  [components setPercentEncodedQuery:[[components percentEncodedQuery]
                                         stringByReplacingOccurrencesOfString:@"+"
                                                                   withString:@"%2B"]];

  NSString *encodedPath = [self encodedURLForPath:reference.path];
  [components setPercentEncodedPath:encodedPath];
  [request setURL:components.URL];
  return request;
}

+ (NSString *)encodedURLForPath:(FIRStoragePath *)path {
  NSString *bucketName = [FIRStorageUtils GCSEscapedString:path.bucket];
  NSString *objectName = [FIRStorageUtils GCSEscapedString:path.object];
  NSString *bucketFormat = [NSString stringWithFormat:kFIRStorageBucketPathFormat, bucketName];
  NSString *urlPath = [@"/" stringByAppendingPathComponent:bucketFormat];
  if (objectName) {
    NSString *objectFormat = [NSString stringWithFormat:kFIRStorageObjectPathFormat, objectName];
    urlPath = [urlPath stringByAppendingFormat:@"/%@", objectFormat];
  } else {
    urlPath = [urlPath stringByAppendingString:@"/o"];
  }
  return [@"/" stringByAppendingString:[kFIRStorageVersionPath stringByAppendingString:urlPath]];
}

+ (NSError *)storageErrorWithDescription:(NSString *)description code:(NSInteger)code {
  return [NSError errorWithDomain:FIRStorageErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

+ (NSTimeInterval)computeRetryIntervalFromRetryTime:(NSTimeInterval)retryTime {
  // GTMSessionFetcher's retry starts at 1 second and then doubles every time. We use this
  // information to compute a best-effort estimate of what to translate the user provided retry
  // time into.

  // Note that this is the same as 2 << (log2(retryTime) - 1), but deemed more readable.
  NSTimeInterval lastInterval = 1.0;
  NSTimeInterval sumOfAllIntervals = 1.0;

  while (sumOfAllIntervals < retryTime) {
    lastInterval *= 2;
    sumOfAllIntervals += lastInterval;
  }

  return lastInterval;
}

@end

@implementation NSDictionary (FIRStorageNSDictionaryJSONHelpers)

+ (nullable instancetype)frs_dictionaryFromJSONData:(nullable NSData *)data {
  if (!data) {
    return nil;
  }
  return [NSJSONSerialization JSONObjectWithData:data
                                         options:NSJSONReadingMutableContainers
                                           error:nil];
}

@end

@implementation NSData (FIRStorageNSDataJSONHelpers)

+ (nullable instancetype)frs_dataFromJSONDictionary:(nullable NSDictionary *)dictionary {
  if (!dictionary) {
    return nil;
  }
  return [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
}

@end
