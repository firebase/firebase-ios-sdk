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

"""Swift identifier naming: keyword escaping, acronym casing, camelCase."""

from __future__ import annotations

import re


# Swift Keywords
SWIFT_KEYWORDS: set[str] = {
    "associatedtype",
    "class",
    "deinit",
    "enum",
    "extension",
    "fileprivate",
    "func",
    "import",
    "init",
    "inout",
    "internal",
    "let",
    "open",
    "operator",
    "private",
    "precedencegroup",
    "protocol",
    "public",
    "rethrows",
    "static",
    "struct",
    "subscript",
    "typealias",
    "var",
    "break",
    "case",
    "catch",
    "continue",
    "default",
    "defer",
    "do",
    "else",
    "fallthrough",
    "for",
    "guard",
    "if",
    "in",
    "repeat",
    "return",
    "throw",
    "throws",
    "switch",
    "where",
    "while",
    "as",
    "any",
    "some",
    "Any",
    "self",
    "Self",
    "super",
    "nil",
    "true",
    "false",
    "is",
    "try",
    "Type",
}


def escape_swift_name(name: str) -> str:
    """Escapes a Swift identifier using backticks if it is a reserved keyword.

    Args:
        name: The identifier to check.

    Returns:
        The escaped identifier if reserved, or the original identifier.
    """
    if name in SWIFT_KEYWORDS:
        return f"`{name}`"
    return name


SWIFT_ACRONYM_PAIRS: list[tuple[str, str]] = [
    ("Uris", "URIs"),
    ("Uri", "URI"),
    ("Url", "URL"),
    ("Json", "JSON"),
    ("Mime", "MIME"),
    ("Id", "ID"),
]


def apply_swift_acronyms(s: str, is_type: bool = False) -> str:
    """Applies Swift API Design Guidelines for acronym casing.

    Acronyms like ID, URI, URL, JSON, and MIME are uniformly uppercase,
    except when starting a lowerCamelCase property or method identifier.

    Args:
        s: The identifier to process.
        is_type: Whether the identifier is a type name (UpperCamelCase).

    Returns:
        The string with acronyms properly capitalized.
    """
    if not s:
        return s
    res = s
    for title_case, upper_case in SWIFT_ACRONYM_PAIRS:
        res = re.sub(
            r"(?<=[a-z0-9.])" + title_case + r"(?=[A-Z0-9]|$)",
            upper_case,
            res,
        )
        if is_type:
            res = re.sub(r"^" + title_case + r"(?=[A-Z0-9]|$)", upper_case, res)
    return res


def to_camel_case(s: str, lower: bool = True) -> str:
    """Converts a snake_case or capitalized string to camelCase.

    Args:
        s: The string to convert.
        lower: If True, returns lowerCamelCase. If False, UpperCamelCase.

    Returns:
        The camelCased string, escaping Swift keywords if necessary.
    """
    if s.isupper():
        s = s.lower()
    if "_" in s:
        parts = [p for p in s.split("_") if p]
        if not parts:
            return ""
        if lower:
            first = (
                parts[0][0].lower() + parts[0][1:]
                if len(parts[0]) > 1
                else parts[0].lower()
            )
        else:
            first = (
                parts[0][0].upper() + parts[0][1:]
                if len(parts[0]) > 1
                else parts[0].upper()
            )
        rest = [
            p[0].upper() + p[1:] if len(p) > 1 else p.upper() for p in parts[1:]
        ]
        result = first + "".join(rest)
    else:
        if not s:
            return ""
        if lower:
            result = s[0].lower() + s[1:] if len(s) > 1 else s.lower()
        else:
            result = s[0].upper() + s[1:] if len(s) > 1 else s.upper()
    result = apply_swift_acronyms(result, is_type=not lower)
    return escape_swift_name(result)
