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

"""Command-line interface for Swift type generation."""

from __future__ import annotations

import argparse
import os

from .pipeline import PipelineOptions, run

# Type generation root: scripts/typegen/swift_typegen/cli.py -> ../
TYPEGEN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Package root: scripts/typegen -> ../../ (GeminiLanguageModel)
PACKAGE_ROOT = os.path.dirname(os.path.dirname(TYPEGEN_DIR))


def parse_args(argv: list[str] | None = None) -> PipelineOptions:
    """Parses command-line arguments into PipelineOptions.

    Args:
        argv: Optional argument list (defaults to sys.argv[1:]).

    Returns:
        The parsed PipelineOptions.
    """
    parser = argparse.ArgumentParser(
        description="Generate Swift types from one or more OpenAPI Specs."
    )
    parser.add_argument(
        "--openapi-spec",
        default=os.path.join(
            TYPEGEN_DIR, "discovery_documents", "firebasevertexai-openapi.yaml"
        ),
        help="Path to the OpenAPI specification YAML file.",
    )
    parser.add_argument(
        "--templates-dir",
        default=os.path.join(TYPEGEN_DIR, "templates"),
        help="Directory containing the Jinja templates.",
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join(
            PACKAGE_ROOT,
            "Sources",
            "GeminiAPIDataModels",
            "GenerateContent",
        ),
        help="Target output directory for the Swift source files.",
    )
    parser.add_argument(
        "--roots",
        nargs="+",
        default=[
            "GenerateContentRequest",
            "GenerateContentResponse",
            "TemplateGenerateContentRequest",
            "CountTokensRequest",
            "CountTokensResponse",
        ],
        help="Root schema names to resolve transitively.",
    )
    parser.add_argument(
        "--access-level",
        default="package",
        choices=("public", "package", "internal"),
        help="Access level keyword for generated types.",
    )
    parser.add_argument(
        "--strip-prefix",
        nargs="*",
        default=None,
        help=(
            "Backend prefixes to strip from schema IDs and reference names."
            " Each must be listed in generatorConfig.backends in the"
            " overrides file. Defaults to all configured backends; pass the"
            " flag with no values to disable stripping. Backends are always"
            " merged Developer API first."
        ),
    )
    parser.add_argument(
        "--namespace",
        default="",
        help="Root Swift namespace. Defaults to empty for module-scoped types.",
    )
    parser.add_argument(
        "--shared-models-target",
        default="",
        help="Target name for shared models (e.g. InternalSharedDataModels).",
    )
    parser.add_argument(
        "--overrides-file",
        default=os.path.join(
            TYPEGEN_DIR, "discovery_documents", "firebasevertexai-overrides.yaml"
        ),
        help="Path to the overrides YAML file containing generatorConfig.",
    )
    parser.add_argument(
        "--doc-wrap-width",
        type=int,
        default=100,
        help=(
            "Maximum column width for wrapping DocC comments"
            " (defaults to 100)."
        ),
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print detailed generation progress.",
    )
    args = parser.parse_args(argv)

    return PipelineOptions(
        openapi_spec=args.openapi_spec,
        templates_dir=args.templates_dir,
        output_dir=args.output_dir,
        roots=tuple(args.roots),
        access_level=args.access_level,
        strip_prefixes=(
            None if args.strip_prefix is None else tuple(args.strip_prefix)
        ),
        namespace=args.namespace,
        shared_models_target=args.shared_models_target,
        overrides_file=args.overrides_file,
        doc_wrap_width=args.doc_wrap_width,
        verbose=args.verbose,
    )


def main(argv: list[str] | None = None) -> None:
    """CLI entry point for Swift type generation from OpenAPI specifications."""
    run(parse_args(argv))
