# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Unit tests for swift_typegen.naming."""

import unittest

from swift_typegen.naming import apply_swift_acronyms, to_camel_case


class TestNaming(unittest.TestCase):

    def test_to_camel_case(self):
        self.assertEqual(to_camel_case("candidate_count"), "candidateCount")
        self.assertEqual(
            to_camel_case("_responseJsonSchema"), "responseJSONSchema"
        )
        self.assertEqual(
            to_camel_case("responseJsonSchema"), "responseJSONSchema"
        )
        self.assertEqual(to_camel_case("responseId"), "responseID")
        self.assertEqual(to_camel_case("fileUri"), "fileURI")
        self.assertEqual(
            to_camel_case("sourceFlaggingUris"), "sourceFlaggingURIs"
        )
        self.assertEqual(to_camel_case("retrievedUrl"), "retrievedURL")
        self.assertEqual(to_camel_case("responseMimeType"), "responseMIMEType")
        self.assertEqual(to_camel_case("uri"), "uri")
        self.assertEqual(to_camel_case("url"), "url")
        self.assertEqual(to_camel_case("id"), "id")
        self.assertEqual(
            to_camel_case("MEDIA_RESOLUTION_LOW"), "mediaResolutionLow"
        )
        self.assertEqual(to_camel_case("default"), "`default`")
        self.assertEqual(to_camel_case("type", lower=False), "`Type`")
        self.assertEqual(
            to_camel_case("url_context", lower=False), "URLContext"
        )
        self.assertEqual(to_camel_case("mime_type", lower=False), "MIMEType")

    def test_apply_swift_acronyms(self):
        self.assertEqual(apply_swift_acronyms("responseId", False), "responseID")
        self.assertEqual(apply_swift_acronyms("placeId", False), "placeID")
        self.assertEqual(apply_swift_acronyms("fileUri", False), "fileURI")
        self.assertEqual(
            apply_swift_acronyms("sourceFlaggingUris", False),
            "sourceFlaggingURIs",
        )
        self.assertEqual(
            apply_swift_acronyms("retrievedUrl", False), "retrievedURL"
        )
        self.assertEqual(
            apply_swift_acronyms("responseJsonSchema", False),
            "responseJSONSchema",
        )
        self.assertEqual(
            apply_swift_acronyms("responseMimeType", False), "responseMIMEType"
        )
        self.assertEqual(apply_swift_acronyms("uri", False), "uri")
        self.assertEqual(apply_swift_acronyms("url", False), "url")
        self.assertEqual(apply_swift_acronyms("id", False), "id")
        self.assertEqual(apply_swift_acronyms("valid", False), "valid")
        self.assertEqual(apply_swift_acronyms("grid", False), "grid")
        self.assertEqual(apply_swift_acronyms("middle", False), "middle")
        self.assertEqual(apply_swift_acronyms("video", False), "video")

        self.assertEqual(apply_swift_acronyms("UrlContext", True), "URLContext")
        self.assertEqual(
            apply_swift_acronyms("UrlMetadata", True), "URLMetadata"
        )
        self.assertEqual(
            apply_swift_acronyms("UrlRetrievalStatus", True),
            "URLRetrievalStatus",
        )
        self.assertEqual(apply_swift_acronyms("MimeType", True), "MIMEType")
        self.assertEqual(
            apply_swift_acronyms("GroundingMetadataSourceFlaggingUri", True),
            "GroundingMetadataSourceFlaggingURI",
        )
        self.assertEqual(
            apply_swift_acronyms("Parent.UrlContext", True), "Parent.URLContext"
        )

