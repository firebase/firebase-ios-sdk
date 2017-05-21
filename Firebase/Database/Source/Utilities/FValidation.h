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
#import "FPath.h"
#import "FIRDataEventType.h"
#import "FParsedUrl.h"
#import "FTypedefs.h"

@interface FValidation : NSObject

+ (void) validateFrom:(NSString *)fn writablePath:(FPath *)path;
+ (void) validateFrom:(NSString *)fn knownEventType:(FIRDataEventType)event;
+ (void) validateFrom:(NSString *)fn validPathString:(NSString *)pathString;
+ (void) validateFrom:(NSString *)fn validRootPathString:(NSString *)pathString;
+ (void) validateFrom:(NSString *)fn validKey:(NSString *)key;
+ (void) validateFrom:(NSString *)fn validURL:(FParsedUrl *)parsedUrl;

+ (void) validateToken:(NSString *)token;

// Functions for handling passing errors back
+ (void) handleError:(NSError *)error withUserCallback:(fbt_void_nserror_id)userCallback;
+ (void) handleError:(NSError *)error withSuccessCallback:(fbt_void_nserror)userCallback;

// Functions used for validating while creating snapshots in FSnapshotUtilities
+ (BOOL) validateFrom:(NSString*)fn isValidLeafValue:(id)value withPath:(NSArray*)path;
+ (void) validateFrom:(NSString*)fn validDictionaryKey:(id)keyId withPath:(NSArray*)path;
+ (void) validateFrom:(NSString*)fn validUpdateDictionaryKey:(id)keyId withValue:(id)value;
+ (void) validateFrom:(NSString*)fn isValidPriorityValue:(id)value withPath:(NSArray*)path;
+ (BOOL) validatePriorityValue:value;

@end
