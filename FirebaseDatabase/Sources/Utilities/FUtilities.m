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

#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Utilities/FAtomicNumber.h"
#import "FirebaseDatabase/Sources/Utilities/FStringUtilities.h"

#define ARC4RANDOM_MAX 0x100000000

#pragma mark -
#pragma mark C functions

FIRLoggerService kFIRLoggerDatabase = @"[Firebase/Database]";
static FLogLevel logLevel = FLogLevelInfo; // Default log level is info
static NSMutableDictionary *options = nil;

BOOL FFIsLoggingEnabled(FLogLevel level) { return level >= logLevel; }

void firebaseJobsTroll(void) {
    FFLog(@"I-RDB095001",
          @"password super secret; JFK conspiracy; Hello there! Having fun "
          @"digging through Firebase? We're always hiring! jobs@firebase.com");
}

#pragma mark -
#pragma mark Private property and singleton specification

@interface FUtilities () {
}

@property(nonatomic, strong) FAtomicNumber *localUid;

+ (FUtilities *)singleton;

@end

@implementation FUtilities

@synthesize localUid;

- (id)init {
    self = [super init];
    if (self) {
        self.localUid = [[FAtomicNumber alloc] init];
    }
    return self;
}

// TODO: We really want to be able to set the log level
+ (void)setLoggingEnabled:(BOOL)enabled {
    logLevel = enabled ? FLogLevelDebug : FLogLevelInfo;
}

+ (BOOL)getLoggingEnabled {
    return logLevel == FLogLevelDebug;
}

+ (FUtilities *)singleton {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
      _sharedObject = [[self alloc] init]; // or some other init method
    });
    return _sharedObject;
}

// Refactor as a category of NSString
+ (NSArray *)splitString:(NSString *)str intoMaxSize:(const unsigned int)size {
    if (str.length <= size) {
        return [NSArray arrayWithObject:str];
    }

    NSMutableArray *dataSegs = [[NSMutableArray alloc] init];
    for (int c = 0; c < str.length; c += size) {
        if (c + size > str.length) {
            int rangeStart = c;
            unsigned long rangeLength = size - ((c + size) - str.length);
            [dataSegs
                addObject:[str substringWithRange:NSMakeRange(rangeStart,
                                                              rangeLength)]];
        } else {
            int rangeStart = c;
            int rangeLength = size;
            [dataSegs
                addObject:[str substringWithRange:NSMakeRange(rangeStart,
                                                              rangeLength)]];
        }
    }
    return dataSegs;
}

+ (NSNumber *)LUIDGenerator {
    FUtilities *f = [FUtilities singleton];
    return [f.localUid getAndIncrement];
}

+ (NSString *)decodePath:(NSString *)pathString {
    NSMutableArray *decodedPieces = [[NSMutableArray alloc] init];
    NSArray *pieces = [pathString componentsSeparatedByString:@"/"];
    for (NSString *piece in pieces) {
        if (piece.length > 0) {
            [decodedPieces addObject:[FStringUtilities urlDecoded:piece]];
        }
    }
    return [NSString
        stringWithFormat:@"/%@", [decodedPieces componentsJoinedByString:@"/"]];
}

+ (NSString *)extractPathFromUrlString:(NSString *)url {
    NSString *path = url;

    NSRange schemeIndex = [path rangeOfString:@"//"];
    if (schemeIndex.location != NSNotFound) {
        path = [path substringFromIndex:schemeIndex.location + 2];
    }

    NSUInteger pathIndex = [path rangeOfString:@"/"].location;
    if (pathIndex != NSNotFound) {
        path = [path substringFromIndex:pathIndex + 1];
    } else {
        path = @"";
    }

    NSUInteger queryParamIndex = [path rangeOfString:@"?"].location;
    if (queryParamIndex != NSNotFound) {
        path = [path substringToIndex:queryParamIndex];
    }

    return path;
}

+ (FParsedUrl *)parseUrl:(NSString *)url {
    // For backwards compatibility, support URLs without schemes on iOS.
    if (![url containsString:@"://"]) {
        url = [@"http://" stringByAppendingString:url];
    }

    NSString *originalPathString = [self extractPathFromUrlString:url];

    // Sanitize the database URL by removing the path component, which may
    // contain invalid URL characters.
    NSRange lastMatch = [url rangeOfString:originalPathString
                                   options:NSBackwardsSearch];
    NSString *sanitizedUrlWithoutPath =
        (lastMatch.location != NSNotFound)
            ? [url substringToIndex:lastMatch.location]
            : url;

    NSURLComponents *urlComponents =
        [NSURLComponents componentsWithString:sanitizedUrlWithoutPath];
    if (!urlComponents) {
        [NSException raise:@"Failed to parse database URL"
                    format:@"Failed to parse database URL: %@", url];
    }

    NSString *host = [urlComponents.host lowercaseString];
    NSString *namespace;
    bool secure;

    if (urlComponents.port != nil) {
        secure = [urlComponents.scheme isEqualToString:@"https"] ||
                 [urlComponents.scheme isEqualToString:@"wss"];
        host = [host stringByAppendingFormat:@":%@", urlComponents.port];
    } else {
        secure = YES;
    };

    NSArray *parts = [urlComponents.host componentsSeparatedByString:@"."];
    if ([parts count] == 3) {
        namespace = [parts[0] lowercaseString];
    } else {
        // Attempt to extract namespace from "ns" query param.
        NSArray *queryItems = urlComponents.queryItems;
        for (NSURLQueryItem *item in queryItems) {
            if ([item.name isEqualToString:@"ns"]) {
                namespace = item.value;
                break;
            }
        }

        if (!namespace) {
            namespace = [parts[0] lowercaseString];
        }
    }

    NSString *pathString = [self
        decodePath:[NSString stringWithFormat:@"/%@", originalPathString]];
    FPath *path = [[FPath alloc] initWith:pathString];
    FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:host
                                                 isSecure:secure
                                            withNamespace:namespace];

    FFLog(@"I-RDB095002", @"---> Parsed (%@) to: (%@,%@); ns=(%@); path=(%@)",
          url, [repoInfo description], [repoInfo connectionURL],
          repoInfo.namespace, [path description]);

    FParsedUrl *parsedUrl = [[FParsedUrl alloc] init];
    parsedUrl.repoInfo = repoInfo;
    parsedUrl.path = path;

    return parsedUrl;
}

/*
 case str: JString => priString + "string:" + str.s;
 case bool: JBool => priString + "boolean:" + bool.value;
 case double: JDouble => priString + "number:" + double.num;
 case int: JInt => priString + "number:" + int.num;
 case _ => {
 error("Leaf node has value '" + data.value + "' of invalid type '" +
 data.value.getClass.toString + "'");
 "";
 }
 */

+ (NSString *)getJavascriptType:(id)obj {
    if ([obj isKindOfClass:[NSDictionary class]]) {
        return kJavaScriptObject;
    } else if ([obj isKindOfClass:[NSString class]]) {
        return kJavaScriptString;
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        // We used to just compare to @encode(BOOL) as suggested at
        // http://stackoverflow.com/questions/2518761/get-type-of-nsnumber, but
        // on arm64, @encode(BOOL) returns "B" instead of "c" even though
        // objCType still returns 'c' (signed char).  So check both.
        if (strcmp([obj objCType], @encode(BOOL)) == 0 ||
            strcmp([obj objCType], @encode(signed char)) == 0) {
            return kJavaScriptBoolean;
        } else {
            return kJavaScriptNumber;
        }
    } else {
        return kJavaScriptNull;
    }
}

+ (NSError *)errorForStatus:(NSString *)status andReason:(NSString *)reason {
    static dispatch_once_t pred = 0;
    __strong static NSDictionary *errorMap = nil;
    __strong static NSDictionary *errorCodes = nil;
    dispatch_once(&pred, ^{
      errorMap = @{
          @"permission_denied" : @"Permission Denied",
          @"unavailable" : @"Service is unavailable",
          kFErrorWriteCanceled : @"Write cancelled by user"
      };
      errorCodes = @{
          @"permission_denied" : @1,
          @"unavailable" : @2,
          kFErrorWriteCanceled : @3
      };
    });

    if ([status isEqualToString:kFWPResponseForActionStatusOk]) {
        return nil;
    } else {
        NSInteger code;
        NSString *desc = nil;
        if (reason) {
            desc = reason;
        } else if ([errorMap objectForKey:status] != nil) {
            desc = [errorMap objectForKey:status];
        } else {
            desc = status;
        }

        if ([errorCodes objectForKey:status] != nil) {
            NSNumber *num = [errorCodes objectForKey:status];
            code = [num integerValue];
        } else {
            // XXX what to do here?
            code = 9999;
        }

        return [[NSError alloc]
            initWithDomain:kFErrorDomain
                      code:code
                  userInfo:@{NSLocalizedDescriptionKey : desc}];
    }
}

+ (NSNumber *)intForString:(NSString *)string {
    static NSCharacterSet *notDigits = nil;
    if (!notDigits) {
        notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    }
    if ([string rangeOfCharacterFromSet:notDigits].length == 0) {
        NSInteger num;
        NSScanner *scanner = [NSScanner scannerWithString:string];
        if ([scanner scanInteger:&num]) {
            return [NSNumber numberWithInteger:num];
        }
    }
    return nil;
}

+ (NSInteger)int32min {
    return INTEGER_32_MIN;
}

+ (NSInteger)int32max {
    return INTEGER_32_MAX;
}

+ (NSString *)ieee754StringForNumber:(NSNumber *)val {
    double d = [val doubleValue];
    NSData *data = [NSData dataWithBytes:&d length:sizeof(double)];
    NSMutableString *str = [[NSMutableString alloc] init];
    const unsigned char *buffer = (const unsigned char *)[data bytes];
    for (int i = 0; i < data.length; i++) {
        unsigned char byte = buffer[7 - i];
        [str appendFormat:@"%02x", byte];
    }
    return str;
}

+ (BOOL)tryParseString:(NSString *)string asInt:(NSInteger *)integer {
    return tryParseStringToInt(string, integer);
}

static inline BOOL tryParseStringToInt(__unsafe_unretained NSString *str,
                                       NSInteger *integer) {
    // First do some cheap checks (NOTE: The below checks are significantly
    // faster than an equivalent regex :-( ).
    NSUInteger length = str.length;
    if (length > 11 || length == 0) {
        return NO;
    }
    long long value = 0;
    BOOL negative = NO;
    NSUInteger i = 0;
    if ([str characterAtIndex:0] == '-') {
        if (length == 1) {
            return NO;
        }
        negative = YES;
        i = 1;
    }
    for (; i < length; i++) {
        unichar c = [str characterAtIndex:i];
        // Must be a digit, or '-' if it's the first char.
        if (c < '0' || c > '9') {
            return NO;
        } else {
            int charValue = c - '0';
            value = value * 10 + charValue;
        }
    }

    value = (negative) ? -value : value;

    if (value < INTEGER_32_MIN || value > INTEGER_32_MAX) {
        return NO;
    } else {
        *integer = (NSInteger)value;
        return YES;
    }
}

+ (NSString *)maxName {
    static dispatch_once_t once;
    static NSString *maxName;
    dispatch_once(&once, ^{
      maxName = [[NSString alloc] initWithFormat:@"[MAX_NAME]"];
    });
    return maxName;
}

+ (NSString *)minName {
    static dispatch_once_t once;
    static NSString *minName;
    dispatch_once(&once, ^{
      minName = [[NSString alloc] initWithFormat:@"[MIN_NAME]"];
    });
    return minName;
}

+ (NSComparisonResult)compareKey:(NSString *)a toKey:(NSString *)b {
    if (a == b) {
        return NSOrderedSame;
    } else if (a == [FUtilities minName] || b == [FUtilities maxName]) {
        return NSOrderedAscending;
    } else if (b == [FUtilities minName] || a == [FUtilities maxName]) {
        return NSOrderedDescending;
    } else {
        NSInteger aAsInt, bAsInt;
        if (tryParseStringToInt(a, &aAsInt)) {
            if (tryParseStringToInt(b, &bAsInt)) {
                if (aAsInt > bAsInt) {
                    return NSOrderedDescending;
                } else if (aAsInt < bAsInt) {
                    return NSOrderedAscending;
                } else if (a.length > b.length) {
                    return NSOrderedDescending;
                } else if (a.length < b.length) {
                    return NSOrderedAscending;
                } else {
                    return NSOrderedSame;
                }
            } else {
                return (NSComparisonResult)NSOrderedAscending;
            }
        } else if (tryParseStringToInt(b, &bAsInt)) {
            return (NSComparisonResult)NSOrderedDescending;
        } else {
            // Perform literal character by character search to prevent a > b &&
            // b > a issues. Note that calling -(NSString
            // *)decomposedStringWithCanonicalMapping also works.
            return [a compare:b options:NSLiteralSearch];
        }
    }
}

+ (NSComparator)keyComparator {
    return ^NSComparisonResult(__unsafe_unretained NSString *a,
                               __unsafe_unretained NSString *b) {
      return [FUtilities compareKey:a toKey:b];
    };
}

+ (NSComparator)stringComparator {
    return ^NSComparisonResult(__unsafe_unretained NSString *a,
                               __unsafe_unretained NSString *b) {
      return [a compare:b];
    };
}

+ (double)randomDouble {
    return ((double)arc4random() / ARC4RANDOM_MAX);
}

@end
