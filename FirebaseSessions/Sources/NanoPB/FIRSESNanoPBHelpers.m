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

#import "FirebaseSessions/Sources/NanoPB/FIRSESNanoPBHelpers.h"

#import <nanopb/pb.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

NS_ASSUME_NONNULL_BEGIN

NSError *FIRSESMakeEncodeError(NSString *description) {
  return [NSError errorWithDomain:@"FIRSESEncodeError"
                             code:-1
                         userInfo:@{@"NSLocalizedDescriptionKey" : description}];
}

// It seems impossible to specify the nullability of the `fields` parameter below,
// yet the compiler complains that it's missing a nullability specifier. Google
// yields no results at this time.
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
  memcpy(pbBytes->bytes, [data bytes], data.length);
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

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
CTTelephonyNetworkInfo *_Nullable FIRSESNetworkInfo(void) {
  static CTTelephonyNetworkInfo *networkInfo;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    networkInfo = [[CTTelephonyNetworkInfo alloc] init];
  });
  return networkInfo;
}
#endif

NSString *_Nullable FIRSESNetworkMobileCountryCode(void) {
#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
  CTTelephonyNetworkInfo *networkInfo = FIRSESNetworkInfo();
  CTCarrier *provider = networkInfo.subscriberCellularProvider;
  return provider.mobileCountryCode;
#endif
  return nil;
}

NSString *_Nullable FIRSESNetworkMobileNetworkCode(void) {
#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
  CTTelephonyNetworkInfo *networkInfo = FIRSESNetworkInfo();
  CTCarrier *provider = networkInfo.subscriberCellularProvider;
  return provider.mobileNetworkCode;
#endif
  return nil;
}

NSString *_Nullable FIRSESValidateMccMnc(NSString *_Nullable mcc, NSString *_Nullable mnc) {
  // These are both nil if the target does not support mobile connectivity
  if (mcc == nil && mnc == nil) {
    return nil;
  }

  if (mcc.length != 3 || mnc.length < 2 || mnc.length > 3) {
    return nil;
  }

  static NSCharacterSet *notDigits;
  static dispatch_once_t token;
  dispatch_once(&token, ^{
    notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
  });
  NSString *mccMnc = [mcc stringByAppendingString:mnc];
  if ([mccMnc rangeOfCharacterFromSet:notDigits].location != NSNotFound) return nil;
  return mccMnc;
}

NS_ASSUME_NONNULL_END
