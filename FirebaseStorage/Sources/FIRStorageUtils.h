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

@class FIRStoragePath;
@class FIRStorageReference;

NS_ASSUME_NONNULL_BEGIN

/**
 * FIRStorageUtils provides a number of helper methods for commonly used operations
 * in Firebase Storage, such as JSON parsing, escaping, and file extensions.
 */
@interface FIRStorageUtils : NSObject

/**
 * Returns a percent encoded string appropriate for GCS.
 * See https://cloud.google.com/storage/docs/naming for more details.
 * @param string A path to escape characters according to the GCS
 * @return A percent encoded string appropriate for GCS operations or nil if string is nil
 * or can't be escaped.
 */
+ (nullable NSString *)GCSEscapedString:(NSString *)string;

/**
 * Returns the MIME type for a file extension.
 * Example of how to get MIME type here: http://ddeville.me/2011/12/mime-to-UTI-cocoa/
 * @param extension A file extension such as "txt", "png", etc.
 * @return The MIME type for the input extension such as "text/plain", "image/png", etc.
 * or nil if no type is found.
 */
+ (nullable NSString *)MIMETypeForExtension:(NSString *)extension;

/**
 * Returns a properly escaped query string from a given dictionary of query items to values.
 * @param dictionary A dictionary containing query items and associated values.
 * @return A properly escaped query string or the empty string for a nil or empty dictionary.
 */
+ (NSString *)queryStringForDictionary:(nullable NSDictionary *)dictionary;

/**
 * Returns a base NSURLRequest used by all tasks.
 * @param reference The FIRStorageReference to create a request for.
 * @return Returns a properly formatted NSURLRequest of the form:
 * scheme://host/version/b/<bucket>/o[/path/to/object]
 */
+ (NSURLRequest *)defaultRequestForReference:(FIRStorageReference *)reference;

/**
 * Returns a base NSURLRequest with custom query parameters.
 * @param reference The FIRStorageReference to create a request for.
 * @param queryParams A key/value dictionary with query parameters.
 * @return Returns a formatted NSURLRequest
 */
+ (NSURLRequest *)defaultRequestForReference:(FIRStorageReference *)reference
                                 queryParams:(NSDictionary<NSString *, NSString *> *)queryParams;

/**
 * Creates the appropriate GCS percent escaped path for a given FIRStoragePath.
 * @param path The FIRStoragePath to encode.
 * @return Returns the GCS encoded URL for a given FIRStoragePath.
 */
+ (NSString *)encodedURLForPath:(FIRStoragePath *)path;

/**
 * Creates a NSError in the Firebase Storage domain with given code and description.
 * Useful for argument validation.
 * @param description The error description to surface to the user.
 * @param code The error code.
 * @return An NSError in the Firebase Storage error domain.
 */
+ (NSError *)storageErrorWithDescription:(NSString *)description code:(NSInteger)code;

/**
 * Performs a crude translation of the user provided timeouts to the retry intervals that
 * GTMSessionFetcher accepts. GTMSessionFetcher times out operations if the time between individual
 * retry attempts exceed a certain threshold, while our API contract looks at the total observed
 * time of the operation (i.e. the sum of all retries).
 * @param retryTime A timeout that caps the sum of all retry attempts
 * @return A timeout that caps the timeout of the last retry attempt
 */
+ (NSTimeInterval)computeRetryIntervalFromRetryTime:(NSTimeInterval)retryTime;

@end

@interface NSDictionary (FIRStorageNSDictionaryJSONHelpers)

/**
 * Returns a dictionary representation of the data in @a data.
 * @param data NSData containing JSON data.
 * @return An NSDictionary representation of the JSON, or nil if serialization failed.
 */
+ (nullable instancetype)frs_dictionaryFromJSONData:(nullable NSData *)data;

@end

@interface NSData (FIRStorageNSDataJSONHelpers)

/**
 * Returns an NSData instance containing JSON serialized from @a dictionary.
 * @param dictionary An NSDictionary containing only types serializable to JSON.
 * @return An NSData object representing the binary JSON, or nil if serialization failed.
 */
+ (nullable instancetype)frs_dataFromJSONDictionary:(nullable NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
