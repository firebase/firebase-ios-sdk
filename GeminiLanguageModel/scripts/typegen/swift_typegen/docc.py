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

"""DocC documentation extraction, cleanup, and wrapping."""

from __future__ import annotations

import re
import textwrap
from typing import Any

from .config import DEVELOPER_TAG, ENTERPRISE_TAG, provenance_key

# Joins differing descriptions from two backends when merging schemas.
VARIANT_SEPARATOR = "\n\nVariant:\n"
# Introduces a backend-availability callout in a description.
IMPORTANT_SEPARATOR = "\n\n> Important:"
# Backend display names used in availability callouts.
DEVELOPER_API_NAME = "Gemini Developer API"
ENTERPRISE_API_NAME = "Gemini Enterprise Agent Platform"
# Per-backend provenance fields read when annotating availability.
_DEVELOPER_DESCRIPTION = provenance_key(DEVELOPER_TAG, "description")
_ENTERPRISE_DESCRIPTION = provenance_key(ENTERPRISE_TAG, "description")
_DEVELOPER_ORIGINAL_NAME = provenance_key(DEVELOPER_TAG, "original-name")
_ENTERPRISE_ORIGINAL_NAME = provenance_key(ENTERPRISE_TAG, "original-name")


def strip_doc_prefixes(text: str) -> str:
    """Strips leading API tags like 'Optional.' or 'Output only.' from comments.

    Args:
        text: Raw documentation comment string.

    Returns:
        Cleaned text with leading tags removed and initial letter capitalized.
    """
    if not text:
        return ""
    text = text.strip()
    cleaned = re.sub(
        r"^(?:(?:Optional|Output only|Input only)\.\s*)+", "", text
    )
    if cleaned:
        cleaned = cleaned[0].upper() + cleaned[1:]
    return cleaned


def extract_summary_sentence(desc: str) -> str:
    """Extracts the first complete summary sentence for DocC parameter docs.

    Preserves leading tags like 'Required.' while properly balancing
    parentheses and brackets when splitting sentences.

    Args:
        desc: Full documentation text.

    Returns:
        The extracted single summary sentence fragment.
    """
    if not desc:
        return ""
    desc = strip_doc_prefixes(desc)
    if "\n" in desc:
        lines = [line.strip() for line in desc.split("\n") if line.strip()]
        return strip_doc_prefixes(lines[0]) if lines else ""

    leading_tags: list[str] = []
    rest = desc
    while True:
        m = re.match(r"^(Required\.|Deprecated\.)\s*", rest)
        if m:
            leading_tags.append(m.group(1))
            rest = rest[m.end() :]
        else:
            break

    prefix = (" ".join(leading_tags) + " ") if leading_tags else ""

    splits = re.split(r"(?<=\.)\s+", rest)
    sentence_parts: list[str] = []
    in_paren = 0
    in_bracket = 0
    for part in splits:
        sentence_parts.append(part)
        in_paren += part.count("(") - part.count(")")
        in_bracket += part.count("[") - part.count("]")
        if in_paren <= 0 and in_bracket <= 0:
            clean = part.rstrip()
            if (
                clean.endswith(".")
                and not clean.endswith("e.g.")
                and not clean.endswith("i.e.")
                and not clean.endswith("vs.")
            ):
                break

    sentence = " ".join(sentence_parts)
    return (prefix + sentence).strip()


def wrap_docc(text: str | None, width: int = 94) -> str:
    """Wraps text to a fixed column width while preserving markdown structure.

    Preserves code blocks, blockquotes, markdown lists, and headers without
    breaking URLs or code spans across invalid line boundaries.

    Args:
        text: The documentation text to format.
        width: Maximum column width for wrapped lines.

    Returns:
        Wrapped text formatted for DocC comments.
    """
    if not text:
        return ""
    text = text.strip()
    blocks = re.split(r"\n\s*\n", text)
    wrapped_blocks: list[str] = []

    for block in blocks:
        block_lines = block.splitlines()
        if block.startswith("```"):
            wrapped_blocks.append(block)
            continue

        is_list = any(
            re.match(r"^\s*([*+-]|\d+\.)\s+", line) for line in block_lines
        )
        if is_list:
            wrapped_list_lines: list[str] = []
            for line in block_lines:
                m = re.match(r"^(\s*([*+-]|\d+\.)\s+)(.*)$", line)
                if m:
                    pfx = m.group(1)
                    body = m.group(3)
                    sub_indent = " " * len(pfx)
                    w = textwrap.fill(
                        body,
                        width=width,
                        initial_indent=pfx,
                        subsequent_indent=sub_indent,
                        break_long_words=False,
                        break_on_hyphens=False,
                    )
                    wrapped_list_lines.append(w)
                else:
                    wrapped_list_lines.append(line)
            wrapped_blocks.append("\n".join(wrapped_list_lines))
            continue

        if block.startswith(">"):
            m = re.match(r"^(>\s*)(.*)$", block, re.DOTALL)
            if m:
                pfx = m.group(1)
                body = " ".join(m.group(2).splitlines())
                w = textwrap.fill(
                    body,
                    width=width,
                    initial_indent=pfx,
                    subsequent_indent="> ",
                    break_long_words=False,
                    break_on_hyphens=False,
                )
                wrapped_blocks.append(w)
                continue

        if block.startswith("#"):
            wrapped_blocks.append(block)
            continue

        words = " ".join(block.split())
        w = textwrap.fill(
            words,
            width=width,
            break_long_words=False,
            break_on_hyphens=False,
        )
        wrapped_blocks.append(w)

    return "\n\n".join(wrapped_blocks)


def strip_variant(text: str) -> str:
    """Drops a merged second-backend variant appended by schema merging.

    Args:
        text: Description that may contain VARIANT_SEPARATOR.

    Returns:
        The text before VARIANT_SEPARATOR (stripped), or the input unchanged.
    """
    if VARIANT_SEPARATOR in text:
        return text.split(VARIANT_SEPARATOR)[0].strip()
    return text


def _clean_description(raw: str | None) -> str:
    """Strips doc prefixes and any merged variant from a raw description."""
    desc = strip_doc_prefixes((raw or "").strip())
    if VARIANT_SEPARATOR in desc:
        desc = strip_doc_prefixes(strip_variant(desc))
    return desc


def _with_unsupported_note(desc: str, note: str, wrap_width: int) -> str:
    """Formats desc followed by a '> Important:' backend availability note."""
    if "> Important:" in desc:
        desc = desc.split(IMPORTANT_SEPARATOR)[0].strip()
    docc = ""
    if desc:
        docc += f"{wrap_docc(desc, wrap_width)}\n\n"
    docc += f"> Important: {note}"
    return docc


def _format_backend_docc(
    data: dict[str, Any],
    has_developer: bool,
    has_enterprise: bool,
    noun: str,
    wrap_width: int,
) -> str:
    """Formats DocC for a schema or property, annotating backend availability.

    Args:
        data: Schema or property definition dictionary.
        has_developer: Whether the element exists in the Gemini Developer API.
        has_enterprise: Whether the element exists in the Gemini Enterprise
            Agent Platform.
        noun: 'type' or 'property', used in availability callouts.
        wrap_width: Column wrap width.

    Returns:
        Formatted DocC comment block.
    """
    if not has_developer and not has_enterprise:
        return wrap_docc(_clean_description(data.get("description")), wrap_width)

    developer_desc = _clean_description(data.get(_DEVELOPER_DESCRIPTION))
    enterprise_desc = _clean_description(data.get(_ENTERPRISE_DESCRIPTION))

    if has_developer and has_enterprise:
        return wrap_docc(enterprise_desc or developer_desc or "", wrap_width)
    if has_developer:
        return _with_unsupported_note(
            developer_desc,
            f"This {noun} is not supported in the {ENTERPRISE_API_NAME}.",
            wrap_width,
        )
    return _with_unsupported_note(
        enterprise_desc,
        f"This {noun} is not supported in the {DEVELOPER_API_NAME}.",
        wrap_width,
    )


def format_schema_docc(data: dict[str, Any], wrap_width: int = 96) -> str:
    """Formats top-level DocC documentation for a Swift type.

    Annotates backend availability callouts (Gemini Developer API vs Gemini
    Enterprise Agent Platform) if the schema is backend-specific.

    Args:
        data: Schema definition dictionary.
        wrap_width: Column wrap width.

    Returns:
        Formatted DocC comment block.
    """
    return _format_backend_docc(
        data,
        has_developer=data.get(_DEVELOPER_ORIGINAL_NAME) is not None,
        has_enterprise=data.get(_ENTERPRISE_ORIGINAL_NAME) is not None,
        noun="type",
        wrap_width=wrap_width,
    )


def format_property_docc(
    prop_data: dict[str, Any], wrap_width: int = 94
) -> str:
    """Formats DocC documentation for a Swift property.

    Args:
        prop_data: Property definition dictionary.
        wrap_width: Column wrap width.

    Returns:
        Formatted DocC comment block.
    """
    return _format_backend_docc(
        prop_data,
        has_developer=_DEVELOPER_DESCRIPTION in prop_data,
        has_enterprise=_ENTERPRISE_DESCRIPTION in prop_data,
        noun="property",
        wrap_width=wrap_width,
    )


def format_enum_case_docc(
    raw_description: str | None,
    in_developer: bool,
    in_enterprise: bool,
    wrap_width: int = 94,
) -> str:
    """Formats DocC documentation for a Swift enum case.

    Args:
        raw_description: Raw case description from `enumDescriptions`.
        in_developer: Whether the case exists in the Gemini Developer API.
        in_enterprise: Whether the case exists in the Gemini Enterprise Agent
            Platform.
        wrap_width: Column wrap width.

    Returns:
        Formatted DocC comment block, with a '> Important:' callout when the
        case exists in only one backend.
    """
    desc = strip_doc_prefixes(raw_description or "")
    if in_developer == in_enterprise:
        return wrap_docc(desc, wrap_width)
    unsupported = ENTERPRISE_API_NAME if in_developer else DEVELOPER_API_NAME
    return _with_unsupported_note(
        desc,
        f"This case is not supported in the {unsupported}.",
        wrap_width,
    )


def format_init_description(
    prop_data: dict[str, Any], swift_prop_name: str
) -> str:
    """Formats the brief DocC parameter description for a memberwise init.

    Args:
        prop_data: Property definition dictionary.
        swift_prop_name: Swift property name, linked for more details.

    Returns:
        A one-sentence description, suffixed with backend availability when
        the property is backend-specific.
    """
    developer_p_desc = strip_variant(
        (prop_data.get(_DEVELOPER_DESCRIPTION) or "").strip()
    )
    enterprise_p_desc = strip_variant(
        (prop_data.get(_ENTERPRISE_DESCRIPTION) or "").strip()
    )

    has_developer = _DEVELOPER_DESCRIPTION in prop_data
    has_enterprise = _ENTERPRISE_DESCRIPTION in prop_data

    p_desc = developer_p_desc or enterprise_p_desc
    if not p_desc:
        p_desc = strip_variant((prop_data.get("description") or "").strip())

    first_line = extract_summary_sentence(p_desc)
    is_backend_specific = (has_developer != has_enterprise) or (
        developer_p_desc
        and enterprise_p_desc
        and developer_p_desc != enterprise_p_desc
    )

    if is_backend_specific:
        if has_developer and not has_enterprise:
            suffix = f" ({DEVELOPER_API_NAME} only)"
        elif has_enterprise and not has_developer:
            suffix = f" ({ENTERPRISE_API_NAME} only)"
        else:
            suffix = " (behavior varies by backend)"
        init_desc = (
            f"{first_line}{suffix}. For more details, see"
            f" ``{swift_prop_name}``."
        )
    else:
        init_desc = first_line

    if not init_desc:
        init_desc = f"For more details, see ``{swift_prop_name}``."

    return init_desc


def docc_filter(text: str | None, indent_level: int = 2) -> str:
    """Formats text as a DocC comment block with specified indentation.

    Args:
        text: The documentation text to format.
        indent_level: Number of leading spaces for each comment line.

    Returns:
        Formatted DocC comment block, or empty string if text is empty.
    """
    if not text or not text.strip():
        return ""
    indent = " " * indent_level
    lines: list[str] = []
    for line in text.splitlines():
        if line.strip():
            lines.append(f"{indent}/// {line}")
        else:
            lines.append(f"{indent}///")
    return "\n".join(lines)
