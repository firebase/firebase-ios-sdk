// Copyright 2023 Google LLC
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

import FirebaseCore
import XCTest

@testable import FirebaseAppDistributionInternal
@testable import FirebaseInstallations

class ApiServiceTests: XCTestCase {
  override class func setUp() {
    let options = FirebaseOptions(
      googleAppID: "0:0000000000000:ios:0000000000000000",
      gcmSenderID: "00000000000000000-00000000000-000000000"
    )
    options.projectID = "myProjectID"
    // Randomly generated, this needs to start with A, and be 39 characters long.
    options.apiKey = "A7a8Ff2UsWT3r5lOg22fFFkVwZClxc2MsvfPPFS"
    FirebaseApp.configure(name: "app-distribution-test-app", options: options)
    _ = FirebaseApp.app(name: "app-distribution-test-app")
  }

  // MARK: - Test generateAuthToken

  func testGenerateAuthTokenSuccess() {
    let installations = FakeInstallations(testCase: .success)

    let expectation = XCTestExpectation(description: "Generate auth token succeeds")

    ApiService.generateAuthToken(
      installations: installations,
      completion: { identifier, authTokenResult, error in
        XCTAssertNotNil(identifier)
        XCTAssertNotNil(authTokenResult)
        XCTAssertNil(error)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testGenerateAuthTokenAuthTokenFailure() {
    let installations = FakeInstallations(testCase: .authTokenFailure)
    let expectation =
      XCTestExpectation(description: "Generate auth token fails to generate auth token.")

    ApiService.generateAuthToken(
      installations: installations,
      completion: { identifier, authTokenResult, error in
        let nserror = error as? NSError
        XCTAssertNil(identifier)
        XCTAssertNil(authTokenResult)
        XCTAssertNotNil(error)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiTokenGenerationFailure.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testGenerateAuthTokenInstallationIDFailure() {
    let installations = FakeInstallations(testCase: .installationIDFailure)
    let expectation = XCTestExpectation(description: "Generate auth token fails to find ID.")

    ApiService.generateAuthToken(
      installations: installations,
      completion: { identifier, authTokenResult, error in
        let nserror = error as? NSError
        XCTAssertNil(identifier)
        XCTAssertNil(authTokenResult)
        XCTAssertNotNil(error)
        XCTAssertEqual(
          nserror?.code,
          AppDistributionApiError.ApiInstallationIdentifierError.rawValue
        )
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  // MARK: - Test fetchReleases

  func testFetchReleasesSuccess() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let expectedReleases: [[String: AnyHashable]] = [
      [
        "displayVersion": "1.0.0",
        "buildVersion": "111",
        "releaseNotes": "This is a release",
        "downloadURL": "http://faketyfakefake.download",
      ],
      [
        "latest": true,
        "displayVersion": "1.0.1",
        "buildVersion": "112",
        "releaseNotes": "This is a release too",
        "downloadURL": "http://faketyfakefake.download",
      ],
    ]
    let response = ["releases": expectedReleases]
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: try! JSONSerialization.data(withJSONObject: response)
    )

    let expectation = XCTestExpectation(description: "Fetch releases succeeds with two releases.")

    ApiService.fetchReleases(
      app: app,
      installations: installations,
      urlSession: urlSession,
      completion: { releases, error in
        XCTAssertNotNil(releases)
        XCTAssertNil(error)
        XCTAssertEqual(releases?.count, 2)
        XCTAssertEqual(releases as? [[String: AnyHashable]?], expectedReleases)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testFetchReleasesWithEmptyArraySuccess() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: try! JSONSerialization.data(withJSONObject: ["releases": []])
    )

    let expectation = XCTestExpectation(description: "Fetch releases succeeds with 0 releases.")

    ApiService.fetchReleases(
      app: app,
      installations: installations,
      urlSession: urlSession,
      completion: { releases, error in
        XCTAssertNotNil(releases)
        XCTAssertNil(error)
        XCTAssertEqual(releases?.count, 0)
        XCTAssertEqual(releases as? [[String: AnyHashable]?], [])
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testFetchReleasesWithInvalidJsonFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: "invalid-string".data(using: .utf8)
    )

    let expectation = XCTestExpectation(description: "Fetch releases fails")

    ApiService.fetchReleases(
      app: app,
      installations: installations,
      urlSession: urlSession,
      completion: { releases, error in
        let nserror = error as? NSError
        XCTAssertNil(releases)
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorParseFailure.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testFetchReleasesUnknownFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unknownFailure)

    let expectation = XCTestExpectation(description: "Fetch releases fails with unknown error.")

    ApiService.fetchReleases(
      app: app,
      installations: installations,
      urlSession: urlSession,
      completion: { releases, error in
        let nserror = error as? NSError
        XCTAssertNil(releases)
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnknownFailure.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testFetchReleasesUnauthenticatedFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unauthenticatedFailure)

    let expectation =
      XCTestExpectation(description: "Fetch releases fails with unauthenticated error.")

    ApiService.fetchReleases(
      app: app,
      installations: installations,
      urlSession: urlSession,
      completion: { releases, error in
        let nserror = error as? NSError
        XCTAssertNil(releases)
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnauthenticated.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  // TODO: Add more cases for testFetchReleases

  func testFindReleaseSuccess() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: try! JSONSerialization.data(withJSONObject: ["release": "release/name"])
    )

    let expectation = XCTestExpectation(description: "Find release succeeds")

    ApiService.findRelease(
      app: app,
      installations: installations,
      urlSession: urlSession,
      displayVersion: "display-version",
      buildVersion: "build-version",
      codeHash: "codeHash",
      completion: { releaseName, error in
        XCTAssertEqual(releaseName, "release/name")
        XCTAssertNil(error)
        expectation.fulfill()
      }
    )
  }

  func testFindReleaseWithInvalidJsonFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: "invalid-json".data(using: .utf8)
    )

    let expectation = XCTestExpectation(description: "Find release fails")

    ApiService.findRelease(
      app: app,
      installations: installations,
      urlSession: urlSession,
      displayVersion: "display-version",
      buildVersion: "build-version",
      codeHash: "codeHash",
      completion: { releaseName, error in
        XCTAssertNil(releaseName)
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorParseFailure.rawValue)
        expectation.fulfill()
      }
    )
  }

  func testFindReleaseUnauthenticatedFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unauthenticatedFailure)

    let expectation = XCTestExpectation(description: "Find release fails")

    ApiService.findRelease(
      app: app,
      installations: installations,
      urlSession: urlSession,
      displayVersion: "display-version",
      buildVersion: "build-version",
      codeHash: "codeHash",
      completion: { releaseName, error in
        XCTAssertNil(releaseName)
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnauthenticated.rawValue)
        expectation.fulfill()
      }
    )
  }

  func testFindReleaseUnknownFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unknownFailure)

    let expectation = XCTestExpectation(description: "Find release fails")

    ApiService.findRelease(
      app: app,
      installations: installations,
      urlSession: urlSession,
      displayVersion: "display-version",
      buildVersion: "build-version",
      codeHash: "codeHash",
      completion: { releaseName, error in
        XCTAssertNil(releaseName)
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnknownFailure.rawValue)
        expectation.fulfill()
      }
    )
  }

  func testCreateFeedbackSuccess() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: try! JSONSerialization.data(withJSONObject: ["name": "feedback/name"])
    )

    let expectation = XCTestExpectation(description: "Create feedback succeeds")

    ApiService.createFeedback(
      app: app,
      installations: installations,
      urlSession: urlSession,
      releaseName: "release/name",
      feedbackText: "feedback text",
      completion: { feedbackName, error in
        XCTAssertEqual(feedbackName, "feedback/name")
        XCTAssertNil(error)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testCreateFeedbackWithInvalidJsonFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: "invalid-json".data(using: .utf8)
    )

    let expectation = XCTestExpectation(description: "Create feedback fails")

    ApiService.createFeedback(
      app: app,
      installations: installations,
      urlSession: urlSession,
      releaseName: "release/name",
      feedbackText: "feedback text",
      completion: { feedbackName, error in
        XCTAssertNil(feedbackName)
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorParseFailure.rawValue)
        expectation.fulfill()
      }
    )
  }

  func testCreateFeedbackUnauthenticatedFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unauthenticatedFailure)

    let expectation = XCTestExpectation(description: "Create feedback fails")

    ApiService.createFeedback(
      app: app,
      installations: installations,
      urlSession: urlSession,
      releaseName: "release/name",
      feedbackText: "feedback text",
      completion: { feedbackName, error in
        XCTAssertNil(feedbackName)
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnauthenticated.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testCreateFeedbackWithCompletionUnknownFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unknownFailure)

    let expectation = XCTestExpectation(description: "Create feedback fails")

    ApiService.createFeedback(
      app: app,
      installations: installations,
      urlSession: urlSession,
      releaseName: "release/name",
      feedbackText: "feedback text",
      completion: { feedbackName, error in
        XCTAssertNil(feedbackName)
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnknownFailure.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testUploadImageSuccess() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .success)

    let expectation = XCTestExpectation(description: "Upload image succeeds")

    ApiService.uploadImage(
      app: app,
      installations: installations,
      urlSession: urlSession,
      feedbackName: "feedback/name",
      image: UIImage(),
      completion: { error in
        XCTAssertNil(error)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testUploadImageUnauthenticatedFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unauthenticatedFailure)

    let expectation = XCTestExpectation(description: "Upload image fails")

    ApiService.uploadImage(
      app: app,
      installations: installations,
      urlSession: urlSession,
      feedbackName: "feedback/name",
      image: UIImage(),
      completion: { error in
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnauthenticated.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testUploadImageWithCompletionUnknownFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unknownFailure)

    let expectation = XCTestExpectation(description: "Upload image fails")

    ApiService.uploadImage(
      app: app,
      installations: installations,
      urlSession: urlSession,
      feedbackName: "feedback/name",
      image: UIImage(),
      completion: { error in
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnknownFailure.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testCommitFeedbackSuccess() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(
      testCase: .success,
      responseData: try! JSONSerialization.data(withJSONObject: ["name": "feedback/name"])
    )

    let expectation = XCTestExpectation(description: "Commit feedback succeeds")

    ApiService.commitFeedback(
      app: app,
      installations: installations,
      urlSession: urlSession,
      feedbackName: "feedback/name",
      completion: { error in
        XCTAssertNil(error)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testCommitFeedbackUnauthenticatedFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unauthenticatedFailure)

    let expectation = XCTestExpectation(description: "Commit feedback fails")

    ApiService.commitFeedback(
      app: app,
      installations: installations,
      urlSession: urlSession,
      feedbackName: "feedback/name",
      completion: { error in
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnauthenticated.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }

  func testCommitFeedbackWithCompletionUnknownFailure() {
    let app = FirebaseApp.app(name: "app-distribution-test-app")!
    let installations = FakeInstallations(testCase: .success)
    let urlSession = URLSessionMock(testCase: .unknownFailure)

    let expectation = XCTestExpectation(description: "Commit feedback fails")

    ApiService.commitFeedback(
      app: app,
      installations: installations,
      urlSession: urlSession,
      feedbackName: "feedback/name",
      completion: { error in
        let nserror = error as? NSError
        XCTAssertNotNil(nserror)
        XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnknownFailure.rawValue)
        expectation.fulfill()
      }
    )

    wait(for: [expectation], timeout: 5)
  }
}
