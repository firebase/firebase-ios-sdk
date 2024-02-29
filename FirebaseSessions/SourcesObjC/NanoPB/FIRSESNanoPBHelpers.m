//
// Copyright 2022 Google LLC
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

#import <GoogleUtilities/GULNetworkInfo.h>

#import "FirebaseSessions/SourcesObjC/NanoPB/FIRSESNanoPBHelpers.h"

#import "FirebaseSessions/SourcesObjC/Protogen/nanopb/sessions.nanopb.h"

@import FirebaseCoreExtension;

#import <nanopb/pb.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>
#import <sys/sysctl.h>

NS_ASSUME_NONNULL_BEGIN

void nanopb_free(void *_Nullable ptr) {
  pb_free(ptr);
}

NSError *FIRSESMakeEncodeError(NSString *description) {
  return [NSError errorWithDomain:@"FIRSESEncodeError"
                             code:-1
                         userInfo:@{@"NSLocalizedDescriptionKey" : description}];
}

NSString *FIRSESPBGetError(pb_istream_t istream) {
  return [NSString stringWithCString:PB_GET_ERROR(&istream) encoding:NSASCIIStringEncoding];
}

// It seems impossible to specify the nullability of the `fields` parameter below,
// yet the compiler complains that it's missing a nullability specifier. Google
// yields no results at this time.
//
// Note 4/17/2023: The warning seems to be spurious (pb_field_t is a non-pointer
// type) and is not present on Xcode 14+. This pragma can be removed after the
// minimum supported Xcode version is above 14.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"
NSData *_Nullable FIRSESEncodeProto(const pb_field_t fields[],
                                    const void *_Nonnull proto,
                                    NSError **error) {
  pb_ostream_t sizestream = PB_OSTREAM_SIZING;

  // Encode 1 time to determine the size.
  if (!pb_encode(&sizestream, fields, proto)) {
    NSString *errorString = [NSString
        stringWithFormat:@"Error in nanopb encoding to get size: %s", PB_GET_ERROR(&sizestream)];
    if (error != NULL) {
      *error = FIRSESMakeEncodeError(errorString);
    }
    return nil;
  }

  // Encode a 2nd time to actually get the bytes from it.
  size_t bufferSize = sizestream.bytes_written;
  CFMutableDataRef dataRef = CFDataCreateMutable(CFAllocatorGetDefault(), bufferSize);
  CFDataSetLength(dataRef, bufferSize);
  pb_ostream_t ostream = pb_ostream_from_buffer((void *)CFDataGetBytePtr(dataRef), bufferSize);
  if (!pb_encode(&ostream, fields, proto)) {
    NSString *errorString =
        [NSString stringWithFormat:@"Error in nanopb encoding: %s", PB_GET_ERROR(&sizestream)];
    if (error != NULL) {
      *error = FIRSESMakeEncodeError(errorString);
    }
    CFBridgingRelease(dataRef);
    return nil;
  }

  return CFBridgingRelease(dataRef);
}
#pragma clang diagnostic pop

/** Mallocs a pb_bytes_array and copies the given NSData bytes into the bytes array.
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param data The data to copy into the new bytes array.
 */
pb_bytes_array_t *_Nullable FIRSESEncodeData(NSData *_Nullable data) {
  pb_bytes_array_t *pbBytes = malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(data.length));
  if (pbBytes == NULL) {
    return NULL;
  }
  [data getBytes:pbBytes->bytes length:data.length];
  pbBytes->size = (pb_size_t)data.length;
  return pbBytes;
}

/** Mallocs a pb_bytes_array and copies the given NSString's bytes into the bytes array.
 * @note Memory needs to be freed manually, through pb_free or pb_release.
 * @param string The string to encode as pb_bytes.
 */
pb_bytes_array_t *_Nullable FIRSESEncodeString(NSString *_Nullable string) {
  if ([string isMemberOfClass:[NSNull class]]) {
    string = nil;
  }
  NSString *stringToEncode = string ? string : @"";
  NSData *stringBytes = [stringToEncode dataUsingEncoding:NSUTF8StringEncoding];
  return FIRSESEncodeData(stringBytes);
}

NSData *FIRSESDecodeData(pb_bytes_array_t *pbData) {
  NSData *data = [NSData dataWithBytes:&(pbData->bytes) length:pbData->size];
  return data;
}

NSString *FIRSESDecodeString(pb_bytes_array_t *pbData) {
  if (pbData->size == 0) {
    return @"";
  }
  NSData *data = FIRSESDecodeData(pbData);
  // There was a bug where length 32 strings were sometimes null after encoding
  // and decoding. We found that this was due to the null terminator sometimes not
  // being included in the decoded code. Using stringWithCString assumes the string
  // is null terminated, so we switched to initWithBytes because it takes a length.
  return [[NSString alloc] initWithBytes:data.bytes
                                  length:data.length
                                encoding:NSUTF8StringEncoding];
}

BOOL FIRSESIsPBArrayEqual(pb_bytes_array_t *_Nullable array, pb_bytes_array_t *_Nullable expected) {
  // Treat the empty string as the same as a missing field
  if (array == nil) {
    return expected->size == 0;
  }

  if (array->size != expected->size) {
    return false;
  }

  for (int i = 0; i < array->size; i++) {
    if (expected->bytes[i] != array->bytes[i]) {
      return false;
    }
  }

  return true;
}

BOOL FIRSESIsPBStringEqual(pb_bytes_array_t *_Nullable pbString, NSString *_Nullable str) {
  pb_bytes_array_t *expected = FIRSESEncodeString(str);
  return FIRSESIsPBArrayEqual(pbString, expected);
}

BOOL FIRSESIsPBDataEqual(pb_bytes_array_t *_Nullable pbArray, NSData *_Nullable data) {
  pb_bytes_array_t *expected = FIRSESEncodeData(data);
  BOOL equal = FIRSESIsPBArrayEqual(pbArray, expected);
  free(expected);
  return equal;
}

pb_size_t FIRSESGetAppleApplicationInfoTag(void) {
  return firebase_appquality_sessions_ApplicationInfo_apple_app_info_tag;
}

/// Copied from a private method in GULAppEnvironmentUtil.
NSString *_Nullable FIRSESGetSysctlEntry(const char *sysctlKey) {
  static NSString *entryValue;
  size_t size;
  sysctlbyname(sysctlKey, NULL, &size, NULL, 0);
  if (size > 0) {
    char *entryValueCStr = malloc(size);
    sysctlbyname(sysctlKey, entryValueCStr, &size, NULL, 0);
    entryValue = [NSString stringWithCString:entryValueCStr encoding:NSUTF8StringEncoding];
    free(entryValueCStr);
    return entryValue;
  } else {
    return nil;
  }
}

NSData *FIRSESTransportBytes(const void *_Nonnull proto) {
  const pb_field_t *fields = firebase_appquality_sessions_SessionEvent_fields;
  NSError *error;
  NSData *data = FIRSESEncodeProto(fields, proto, &error);
  if (error != nil) {
    FIRLogError(
        @"FirebaseSessions", @"I-SES000001", @"%@",
        [NSString stringWithFormat:@"Session Event failed to encode as proto with error: %@",
                                   error.debugDescription]);
  }
  if (data == nil) {
    data = [NSData data];
    FIRLogError(@"FirebaseSessions", @"I-SES000002",
                @"Session Event generated nil transportBytes. Returning empty data.");
  }
  return data;
}

NS_ASSUME_NONNULL_END
