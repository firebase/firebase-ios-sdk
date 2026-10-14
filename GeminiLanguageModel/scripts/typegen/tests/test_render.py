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

"""Unit tests for swift_typegen.render (no filesystem output)."""

import os
import unittest

from swift_typegen import models
from swift_typegen import render

TEMPLATES_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "templates")
)


def _render(
    renderer: render.SwiftRenderer, st: models.SwiftType
) -> tuple[str, str]:
    """Renders `st`, failing the test if the renderer skips it."""
    result = renderer.render(st)
    if result is None:
        raise AssertionError(f"{st.name} was not rendered")
    return result


class TestTemplateRendering(unittest.TestCase):
    """Test suite for Jinja2 template rendering."""

    def test_render_struct_with_properties_and_oneof(self):
        st = models.SwiftType(
            name="TestConfig",
            namespace="GoogleAI",
            kind="struct",
            description="Configuration for tests.",
        )
        st.properties = [
            models.SwiftProperty(
                swift_name="temperature",
                json_name="temperature",
                swift_type="Double",
                description="Controls randomness.",
            ),
            models.SwiftProperty(
                swift_name="topK",
                json_name="top_k",
                swift_type="Int",
                description="Top-k sampling threshold.",
            ),
        ]
        st.has_oneof = True
        st.oneof_name = "Data"
        st.oneof_properties = [
            models.SwiftProperty(
                swift_name="text",
                json_name="text",
                swift_type="String",
            ),
        ]

        renderer = render.SwiftRenderer(
            TEMPLATES_DIR,
            access_level="package",
            root_namespace="GoogleAI",
            shared_models_target="InternalSharedDataModels",
        )
        filename, content = _render(renderer, st)

        self.assertEqual(filename, "TestConfig.swift")
        self.assertIn("package import InternalSharedDataModels", content)
        self.assertIn("/// Configuration for tests.", content)
        self.assertIn(
            "package struct TestConfig: Codable, Sendable, Equatable, Hashable,"
            " Buildable",
            content,
        )
        self.assertIn("/// Controls randomness.", content)
        self.assertIn("package var temperature: Double?", content)
        self.assertIn(
            "package enum Data: Sendable, Equatable, Hashable", content
        )
        self.assertIn("case text(String)", content)
        self.assertIn("case temperature", content)
        self.assertIn('case topK = "top_k"', content)

    def test_render_empty_struct(self):
        st = models.SwiftType(
            name="EmptyStruct",
            namespace="GoogleAI",
            kind="struct",
            description="An empty struct.",
        )
        renderer = render.SwiftRenderer(
            TEMPLATES_DIR, access_level="package", root_namespace="GoogleAI"
        )
        filename, content = _render(renderer, st)

        self.assertEqual(filename, "EmptyStruct.swift")
        self.assertIn(
            "package struct EmptyStruct: Codable, Sendable, Equatable,"
            " Hashable, Buildable",
            content,
        )
        self.assertIn("package init() {}", content)
        self.assertNotIn("enum CodingKeys", content)

    def test_render_struct_with_const_property_defaults_when_missing(self):
        st = models.SwiftType(
            name="Schema", namespace="GoogleAI", kind="struct"
        )
        st.properties = [
            models.SwiftProperty(
                swift_name="kind",
                json_name="kind",
                swift_type="String",
                is_required=True,
                is_const=True,
                const_value='"OBJECT"',
            ),
            models.SwiftProperty(
                swift_name="title",
                json_name="title",
                swift_type="String",
            ),
        ]
        renderer = render.SwiftRenderer(
            TEMPLATES_DIR, access_level="package", root_namespace="GoogleAI"
        )
        _, content = _render(renderer, st)

        self.assertIn('package var kind: String = "OBJECT"', content)
        self.assertIn("package init(from decoder: any Decoder)", content)
        self.assertIn(
            "self.kind = (try container.decodeIfPresent(String.self,"
            ' forKey: .kind)) ?? "OBJECT"',
            content,
        )
        self.assertIn("try container.encode(kind, forKey: .kind)", content)
        self.assertIn(
            "try container.encodeIfPresent(title, forKey: .title)", content
        )
        self.assertNotIn("DynamicCodingKey", content)
        self.assertNotIn("unrecognized", content)

    def test_render_enum_with_cases_and_deprecation(self):
        et = models.SwiftType(
            name="TestEnum",
            namespace="GoogleAI",
            kind="enum",
            description="Test enum description.",
        )
        et.cases = [
            models.SwiftEnumCase(
                swift_name="activeCase",
                raw_value="ACTIVE",
                description="Active case.",
            ),
            models.SwiftEnumCase(
                swift_name="deprecatedCase",
                raw_value="DEPRECATED",
                description="Deprecated case.",
                is_deprecated=True,
            ),
        ]
        renderer = render.SwiftRenderer(
            TEMPLATES_DIR, access_level="public", root_namespace="GoogleAI"
        )
        filename, content = _render(renderer, et)

        self.assertEqual(filename, "TestEnum.swift")
        self.assertIn(
            "public enum TestEnum: Codable, Sendable, Equatable, Hashable",
            content,
        )
        self.assertIn("case activeCase", content)
        self.assertIn("@available(*, deprecated)", content)
        self.assertIn("case deprecatedCase", content)
        self.assertIn("case unrecognized(_ value: String)", content)
        self.assertIn("extension GoogleAI.TestEnum: RawRepresentable", content)
        self.assertIn('case .activeCase: "ACTIVE"', content)
        self.assertIn('case .deprecatedCase: "DEPRECATED"', content)
        # Deprecated cases decode in the main switch, with deprecation
        # warnings suppressed by `@diagnose` on Swift 6.4+ compilers.
        self.assertIn(
            "  #if hasAttribute(diagnose)\n"
            "    @diagnose(DeprecatedDeclaration, as: ignored)\n"
            "  #endif\n"
            "  public init(rawValue: String) {\n",
            content,
        )
        self.assertIn('case "ACTIVE": self = .activeCase', content)
        self.assertIn('case "DEPRECATED": self = .deprecatedCase', content)
        self.assertIn("default: self = .unrecognized(rawValue)", content)
        self.assertNotIn("DeprecatedCaseDecoding", content)

    def test_render_enum_without_deprecated_cases_omits_diagnose(self):
        et = models.SwiftType(name="Plain", namespace="", kind="enum")
        et.cases = [models.SwiftEnumCase(swift_name="one", raw_value="ONE")]
        renderer = render.SwiftRenderer(
            TEMPLATES_DIR, access_level="package", root_namespace=""
        )
        _, content = _render(renderer, et)
        self.assertIn("default: self = .unrecognized(rawValue)", content)
        self.assertNotIn("@diagnose", content)
        self.assertNotIn("hasAttribute", content)

    def test_render_unknown_kind_returns_none(self):
        st = models.SwiftType(name="Thing", namespace="", kind="class")
        renderer = render.SwiftRenderer(
            TEMPLATES_DIR, access_level="package", root_namespace=""
        )
        self.assertIsNone(renderer.render(st))

    def test_rendered_files_include_do_not_edit_notice(self):
        renderer = render.SwiftRenderer(
            TEMPLATES_DIR, access_level="package", root_namespace="GoogleAI"
        )
        enum_type = models.SwiftType(
            name="Kind", namespace="GoogleAI", kind="enum"
        )
        enum_type.cases = [models.SwiftEnumCase(swift_name="a", raw_value="A")]
        for st in (
            models.SwiftType(name="Thing", namespace="GoogleAI", kind="struct"),
            enum_type,
        ):
            with self.subTest(kind=st.kind):
                _, content = _render(renderer, st)
                self.assertIn(
                    "// limitations under the License.\n\n// DO NOT EDIT."
                    " This file is generated by"
                    " GeminiLanguageModel/scripts/typegen;",
                    content,
                )

    def test_output_filename_joins_nested_namespaces(self):
        st = models.SwiftType(
            name="`Type`", namespace="GoogleAI.Schema.Items", kind="enum"
        )
        self.assertEqual(
            render.output_filename(st, root_namespace="GoogleAI"),
            "Schema+Items+Type.swift",
        )
