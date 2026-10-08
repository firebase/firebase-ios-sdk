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

"""Unit tests for swift_typegen.docc."""

import unittest

from swift_typegen.docc import (
    docc_filter,
    extract_summary_sentence,
    format_init_description,
    format_property_docc,
    format_schema_docc,
    strip_doc_prefixes,
    wrap_docc,
)


class TestDocc(unittest.TestCase):

    def test_structured_docc_formatting(self):
        dual_prop_data = {
            "x-gl-description": "Gl description.",
            "x-ai-description": "Ai description.",
            "x-gl-original-name": "glName",
            "x-ai-original-name": "aiName",
        }
        dual_docc = format_property_docc(dual_prop_data)
        self.assertEqual(dual_docc, "Ai description.")
        self.assertNotIn("### Gemini Developer API", dual_docc)
        self.assertNotIn("### Gemini Enterprise Agent Platform", dual_docc)

        gl_only_prop_data = {
            "x-gl-description": "Gl only description.",
            "x-gl-original-name": "glName",
        }
        gl_docc = format_property_docc(gl_only_prop_data)
        self.assertIn("Gl only description.", gl_docc)
        self.assertNotIn("### Gemini Developer API", gl_docc)
        self.assertNotIn("### Gemini Enterprise Agent Platform", gl_docc)
        self.assertIn(
            "> Important: This property is not supported in the Gemini"
            " Enterprise Agent Platform.",
            gl_docc,
        )

        dual_schema_data = {
            "x-gl-description": "Gl schema description.",
            "x-ai-description": "Ai schema description.",
            "x-gl-original-name": "GlCandidate",
            "x-ai-original-name": "AiCandidate",
        }
        schema_docc = format_schema_docc(dual_schema_data)
        self.assertEqual(schema_docc, "Ai schema description.")
        self.assertNotIn("An internal data model for", schema_docc)
        self.assertNotIn("### Gemini Developer API", schema_docc)
        self.assertNotIn("### Gemini Enterprise Agent Platform", schema_docc)

        gl_only_schema_data = {
            "x-gl-description": "Gl only schema description.",
            "x-gl-original-name": "GlHarmCategory",
        }
        gl_schema_docc = format_schema_docc(gl_only_schema_data)
        self.assertEqual(
            gl_schema_docc,
            "Gl only schema description.\n\n> Important: This type is not"
            " supported in the Gemini Enterprise Agent Platform.",
        )
        self.assertNotIn("An internal data model for", gl_schema_docc)
        self.assertNotIn("### Gemini Developer API", gl_schema_docc)
        self.assertNotIn(
            "### Gemini Enterprise Agent Platform", gl_schema_docc
        )

        ai_only_schema_data = {
            "x-ai-description": "Ai only schema description.",
            "x-ai-original-name": "AiCandidate",
        }
        ai_schema_docc = format_schema_docc(ai_only_schema_data)
        self.assertEqual(
            ai_schema_docc,
            "Ai only schema description.\n\n> Important: This type is not"
            " supported in the Gemini Developer API.",
        )
        self.assertNotIn("An internal data model for", ai_schema_docc)
        self.assertNotIn("### Gemini Developer API", ai_schema_docc)
        self.assertNotIn(
            "### Gemini Enterprise Agent Platform", ai_schema_docc
        )

    def test_variant_and_existing_callouts_are_stripped(self):
        prop_data = {
            "x-gl-description": (
                "Optional. Gl text.\n\n> Important: stale note.\n\nVariant:\nOther."
            ),
        }
        self.assertEqual(
            format_property_docc(prop_data),
            "Gl text.\n\n> Important: This property is not supported in the"
            " Gemini Enterprise Agent Platform.",
        )
        self.assertEqual(
            format_property_docc({"description": "Optional. Shared.\n\nVariant:\nOther."}
            ),
            "Shared.",
        )

    def test_format_init_description(self):
        self.assertEqual(
            format_init_description(
                {"description": "Optional. The count. More detail."}, "count"
            ),
            "The count.",
        )
        self.assertEqual(
            format_init_description({"x-gl-description": "Gl only."}, "glProp"),
            "Gl only. (Gemini Developer API only). For more details, see"
            " ``glProp``.",
        )
        self.assertEqual(
            format_init_description(
                {"x-gl-description": "Gl.", "x-ai-description": "Ai."}, "both"
            ),
            "Gl. (behavior varies by backend). For more details, see"
            " ``both``.",
        )
        self.assertEqual(
            format_init_description({}, "empty"),
            "For more details, see ``empty``.",
        )

    def test_format_init_description_enterprise_only(self):
        self.assertEqual(
            format_init_description({"x-ai-description": "Ai only."}, "aiProp"),
            "Ai only. (Gemini Enterprise Agent Platform only). For more"
            " details, see ``aiProp``.",
        )

    def test_format_init_description_same_text_on_both_backends(self):
        self.assertEqual(
            format_init_description(
                {"x-gl-description": "Same.", "x-ai-description": "Same."},
                "shared",
            ),
            "Same.",
        )

    def test_backend_only_property_without_description(self):
        self.assertEqual(
            format_property_docc({"x-ai-description": ""}),
            "> Important: This property is not supported in the Gemini"
            " Developer API.",
        )

    def test_strip_doc_prefixes(self):
        self.assertEqual(
            strip_doc_prefixes("Optional. The maximum tokens."),
            "The maximum tokens.",
        )
        self.assertEqual(
            strip_doc_prefixes("Output only. The candidate response."),
            "The candidate response.",
        )
        self.assertEqual(
            strip_doc_prefixes("Optional. Output only. The count."),
            "The count.",
        )
        self.assertEqual(
            strip_doc_prefixes("Required. The contents."),
            "Required. The contents.",
        )

    def test_extract_summary_sentence(self):
        desc = (
            "Optional. Controls the randomness of the output. Note: The"
            " default value varies by model. Values can range from [0.0, 2.0]."
        )
        self.assertEqual(
            extract_summary_sentence(desc),
            "Controls the randomness of the output.",
        )

        desc_url = (
            "Optional. The name of the content"
            " [cached](https://ai.google.dev/gemini-api/docs/caching) to use as"
            " context to serve the prediction. Format:"
            " `cachedContents/{cachedContent}`"
        )
        self.assertEqual(
            extract_summary_sentence(desc_url),
            "The name of the content"
            " [cached](https://ai.google.dev/gemini-api/docs/caching) to use as"
            " context to serve the prediction.",
        )

        desc_req = (
            "Required. The content of the current conversation with the model."
        )
        self.assertEqual(
            extract_summary_sentence(desc_req),
            "Required. The content of the current conversation with the model.",
        )

    def test_wrap_docc(self):
        long_prose = (
            "An object that represents a latitude/longitude pair. This is"
            " expressed as a pair of doubles to represent degrees latitude and"
            " degrees longitude. Unless specified otherwise, this object must"
            " conform to the WGS84 standard."
        )
        wrapped = wrap_docc(long_prose, width=74)
        for line in wrapped.split("\n"):
            self.assertLessEqual(len(line), 74)

        markdown_list = (
            "- First item that is quite long and should be wrapped cleanly"
            " across multiple lines without breaking words.\n- Second item."
        )
        wrapped_list = wrap_docc(markdown_list, width=60)
        self.assertIn("- First item", wrapped_list)
        self.assertIn("- Second item.", wrapped_list)

    def test_docc_filter(self):
        text = "First paragraph.\n\nSecond paragraph."
        filtered = docc_filter(text, indent_level=2)
        expected = "  /// First paragraph.\n  ///\n  /// Second paragraph."
        self.assertEqual(filtered, expected)

        # Empty, None, or whitespace-only returns empty string
        self.assertEqual(docc_filter(None), "")
        self.assertEqual(docc_filter(""), "")
        self.assertEqual(docc_filter("   \n\t  "), "")

