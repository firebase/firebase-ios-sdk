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

import unittest

from swift_typegen import naming


class TestNaming(unittest.TestCase):

    def test_to_camel_case(self):
        self.assertEqual(
            naming.to_camel_case("candidate_count"), "candidateCount"
        )
        self.assertEqual(
            naming.to_camel_case("_responseJsonSchema"), "responseJSONSchema"
        )
        self.assertEqual(
            naming.to_camel_case("responseJsonSchema"), "responseJSONSchema"
        )
        self.assertEqual(naming.to_camel_case("responseId"), "responseID")
        self.assertEqual(naming.to_camel_case("fileUri"), "fileURI")
        self.assertEqual(
            naming.to_camel_case("sourceFlaggingUris"), "sourceFlaggingURIs"
        )
        self.assertEqual(naming.to_camel_case("retrievedUrl"), "retrievedURL")
        self.assertEqual(
            naming.to_camel_case("responseMimeType"), "responseMIMEType"
        )
        self.assertEqual(naming.to_camel_case("uri"), "uri")
        self.assertEqual(naming.to_camel_case("url"), "url")
        self.assertEqual(naming.to_camel_case("id"), "id")
        self.assertEqual(
            naming.to_camel_case("MEDIA_RESOLUTION_LOW"), "mediaResolutionLow"
        )
        self.assertEqual(naming.to_camel_case("default"), "`default`")
        self.assertEqual(naming.to_camel_case("type", lower=False), "`Type`")
        self.assertEqual(
            naming.to_camel_case("url_context", lower=False), "URLContext"
        )
        self.assertEqual(
            naming.to_camel_case("mime_type", lower=False), "MIMEType"
        )

    def test_apply_swift_acronyms(self):
        self.assertEqual(
            naming.apply_swift_acronyms("responseId", False), "responseID"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("placeId", False), "placeID"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("fileUri", False), "fileURI"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("sourceFlaggingUris", False),
            "sourceFlaggingURIs",
        )
        self.assertEqual(
            naming.apply_swift_acronyms("retrievedUrl", False), "retrievedURL"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("responseJsonSchema", False),
            "responseJSONSchema",
        )
        self.assertEqual(
            naming.apply_swift_acronyms("responseMimeType", False),
            "responseMIMEType",
        )
        self.assertEqual(
            naming.apply_swift_acronyms("obfuscatedApiKey", False),
            "obfuscatedAPIKey",
        )
        self.assertEqual(
            naming.apply_swift_acronyms("OpenApi", True), "OpenAPI"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("supportedApis", False), "supportedAPIs"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("sourceUrls", False), "sourceURLs"
        )
        self.assertEqual(naming.apply_swift_acronyms("apiKey", False), "apiKey")
        self.assertEqual(
            naming.apply_swift_acronyms("capital", False), "capital"
        )
        self.assertEqual(naming.apply_swift_acronyms("uri", False), "uri")
        self.assertEqual(naming.apply_swift_acronyms("url", False), "url")
        self.assertEqual(naming.apply_swift_acronyms("id", False), "id")
        self.assertEqual(naming.apply_swift_acronyms("valid", False), "valid")
        self.assertEqual(naming.apply_swift_acronyms("grid", False), "grid")
        self.assertEqual(naming.apply_swift_acronyms("middle", False), "middle")
        self.assertEqual(naming.apply_swift_acronyms("video", False), "video")

        self.assertEqual(
            naming.apply_swift_acronyms("UrlContext", True), "URLContext"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("UrlMetadata", True), "URLMetadata"
        )
        self.assertEqual(
            naming.apply_swift_acronyms("UrlRetrievalStatus", True),
            "URLRetrievalStatus",
        )
        self.assertEqual(
            naming.apply_swift_acronyms("MimeType", True), "MIMEType"
        )
        self.assertEqual(
            naming.apply_swift_acronyms(
                "GroundingMetadataSourceFlaggingUri", True
            ),
            "GroundingMetadataSourceFlaggingURI",
        )
        self.assertEqual(
            naming.apply_swift_acronyms("Parent.UrlContext", True),
            "Parent.URLContext",
        )
