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

"""Intermediate Swift type models consumed by the templates."""

from __future__ import annotations

import dataclasses


@dataclasses.dataclass
class SwiftProperty:
    """Represents a property on a Swift struct or class.

    Attributes:
        swift_name: The Swift identifier (e.g., 'candidateCount').
        json_name: The wire JSON key (e.g., 'candidate_count').
        swift_type: The Swift type name (e.g., 'Int', 'String?').
        description: Full DocC documentation comment.
        init_description: Brief description for initializer DocC parameter.
        is_deprecated: Whether the property is deprecated.
        is_required: Whether the property is non-optional.
        is_const: Whether the property has a constant fixed value.
        const_value: String representation of the constant value.
    """

    swift_name: str
    json_name: str
    swift_type: str
    description: str | None = None
    init_description: str | None = None
    is_deprecated: bool = False
    is_required: bool = False
    is_const: bool = False
    const_value: str | None = None

    @property
    def needs_explicit_coding_key(self) -> bool:
        """Returns True if the Swift name diverges from the JSON wire key."""
        return self.swift_name.strip("`") != self.json_name


@dataclasses.dataclass
class SwiftEnumCase:
    """Represents an enum case in a Swift enum declaration.

    Attributes:
        swift_name: The Swift case name (e.g., 'derogatory').
        raw_value: The wire raw string value (e.g., 'HARM_CATEGORY_DEROGATORY').
        description: DocC comment for the enum case.
        is_deprecated: Whether the case is marked deprecated.
    """

    swift_name: str
    raw_value: str
    description: str | None = None
    is_deprecated: bool = False


@dataclasses.dataclass
class SwiftType:
    """Represents a generated Swift type (struct, class, or enum).

    Attributes:
        name: Name of the Swift type (e.g., 'GenerateContentRequest').
        namespace: Parent namespace (e.g., 'GoogleAI.SafetySetting').
        kind: The kind of Swift declaration ('struct', 'class', 'enum').
        description: DocC documentation string for the type.
        is_deprecated: Whether the type is marked deprecated.
        properties: List of Swift properties for struct or class.
        cases: List of Swift enum cases for an enum.
        has_oneof: Whether this type contains a oneOf polymorphic union.
        oneof_name: Nested enum name for oneOf handling.
        oneof_properties: Properties belonging to the oneOf union.
    """

    name: str
    namespace: str
    kind: str
    description: str | None = None
    is_deprecated: bool = False
    properties: list[SwiftProperty] = dataclasses.field(default_factory=list)
    cases: list[SwiftEnumCase] = dataclasses.field(default_factory=list)
    has_oneof: bool = False
    oneof_name: str | None = None
    oneof_properties: list[SwiftProperty] = dataclasses.field(
        default_factory=list
    )
