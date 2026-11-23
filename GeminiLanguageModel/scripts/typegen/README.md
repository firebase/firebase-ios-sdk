# Swift type generation (`typegen`)

This directory contains the OpenAPI 3.1.0 upgrade and Swift code generation
pipeline used to generate the data models in
`GeminiLanguageModel/Sources/GeminiAPIDataModels/GenerateContent`.

Hand-written support types used by the generated models (`Buildable`,
`JSONValue`, `GoogleCloudAPIError`, and `manualOverrideSchemas` implementations
such as `ResponseFormatConfig`) live in
`GeminiLanguageModel/Sources/GeminiAPIDataModels/Core`, which the generator
never writes to or prunes.

---

## Architecture and code generation workflow

```mermaid
graph TD
    A["firebasevertexai_public_openapi3_0_v1beta.json"] -->|Upgraded by| B("upgrade_spec.py")
    E["firebasevertexai-overrides.yaml"] -->|Merged by| B
    B -->|Produces| F["firebasevertexai-openapi.yaml"]
    F -->|Parsed by| C("generate_types.py")
    E -->|Configures| C
    D["Jinja2 Swift Templates"] -->|Rendered by| C
    C -->|Generates Swift Models| G["Sources/GeminiAPIDataModels/GenerateContent"]
```

## Setup

From `GeminiLanguageModel/scripts/typegen`:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## 1. Upgrading the specification (`upgrade_spec.py`)

Before generating types, convert the checked-in OpenAPI 3.0 Discovery
specification to OpenAPI 3.1.0 and apply manual overrides:

```bash
python upgrade_spec.py
```

By default, `upgrade_spec.py` loads the checked-in
`discovery_documents/firebasevertexai_public_openapi3_0_v1beta.json` without
making any network requests, normalizes schema references and enum metadata
extensions, extracts shared standalone enums (such as `HarmCategory`,
`Modality`, and `DataType`), infers required fields, merges manual overrides
from `firebasevertexai-overrides.yaml`, and writes
`discovery_documents/firebasevertexai-openapi.yaml` (gitignored).

Pass `--input-file` to convert an alternate local OpenAPI 3.0 or Google
Discovery Document JSON file. For **upstream comparison only**, pass `--fetch`
to download and convert the latest live Google REST Discovery Document (saved to
the gitignored `discovery_documents/firebasevertexai_discovery_v1beta.json`; the
script refuses to overwrite the checked-in OpenAPI 3.0 spec):

```bash
python upgrade_spec.py --fetch
```

Do not commit Swift models regenerated with `--fetch`: the live REST Discovery
Document formats doc descriptions differently and omits some OpenAPI 3.0
metadata (such as `BidiGenerateContent` descriptions and `google-duration`
formats). See [discovery_documents/README.md](discovery_documents/README.md) for
details on the checked-in OpenAPI 3.0 spec.

---

## 2. Generating Swift types (`generate_types.py`)

Use [generate_types.py](generate_types.py) to parse the upgraded OpenAPI 3.1.0
specification and write Swift types directly into
`GeminiLanguageModel/Sources/GeminiAPIDataModels/GenerateContent`:

```bash
python generate_types.py
```

### Command-line arguments reference

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--openapi-spec` | `discovery_documents/firebasevertexai-openapi.yaml` | Upgraded spec YAML path. |
| `--overrides-file` | `discovery_documents/firebasevertexai-overrides.yaml` | YAML overrides file path. |
| `--output-dir` | `../../Sources/GeminiAPIDataModels/GenerateContent` | Output directory. |
| `--roots` | `["GenerateContentRequest", ...]` | Roots to resolve. |
| `--access-level` | `package` | Swift access control: `public`, `package`, or `internal`. |
| `--strip-prefix` | all `generatorConfig.backends` | Backend prefixes to strip and merge (pass with no values to disable). |
| `--namespace` | `""` | Swift root namespace. |
| `--shared-models-target` | `""` | Shared models target. |
| `--templates-dir` | `templates` | Jinja2 templates folder. |
| `--doc-wrap-width` | `100` | Maximum column width for DocC comments. |
| `--verbose` | `false` | Enable verbose output. |

The overrides file is required: the generator exits with an error if it is
missing, rather than generating a much smaller type set and pruning existing
output. Each `--strip-prefix` value must be listed in
`generatorConfig.backends`. If no backends are configured, the generator exits
with an error unless `--strip-prefix` is passed with no values. Backends are
always merged Developer API (`gl-developer`) first, regardless of argument or
config order.

### Code layout

`generate_types.py` is a thin entry point. The implementation lives in the
[`swift_typegen`](swift_typegen) package:

| Module | Responsibility |
| :--- | :--- |
| `cli.py` | Argument parsing; builds `PipelineOptions`. |
| `pipeline.py` | Orchestration: load → per-backend preprocess → merge → cycle check → process → write. |
| `config.py` | `GeneratorConfig`, loaded from the overrides YAML `generatorConfig` block (including `backends` prefixes/tags and `preservedFiles`). |
| `merge.py` | Backend prefix stripping, schema renaming, and cross-backend schema merging. |
| `graph.py` | `$ref` traversal, reachability from roots, and cycle detection. |
| `processor.py` | `SchemaProcessor`: OpenAPI schemas → `SwiftType` models. |
| `models.py` | `SwiftType`, `SwiftProperty`, `SwiftEnumCase`. |
| `naming.py` | Swift identifier casing, acronyms, and keyword escaping. |
| `docc.py` | DocC comment extraction, cleanup, and wrapping. |
| `render.py` | Jinja2 rendering to `(filename, source)` with no file I/O. |
| `output.py` | Writing files, `swift format`, and pruning stale outputs. |

---

## 3. Running unit tests

From `GeminiLanguageModel/scripts/typegen/`:

```bash
python -m unittest discover -s tests -t .
```

Or from anywhere in the repository:

```bash
python -m unittest discover \
  -s GeminiLanguageModel/scripts/typegen/tests \
  -t GeminiLanguageModel/scripts/typegen
```

---

## 4. Formatting

Python sources are formatted with [pyink](https://github.com/google/pyink)
using the settings in [pyproject.toml](pyproject.toml). From
`GeminiLanguageModel/scripts/typegen/`:

```bash
pip install pyink
pyink .
```
