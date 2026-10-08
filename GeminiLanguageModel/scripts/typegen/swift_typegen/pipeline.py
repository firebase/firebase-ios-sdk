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

"""End-to-end generation pipeline: load, preprocess, merge, process, write."""

from __future__ import annotations

from collections.abc import Iterable, Sequence
import copy
from dataclasses import dataclass
import os
from typing import Any

import yaml

from .config import BACKEND_TAGS, Backend, GeneratorConfig
from .graph import (
    build_direct_dependency_graph,
    find_cycle_nodes,
    resolve_all_types,
)
from .merge import (
    merge_schemas,
    rename_schemas_and_refs,
    strip_prefix_from_schemas,
)
from .models import SwiftType
from .output import (
    prune_stale_files,
    run_swift_format,
    write_files,
)
from .processor import SchemaProcessor
from .render import SwiftRenderer


@dataclass(frozen=True)
class PipelineOptions:
    """Options controlling a generation run (mirrors the CLI flags).

    Attributes:
        openapi_spec: Path to the OpenAPI specification YAML file.
        templates_dir: Directory containing the Jinja templates.
        output_dir: Target output directory for the Swift source files.
        roots: Root schema names to resolve transitively.
        access_level: Access level keyword for generated types.
        strip_prefixes: Backend prefixes to strip and merge, each of which
            must be configured in generatorConfig.backends. None uses every
            configured backend; an empty tuple disables prefix stripping.
        namespace: Root Swift namespace.
        shared_models_target: Target name for shared models.
        overrides_file: Path to the overrides YAML file.
        doc_wrap_width: Maximum column width for wrapping DocC comments.
        verbose: Whether to print detailed generation progress.
    """

    openapi_spec: str
    templates_dir: str
    output_dir: str
    roots: tuple[str, ...]
    access_level: str
    strip_prefixes: tuple[str, ...] | None
    namespace: str
    shared_models_target: str
    overrides_file: str
    doc_wrap_width: int
    verbose: bool = False


def load_config(overrides_file: str) -> GeneratorConfig:
    """Loads the generator configuration from the overrides YAML file.

    Args:
        overrides_file: Path to the overrides YAML file.

    Returns:
        The loaded GeneratorConfig.

    Raises:
        FileNotFoundError: If the overrides file does not exist. Running
            without it would generate a different, much smaller type set
            and prune the existing output.
    """
    if not os.path.exists(overrides_file):
        raise FileNotFoundError(
            f"Overrides file not found at {overrides_file}"
        )
    config = GeneratorConfig.from_file(overrides_file)
    print(f"Loaded generator configuration from {overrides_file}")
    return config


def select_backends(
    strip_prefixes: Sequence[str] | None, config: GeneratorConfig
) -> list[Backend]:
    """Selects the backends to strip and merge, in merge order.

    Merge order is always BACKEND_TAGS order (Developer API first),
    regardless of the requested or configured order, because merged
    provenance and descriptions assume the Developer API comes first.

    Args:
        strip_prefixes: Prefixes requested on the command line, or None to use
            every configured backend.
        config: Generator configuration.

    Returns:
        The selected backends. An empty list means no prefix stripping.

    Raises:
        ValueError: If a requested prefix is not a configured backend, or if
            strip_prefixes is None and no backends are configured.
    """
    if strip_prefixes is None:
        if not config.backends:
            raise ValueError(
                "No generatorConfig.backends configured in the overrides"
                " file. Configure backends, or pass --strip-prefix with no"
                " values to explicitly disable prefix stripping."
            )
        selected = set(config.backends)
    else:
        selected = {config.backend_for_prefix(p) for p in strip_prefixes}
    return sorted(selected, key=lambda b: BACKEND_TAGS.index(b.tag))


def load_spec(openapi_spec: str) -> dict[str, Any]:
    """Loads `components.schemas` from an OpenAPI specification file.

    Args:
        openapi_spec: Path to the OpenAPI specification YAML file.

    Returns:
        Dictionary of schema names to schema definitions.

    Raises:
        FileNotFoundError: If the specification file does not exist.
        ValueError: If the specification has no `components.schemas`, e.g.
            because the file is empty.
    """
    if not os.path.exists(openapi_spec):
        raise FileNotFoundError(
            f"Specification file not found at {openapi_spec}. Run"
            " `python upgrade_spec.py` first to fetch the Discovery Document"
            " and generate the OpenAPI 3.1.0 specification."
        )

    with open(openapi_spec, "r", encoding="utf-8") as f:
        doc = yaml.safe_load(f)

    components = doc.get("components") if isinstance(doc, dict) else None
    base_schemas = (
        components.get("schemas") if isinstance(components, dict) else None
    )
    if not isinstance(base_schemas, dict) or not base_schemas:
        # Continuing with no schemas would write no files and then prune
        # every previously generated file.
        raise ValueError(
            f"No components.schemas found in {openapi_spec}. Run"
            " `python upgrade_spec.py` to regenerate the OpenAPI 3.1.0"
            " specification."
        )
    print(
        f"Loaded specification {openapi_spec} with {len(base_schemas)}"
        " schemas."
    )
    return base_schemas


def preprocess_backend(
    base_schemas: dict[str, Any],
    backend: Backend | None,
    roots: Sequence[str],
    config: GeneratorConfig,
) -> dict[str, Any]:
    """Produces the resolved schema set for a single backend.

    Strips the backend prefix, applies renames, and resolves the schemas
    reachable from the roots.

    Args:
        base_schemas: All schemas from the specification (not mutated).
        backend: Backend whose prefix to strip, or None for no stripping.
        roots: Root schema names to resolve transitively.
        config: Generator configuration.

    Returns:
        Dictionary of resolved schemas for this backend.
    """
    roots = list(roots)
    doc_schemas = copy.deepcopy(base_schemas)
    prefix = backend.prefix if backend is not None else ""
    if backend is not None:
        doc_schemas = strip_prefix_from_schemas(
            doc_schemas,
            backend,
            divergences=config.type_divergences_resolutions,
        )
        print(
            f"Stripped prefix '{prefix}'. Remaining schema count:"
            f" {len(doc_schemas)}"
        )

    doc_schemas = rename_schemas_and_refs(doc_schemas, config.rename_mappings)
    doc_resolved = resolve_all_types(
        doc_schemas,
        roots,
        excluded_schemas=config.excluded_schemas,
        excluded_properties=config.excluded_properties,
    )
    print(
        f"Resolved {len(doc_resolved)} schemas for prefix '{prefix}'"
        f" from roots {roots}."
    )
    return doc_resolved


def merge_backends(
    resolved_by_doc: list[dict[str, Any]], config: GeneratorConfig
) -> dict[str, Any]:
    """Merges per-backend schema sets and drops manually implemented schemas.

    Args:
        resolved_by_doc: Resolved schemas for each backend, in order.
        config: Generator configuration.

    Returns:
        Dictionary of merged schemas.
    """
    resolved: dict[str, Any] = {}
    for doc_resolved in resolved_by_doc:
        for name, data in doc_resolved.items():
            if name in resolved:
                resolved[name] = merge_schemas(
                    name,
                    resolved[name],
                    data,
                    divergences=config.type_divergences_resolutions,
                )
            else:
                resolved[name] = data

    for name in list(resolved.keys()):
        if name in config.manual_override_schemas:
            del resolved[name]

    return resolved


def check_cycles(resolved: dict[str, Any], config: GeneratorConfig) -> None:
    """Raises if any schemas contain each other by value.

    Args:
        resolved: Merged schemas.
        config: Generator configuration.

    Raises:
        RuntimeError: If recursive schema cycles are detected.
    """
    graph = build_direct_dependency_graph(
        resolved, excluded_properties=config.excluded_properties
    )
    cycle_nodes = find_cycle_nodes(graph)
    if cycle_nodes:
        raise RuntimeError(
            f"Detected recursive schema cycles in: {sorted(list(cycle_nodes))}."
            " Swift value types cannot have infinite size. Exclude these"
            " schemas in overrides.yaml or configure property overrides."
        )


def write_types(
    swift_types: list[SwiftType],
    options: PipelineOptions,
    preserved_files: Iterable[str],
) -> list[str]:
    """Renders, writes, formats, and prunes generated Swift sources.

    Args:
        swift_types: Swift types to render.
        options: Pipeline options.
        preserved_files: Hand-written file names that must not be pruned.

    Returns:
        List of paths to newly written Swift files.
    """
    renderer = SwiftRenderer(
        options.templates_dir,
        options.access_level,
        options.namespace,
        shared_models_target=options.shared_models_target,
    )
    rendered = [r for r in map(renderer.render, swift_types) if r is not None]
    written_files = write_files(
        rendered, options.output_dir, verbose=options.verbose
    )
    run_swift_format(written_files, verbose=options.verbose)

    preserved = set(preserved_files)
    if options.namespace:
        preserved.add(f"{options.namespace}.swift")
    prune_stale_files(
        options.output_dir, written_files, preserved, verbose=options.verbose
    )
    return written_files


def run(options: PipelineOptions) -> None:
    """Runs the full generation pipeline.

    Args:
        options: Pipeline options.
    """
    config = load_config(options.overrides_file)
    base_schemas = load_spec(options.openapi_spec)

    roots = list(options.roots)
    backends = select_backends(options.strip_prefixes, config)
    if backends:
        resolved_by_doc = [
            preprocess_backend(base_schemas, backend, roots, config)
            for backend in backends
        ]
    else:
        resolved_by_doc = [
            preprocess_backend(base_schemas, None, roots, config)
        ]

    resolved = merge_backends(resolved_by_doc, config)
    print(
        f"Total merged and resolved schemas: {len(resolved)} from roots"
        f" {roots}."
    )

    check_cycles(resolved, config)

    processor = SchemaProcessor(
        config=config, doc_wrap_width=options.doc_wrap_width
    )
    swift_types = processor.process(resolved, options.namespace)
    print(
        f"Processing generated {len(swift_types)} distinct types"
        " (including nested enums/structs)."
    )

    write_types(swift_types, options, config.preserved_files)
    print("Code generation completed successfully.")
