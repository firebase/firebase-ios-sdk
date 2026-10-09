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

"""Generator configuration loaded from the overrides YAML file."""

from __future__ import annotations

import dataclasses
from typing import Any

import yaml

# Extension tags used for 'x-<tag>-*' provenance fields on merged schemas.
# The set is closed: merge.py and docc.py read the provenance fields of these
# specific tags, so supporting another backend requires code changes, not just
# configuration.
DEVELOPER_TAG = "gl-developer"
ENTERPRISE_TAG = "ai-enterprise"
BACKEND_TAGS = (DEVELOPER_TAG, ENTERPRISE_TAG)


def provenance_key(tag: str, field_name: str) -> str:
    """Returns the extension key recording a backend's provenance for a field.

    Tags contain hyphens, so keys must be built (or matched against
    BACKEND_TAGS) rather than parsed by splitting on '-'.

    Args:
        tag: A backend tag from BACKEND_TAGS.
        field_name: The provenance field: 'description', 'enum', or
            'original-name'.

    Returns:
        The 'x-<tag>-<field_name>' extension key.
    """
    return f"x-{tag}-{field_name}"


@dataclasses.dataclass(frozen=True)
class Backend:
    """A backend whose schemas share a vendor prefix in the OpenAPI spec.

    Attributes:
        prefix: Schema name prefix to strip (e.g.
            'GoogleAiGenerativelanguageV1beta').
        tag: Provenance extension tag: 'gl-developer' (Gemini Developer API)
            or 'ai-enterprise' (Gemini Enterprise Agent Platform).
    """

    prefix: str
    tag: str

    def __post_init__(self) -> None:
        if not self.prefix:
            raise ValueError("Backend prefix must be non-empty.")
        if self.tag not in BACKEND_TAGS:
            raise ValueError(
                f"Backend tag for prefix '{self.prefix}' must be one of"
                f" {BACKEND_TAGS}, got '{self.tag}'."
            )


@dataclasses.dataclass
class GeneratorConfig:
    """Configuration options and overrides for Swift type generation.

    Attributes:
        type_overrides: Schema reference to Swift type string overrides.
        property_type_overrides: Property-specific type overrides.
        excluded_schemas: Set of schema names to exclude from generation.
        manual_override_schemas: Schema names manually implemented elsewhere.
        type_divergences_resolutions: Resolutions for diverging property types.
        rename_mappings: Schema and reference renaming mappings.
        excluded_properties: Mapping of schema name to set of property names
            to exclude.
        backends: Backends to strip and merge. Prefixes and tags must be
            unique. List order is not significant: backends are always
            merged in BACKEND_TAGS order (Developer API first).
        preserved_files: Hand-written file names in the output directory that
            must never be pruned as stale.
    """

    type_overrides: dict[str, str] = dataclasses.field(default_factory=dict)
    property_type_overrides: dict[str, Any] = dataclasses.field(
        default_factory=dict
    )
    excluded_schemas: set[str] = dataclasses.field(default_factory=set)
    manual_override_schemas: set[str] = dataclasses.field(default_factory=set)
    type_divergences_resolutions: dict[str, Any] = dataclasses.field(
        default_factory=dict
    )
    rename_mappings: dict[str, str] = dataclasses.field(default_factory=dict)
    excluded_properties: dict[str, set[str]] = dataclasses.field(
        default_factory=dict
    )
    backends: list[Backend] = dataclasses.field(default_factory=list)
    preserved_files: set[str] = dataclasses.field(default_factory=set)

    def __post_init__(self) -> None:
        for attr in ("prefix", "tag"):
            values = [getattr(b, attr) for b in self.backends]
            duplicates = sorted({v for v in values if values.count(v) > 1})
            if duplicates:
                raise ValueError(
                    f"Duplicate backend {attr}(s) in"
                    f" generatorConfig.backends: {duplicates}."
                )

    def backend_for_prefix(self, prefix: str) -> Backend:
        """Returns the configured backend for a schema prefix.

        Args:
            prefix: Schema name prefix.

        Returns:
            The matching Backend.

        Raises:
            ValueError: If no backend is configured for the prefix.
        """
        for backend in self.backends:
            if backend.prefix == prefix:
                return backend
        raise ValueError(
            f"No backend configured for prefix '{prefix}'. Add it to"
            " generatorConfig.backends in the overrides file."
        )

    @classmethod
    def from_file(cls, path: str) -> GeneratorConfig:
        """Loads generator configuration from a YAML overrides file.

        Args:
            path: Path to the YAML overrides file.

        Returns:
            A GeneratorConfig instance initialized from the file contents.

        Raises:
            FileNotFoundError: If the overrides file does not exist.
            ValueError: If generatorConfig.backends is malformed.
        """
        with open(path, "r", encoding="utf-8") as f:
            overrides = yaml.safe_load(f) or {}
        gen_config = overrides.get("generatorConfig") or {}
        return cls(
            type_overrides=gen_config.get("typeOverrides") or {},
            property_type_overrides=(
                gen_config.get("propertyTypeOverrides") or {}
            ),
            excluded_schemas=set(gen_config.get("excludedSchemas") or []),
            manual_override_schemas=set(
                gen_config.get("manualOverrideSchemas") or []
            ),
            type_divergences_resolutions=(
                gen_config.get("typeDivergencesResolutions") or {}
            ),
            rename_mappings=gen_config.get("renameMappings") or {},
            excluded_properties={
                k: set(v or [])
                for k, v in (gen_config.get("excludedProperties") or {}).items()
            },
            backends=[
                _parse_backend(entry)
                for entry in gen_config.get("backends") or []
            ],
            preserved_files=set(gen_config.get("preservedFiles") or []),
        )


def _parse_backend(entry: Any) -> Backend:
    """Parses one generatorConfig.backends entry.

    Args:
        entry: A mapping with 'prefix' and 'tag' keys.

    Returns:
        The parsed Backend.

    Raises:
        ValueError: If the entry is not a mapping with 'prefix' and 'tag'.
    """
    if not isinstance(entry, dict) or not {"prefix", "tag"} <= entry.keys():
        raise ValueError(
            "Each generatorConfig.backends entry must be a mapping with"
            f" 'prefix' and 'tag' keys, got {entry!r}."
        )
    return Backend(prefix=entry["prefix"], tag=entry["tag"])
