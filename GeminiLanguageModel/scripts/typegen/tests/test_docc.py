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

from swift_typegen import docc


class TestDocc(unittest.TestCase):

    def test_structured_docc_formatting(self):
        dual_prop_data = {
            "x-gl-developer-description": "Developer description.",
            "x-ai-enterprise-description": "Enterprise description.",
            "x-gl-developer-original-name": "developerName",
            "x-ai-enterprise-original-name": "enterpriseName",
        }
        dual_docc = docc.format_property_docc(dual_prop_data)
        self.assertEqual(dual_docc, "Enterprise description.")
        self.assertNotIn("### Gemini Developer API", dual_docc)
        self.assertNotIn("### Gemini Enterprise Agent Platform", dual_docc)

        developer_only_prop_data = {
            "x-gl-developer-description": "Developer-only description.",
            "x-gl-developer-original-name": "developerName",
        }
        developer_docc = docc.format_property_docc(developer_only_prop_data)
        self.assertIn("Developer-only description.", developer_docc)
        self.assertNotIn("### Gemini Developer API", developer_docc)
        self.assertNotIn("### Gemini Enterprise Agent Platform", developer_docc)
        self.assertIn(
            "> Important: This property is not supported in the Gemini"
            " Enterprise Agent Platform.",
            developer_docc,
        )

        dual_schema_data = {
            "x-gl-developer-description": "Developer schema description.",
            "x-ai-enterprise-description": "Enterprise schema description.",
            "x-gl-developer-original-name": "DeveloperCandidate",
            "x-ai-enterprise-original-name": "EnterpriseCandidate",
        }
        schema_docc = docc.format_schema_docc(dual_schema_data)
        self.assertEqual(schema_docc, "Enterprise schema description.")
        self.assertNotIn("An internal data model for", schema_docc)
        self.assertNotIn("### Gemini Developer API", schema_docc)
        self.assertNotIn("### Gemini Enterprise Agent Platform", schema_docc)

        developer_only_schema_data = {
            "x-gl-developer-description": "Developer-only schema description.",
            "x-gl-developer-original-name": "DeveloperHarmCategory",
        }
        developer_schema_docc = docc.format_schema_docc(
            developer_only_schema_data
        )
        self.assertEqual(
            developer_schema_docc,
            "Developer-only schema description.\n\n> Important: This type is"
            " not supported in the Gemini Enterprise Agent Platform.",
        )
        self.assertNotIn("An internal data model for", developer_schema_docc)
        self.assertNotIn("### Gemini Developer API", developer_schema_docc)
        self.assertNotIn(
            "### Gemini Enterprise Agent Platform", developer_schema_docc
        )

        enterprise_only_schema_data = {
            "x-ai-enterprise-description": (
                "Enterprise-only schema description."
            ),
            "x-ai-enterprise-original-name": "EnterpriseCandidate",
        }
        enterprise_schema_docc = docc.format_schema_docc(
            enterprise_only_schema_data
        )
        self.assertEqual(
            enterprise_schema_docc,
            "Enterprise-only schema description.\n\n> Important: This type is"
            " not supported in the Gemini Developer API.",
        )
        self.assertNotIn("An internal data model for", enterprise_schema_docc)
        self.assertNotIn("### Gemini Developer API", enterprise_schema_docc)
        self.assertNotIn(
            "### Gemini Enterprise Agent Platform", enterprise_schema_docc
        )

    def test_variant_and_existing_callouts_are_stripped(self):
        prop_data = {
            "x-gl-developer-description": (
                "Optional. Developer text.\n\n> Important: stale note."
                "\n\nVariant:\nOther."
            ),
        }
        self.assertEqual(
            docc.format_property_docc(prop_data),
            "Developer text.\n\n> Important: This property is not supported in"
            " the Gemini Enterprise Agent Platform.",
        )
        self.assertEqual(
            docc.format_property_docc(
                {"description": "Optional. Shared.\n\nVariant:\nOther."}
            ),
            "Shared.",
        )

    def test_format_init_description(self):
        self.assertEqual(
            docc.format_init_description(
                {"description": "Optional. The count. More detail."}, "count"
            ),
            "The count.",
        )
        self.assertEqual(
            docc.format_init_description(
                {"x-gl-developer-description": "Developer-only."},
                "developerProp",
            ),
            "Developer-only. (Gemini Developer API only). For more details, see"
            " ``developerProp``.",
        )
        self.assertEqual(
            docc.format_init_description(
                {
                    "x-gl-developer-description": "Developer.",
                    "x-ai-enterprise-description": "Enterprise.",
                },
                "both",
            ),
            "Developer. (behavior varies by backend). For more details, see"
            " ``both``.",
        )
        self.assertEqual(
            docc.format_init_description({}, "empty"),
            "For more details, see ``empty``.",
        )

    def test_format_init_description_enterprise_only(self):
        self.assertEqual(
            docc.format_init_description(
                {"x-ai-enterprise-description": "Enterprise-only."},
                "enterpriseProp",
            ),
            "Enterprise-only. (Gemini Enterprise Agent Platform only). For more"
            " details, see ``enterpriseProp``.",
        )

    def test_format_init_description_same_text_on_both_backends(self):
        self.assertEqual(
            docc.format_init_description(
                {
                    "x-gl-developer-description": "Same.",
                    "x-ai-enterprise-description": "Same.",
                },
                "shared",
            ),
            "Same.",
        )

    def test_backend_only_property_without_description(self):
        self.assertEqual(
            docc.format_property_docc({"x-ai-enterprise-description": ""}),
            "> Important: This property is not supported in the Gemini"
            " Developer API.",
        )

    def test_strip_doc_prefixes(self):
        self.assertEqual(
            docc.strip_doc_prefixes("Optional. The maximum tokens."),
            "The maximum tokens.",
        )
        self.assertEqual(
            docc.strip_doc_prefixes("Output only. The candidate response."),
            "The candidate response.",
        )
        self.assertEqual(
            docc.strip_doc_prefixes("Optional. Output only. The count."),
            "The count.",
        )
        self.assertEqual(
            docc.strip_doc_prefixes("Required. The contents."),
            "Required. The contents.",
        )

    def test_extract_summary_sentence(self):
        desc = (
            "Optional. Controls the randomness of the output. Note: The"
            " default value varies by model. Values can range from [0.0, 2.0]."
        )
        self.assertEqual(
            docc.extract_summary_sentence(desc),
            "Controls the randomness of the output.",
        )

        desc_url = (
            "Optional. The name of the content"
            " [cached](https://ai.google.dev/gemini-api/docs/caching) to use as"
            " context to serve the prediction. Format:"
            " `cachedContents/{cachedContent}`"
        )
        self.assertEqual(
            docc.extract_summary_sentence(desc_url),
            "The name of the content"
            " [cached](https://ai.google.dev/gemini-api/docs/caching) to use as"
            " context to serve the prediction.",
        )

        desc_req = (
            "Required. The content of the current conversation with the model."
        )
        self.assertEqual(
            docc.extract_summary_sentence(desc_req),
            "Required. The content of the current conversation with the model.",
        )

    def test_wrap_docc(self):
        long_prose = (
            "An object that represents a latitude/longitude pair. This is"
            " expressed as a pair of doubles to represent degrees latitude and"
            " degrees longitude. Unless specified otherwise, this object must"
            " conform to the WGS84 standard."
        )
        wrapped = docc.wrap_docc(long_prose, width=74)
        for line in wrapped.split("\n"):
            self.assertLessEqual(len(line), 74)

        markdown_list = (
            "- First item that is quite long and should be wrapped cleanly"
            " across multiple lines without breaking words.\n- Second item."
        )
        wrapped_list = docc.wrap_docc(markdown_list, width=60)
        self.assertIn("- First item", wrapped_list)
        self.assertIn("- Second item.", wrapped_list)

    def test_docc_filter(self):
        text = "First paragraph.\n\nSecond paragraph."
        filtered = docc.docc_filter(text, indent_level=2)
        expected = "  /// First paragraph.\n  ///\n  /// Second paragraph."
        self.assertEqual(filtered, expected)

        # Empty, None, or whitespace-only returns empty string
        self.assertEqual(docc.docc_filter(None), "")
        self.assertEqual(docc.docc_filter(""), "")
        self.assertEqual(docc.docc_filter("   \n\t  "), "")
