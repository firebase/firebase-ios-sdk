#import <XCTest/XCTest.h>
#import "FirebaseAuth/Sources/Utilities/FIRAuthWebUtils.m"

/** @class FIRAuthWebUtilsTests
 @brief Tests for the FIRAuthWebUtils class.
 */
@interface FIRAuthWebUtilsTests : XCTestCase
@end

@implementation FIRAuthWebUtilsTests

/** @fn testExtractDomainWithHTTP
 @brief Test case for extracting the domain from a URL with "http://" scheme.
 */
- (void)testExtractDomainWithHTTP {
  NSString *urlString = @"http://www.example.com/path/to/resource";
  NSString *domain = [FIRAuthWebUtils extractDomain:urlString];
  XCTAssertEqualObjects(domain, @"www.example.com");
}

/** @fn testExtractDomainWithHTTPS
 @brief Test case for extracting the domain from a URL with "https://" scheme.
 */
- (void)testExtractDomainWithHTTPS {
  NSString *urlString = @"https://www.example.com/path/to/resource";
  NSString *domain = [FIRAuthWebUtils extractDomain:urlString];
  XCTAssertEqualObjects(domain, @"www.example.com");
}

/** @fn testExtractDomainWithoutScheme
 @brief Test case for extracting the domain from a URL without a scheme (assumes HTTP by default).
 */
- (void)testExtractDomainWithoutScheme {
  NSString *urlString = @"www.example.com/path/to/resource";
  NSString *domain = [FIRAuthWebUtils extractDomain:urlString];
  XCTAssertEqualObjects(domain, @"www.example.com");
}

/** @fn testExtractDomainWithTrailingSlashes
 @brief Test case for extracting the domain from a URL with trailing slashes.
 */
- (void)testExtractDomainWithTrailingSlashes {
  NSString *urlString = @"http://www.example.com/////";
  NSString *domain = [FIRAuthWebUtils extractDomain:urlString];
  XCTAssertEqualObjects(domain, @"www.example.com");
}

/** @fn testExtractDomainWithStringDomain
 @brief Test case for extracting the domain from a string that represents just the domain itself.
 */
- (void)testExtractDomainWithStringDomain {
  NSString *urlString = @"example.com";
  NSString *domain = [FIRAuthWebUtils extractDomain:urlString];
  XCTAssertEqualObjects(domain, @"example.com");
}

@end
