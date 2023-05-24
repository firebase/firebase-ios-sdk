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

import FirebaseFirestore
import Foundation
import XCTest

class CodableGeoPointTests: XCTestCase {
  func testGeoPointEncodes() {
    let geoPoint = GeoPoint(latitude: 37.77493, longitude: -122.41942)

    let jsonData = try! JSONEncoder().encode(geoPoint)
    let json = String(data: jsonData, encoding: .utf8)!

    // The ordering of attributes in the JSON output is not guaranteed, nor is the rounding of
    // the values so just verify that each required property is present and that the value
    // starts as expected.
    XCTAssert(json.contains("\"latitude\":37."))
    XCTAssert(json.contains("\"longitude\":-122."))
  }

  func testGeoPointDecodes() {
    let json = """
    {
      "latitude": 37.77493,
      "longitude": -122.41942
    }
    """
    let jsonData: Data = json.data(using: .utf8)!

    let geoPoint = try! JSONDecoder().decode(GeoPoint.self, from: jsonData)
    XCTAssertEqual(37.77493, geoPoint.latitude, accuracy: 0.0001)
    XCTAssertEqual(-122.41942, geoPoint.longitude, accuracy: 0.0001)
  }

  func testGeoPointIsHashable() {
    let geoPoint = GeoPoint(latitude: 37.77493, longitude: -122.41942)
    let geoPoint2 = GeoPoint(latitude: 37.77493, longitude: -122.41942)
    let dictionary: [GeoPoint: String] = [geoPoint: "foo"]
    XCTAssertEqual("foo", dictionary[geoPoint2])
  }
}
