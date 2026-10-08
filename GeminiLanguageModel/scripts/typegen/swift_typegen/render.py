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

"""Renders Swift type models to Swift source using Jinja2 templates."""

from __future__ import annotations

from jinja2 import Environment, FileSystemLoader

from .docc import docc_filter
from .models import SwiftType


def create_environment(templates_dir: str) -> Environment:
    """Creates the Jinja2 environment used to render Swift templates.

    Args:
        templates_dir: Path to directory containing Jinja templates.

    Returns:
        A configured Jinja2 Environment with the `docc` filter registered.
    """
    env = Environment(
        loader=FileSystemLoader(templates_dir),
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )
    env.filters["docc"] = docc_filter
    return env


def output_filename(st: SwiftType, root_namespace: str) -> str:
    """Returns the Swift file name for a type, e.g. 'Candidate+FinishReason.swift'.

    Args:
        st: The Swift type to name.
        root_namespace: Root namespace prefix to omit from file names.

    Returns:
        The file name (without directory) for the rendered type.
    """
    parts = [p for p in st.namespace.split(".") if p and p != root_namespace]
    filename_parts = parts + [st.name.replace("`", "")]
    return "+".join(filename_parts) + ".swift"


class SwiftRenderer:
    """Renders SwiftType models to Swift source code without touching disk."""

    def __init__(
        self,
        templates_dir: str,
        access_level: str,
        root_namespace: str,
        shared_models_target: str = "",
    ) -> None:
        """Initializes the renderer and loads templates.

        Args:
            templates_dir: Path to directory containing Jinja templates.
            access_level: Swift access control keyword ('public', 'package',
                etc.).
            root_namespace: Root namespace prefix to omit from file names.
            shared_models_target: Target module name for shared models.
        """
        env = create_environment(templates_dir)
        self.struct_template = env.get_template("struct.swift.jinja")
        self.enum_template = env.get_template("enum.swift.jinja")
        self.access_level = access_level
        self.root_namespace = root_namespace
        self.shared_models_target = shared_models_target

    def render(self, st: SwiftType) -> tuple[str, str] | None:
        """Renders a single Swift type.

        Args:
            st: The Swift type to render.

        Returns:
            A (filename, source) tuple, or None if the type kind is not
            supported.
        """
        all_props = st.properties + st.oneof_properties

        if st.kind == "struct":
            rendered = self.struct_template.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                properties=st.properties,
                has_oneof=st.has_oneof,
                oneof_name=st.oneof_name,
                oneof_properties=st.oneof_properties,
                uses_shared_data_models=st.has_oneof
                or any(
                    "JSONValue" in p.swift_type or "APIError" in p.swift_type
                    for p in all_props
                ),
                shared_models_target=self.shared_models_target,
                access_level=self.access_level,
            )
        elif st.kind == "enum":
            rendered = self.enum_template.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                cases=st.cases,
                access_level=self.access_level,
            )
        else:
            return None

        return output_filename(st, self.root_namespace), rendered
