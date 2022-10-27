/*
 * Copyright 2018 Google
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

#import <XCTest/XCTest.h>

#import "FirebaseDynamicLinks/Sources/Utilities/FDLUtilities.h"

static NSString *const kURLScheme = @"gindeeplinkurl";

@interface FDLUtilitiesTests : XCTestCase
@end

@implementation FDLUtilitiesTests

- (void)testFDLCookieRetrievalURLCreatesCorrectURL {
  static NSString *const kCustomScheme = @"customscheme";
  static NSString *const kBundleID = @"com.My.Bundle.ID";

  NSString *expectedURLString = [NSString stringWithFormat:@"https://goo.gl/app/_/deeplink?fdl_ios_"
                                                            "bundle_id=%@&fdl_ios_url_scheme=%@",
                                                           kBundleID, kCustomScheme];

  NSURL *url = FIRDLCookieRetrievalURL(kCustomScheme, kBundleID);

  XCTAssertEqualObjects(url.absoluteString, expectedURLString);
}

- (void)testFDLURLQueryStringFromDictionaryReturnsEmptyStringWithEmptyDictionary {
  NSString *query = FIRDLURLQueryStringFromDictionary(@{});

  XCTAssertEqualObjects(query, @"");
}

- (void)testFDLURLQueryStringFromDictionaryReturnsCorrectStringWithSingleKVP {
  NSString *key = @"key";
  NSString *value = @"value";

  NSDictionary *queryDict = @{key : value};
  NSString *query = FIRDLURLQueryStringFromDictionary(queryDict);

  NSString *expectedQuery = [NSString stringWithFormat:@"?%@=%@", key, value];

  XCTAssertEqualObjects(query, expectedQuery);
}

- (void)testFDLURLQueryStringFromDictionary {
  NSDictionary *expectedQueryDict = @{
    @"key1" : @"va!lue1",
    @"key2" : @"val=ue2",
    @"key3" : @"val&ue3",
    @"key4" : @"valu?e4",
    @"key5" : @"val$ue5",
  };

  NSString *query = FIRDLURLQueryStringFromDictionary(expectedQueryDict);
  NSString *prefixToRemove = @"?";
  NSString *queryWithoutPrefix = [query substringFromIndex:prefixToRemove.length];

  NSDictionary *retrievedQueryDict = FIRDLDictionaryFromQuery(queryWithoutPrefix);

  XCTAssertEqualObjects(retrievedQueryDict, expectedQueryDict);
}

- (void)testGINDictionaryFromQueryWithNormalQuery {
  NSString *query = @"key1=value1&key2=value2";

  NSDictionary *returnedDictionary = FIRDLDictionaryFromQuery(query);
  NSDictionary *expectedDictionary = @{@"key1" : @"value1", @"key2" : @"value2"};

  XCTAssertEqualObjects(returnedDictionary, expectedDictionary);
}

- (void)testGINDictionaryFromQueryWithQueryMissingValue {
  NSString *query = @"key1=value1&key2=";

  NSDictionary *returnedDictionary = FIRDLDictionaryFromQuery(query);
  NSDictionary *expectedDictionary = @{@"key1" : @"value1", @"key2" : @""};

  XCTAssertEqualObjects(returnedDictionary, expectedDictionary);
}

- (void)testGINDictionaryFromQueryWithQueryMissingKey {
  NSString *query = @"key1=value1&=value2";

  NSDictionary *returnedDictionary = FIRDLDictionaryFromQuery(query);
  NSDictionary *expectedDictionary = @{@"key1" : @"value1", @"" : @"value2"};

  XCTAssertEqualObjects(returnedDictionary, expectedDictionary);
}

- (void)testGINDictionaryFromQueryWithQueryMissingKeyAndValue {
  NSString *query = @"key1=value1&=";

  NSDictionary *returnedDictionary = FIRDLDictionaryFromQuery(query);
  NSDictionary *expectedDictionary = @{@"key1" : @"value1", @"" : @""};

  XCTAssertEqualObjects(returnedDictionary, expectedDictionary);
}

- (void)testGINDictionaryFromQueryWithQueryMissingPairAtTheEnd {
  NSString *query = @"key1=value1&";

  NSDictionary *returnedDictionary = FIRDLDictionaryFromQuery(query);
  NSDictionary *expectedDictionary = @{@"key1" : @"value1"};

  XCTAssertEqualObjects(returnedDictionary, expectedDictionary);
}

- (void)testGINDictionaryFromQueryWithQueryMissingPairAtTheBeginning {
  NSString *query = @"&key1=value1";

  NSDictionary *returnedDictionary = FIRDLDictionaryFromQuery(query);
  NSDictionary *expectedDictionary = @{@"key1" : @"value1"};

  XCTAssertEqualObjects(returnedDictionary, expectedDictionary);
}

- (void)testGINDictionaryFromQueryWithQueryMissingPairInTheMiddle {
  NSString *query = @"key1=value1&&key2=value2";

  NSDictionary *returnedDictionary = FIRDLDictionaryFromQuery(query);
  NSDictionary *expectedDictionary = @{@"key1" : @"value1", @"key2" : @"value2"};

  XCTAssertEqualObjects(returnedDictionary, expectedDictionary);
}

- (void)testDeepLinkURLWithInviteIDDeepLinkStringWeakMatchEndpointCreatesExpectedCustomSchemeURL {
  NSString *inviteID = @"3082906yht4i02";
  NSString *deepLinkString = @"https://google.com/a%b!c=d";
  NSString *encodedDeepLinkString = @"https%3A%2F%2Fgoogle%2Ecom%2Fa%25b%21c%3Dd";
  NSString *weakMatchEndpoint = @"IPV6";
  NSString *utmSource = @"firebase";
  NSString *utmMedium = @"email";
  NSString *utmCampaign = @"testCampaign";
  NSString *utmTerm = @"testTerm";
  NSString *utmContent = @"testContent";
  NSString *matchType = @"unique";

  NSString *expectedURLString = [NSString
      stringWithFormat:@"%@://google/link/?utm_campaign=%@"
                       @"&deep_link_id=%@&utm_medium=%@&invitation_weakMatchEndpoint=%@"
                       @"&utm_source=%@&invitation_id=%@&match_type=%@"
                       @"&utm_content=%@&utm_term=%@",
                       kURLScheme, utmCampaign, encodedDeepLinkString, utmMedium, weakMatchEndpoint,
                       utmSource, inviteID, matchType, utmContent, utmTerm];
  NSURLComponents *expectedURLComponents = [NSURLComponents componentsWithString:expectedURLString];

  NSURL *actualURL = FIRDLDeepLinkURLWithInviteID(inviteID, deepLinkString, utmSource, utmMedium,
                                                  utmCampaign, utmContent, utmTerm, NO,
                                                  weakMatchEndpoint, nil, kURLScheme, nil);

  NSURLComponents *actualURLComponents = [NSURLComponents componentsWithURL:actualURL
                                                    resolvingAgainstBaseURL:NO];

  // Since the parameters are not guaranteed to be in any specific order, we must compare
  // arrays of properties of the URLs rather than the URLs themselves.
  // sort both expected/actual arrays to prevent order influencing the test results
  NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
  NSArray<NSURLQueryItem *> *expectedURLQueryItems =
      [expectedURLComponents.queryItems sortedArrayUsingDescriptors:@[ sort ]];

  NSArray<NSURLQueryItem *> *actualQueryItems =
      [actualURLComponents.queryItems sortedArrayUsingDescriptors:@[ sort ]];

  XCTAssertEqualObjects(actualQueryItems, expectedURLQueryItems);
  XCTAssertEqualObjects(actualURLComponents.host, expectedURLComponents.host);
}

- (void)testGINOSVersionSupportedReturnsYESWhenCurrentIsGreaterThanMin {
  BOOL supported = FIRDLOSVersionSupported(@"8.0.1", @"8.0");
  XCTAssertTrue(supported, @"FIRDLOSVersionSupported() returned NO when the OS was supported.");
}

- (void)testGINOSVersionSupportedReturnsYESWhenCurrentIsEqualToMin {
  BOOL supported = FIRDLOSVersionSupported(@"8.0", @"8.0");
  XCTAssertTrue(supported, @"FIRDLOSVersionSupported() returned NO when the OS was supported.");
}

- (void)testGINOSVersionSupportedReturnsNOWhenCurrentIsLessThanMin {
  BOOL supported = FIRDLOSVersionSupported(@"7.1", @"8.1");
  XCTAssertFalse(supported,
                 @"FIRDLOSVersionSupported() returned YES when the OS was not supported.");
}

@end
