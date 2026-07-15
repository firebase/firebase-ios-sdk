# Code Generation Scripts

This directory contains execution scripts that orchestrate the code generation
pipeline.

## Setup

First, activate the local Python virtual environment and ensure dependencies are
installed:

```bash
# From the project root directory
source utilities/.venv/bin/activate
pip install -r utilities/requirements.txt # Installs jinja2 if not present
pip install pyyaml --index-url https://pypi.org/simple # Installs pyyaml
```

---

## 1. Upgrading Specification (`upgrade_spec.py`)

Before generating types, you must upgrade the base specification and apply
manual overrides:

```bash
python utilities/scripts/upgrade_spec.py
```
This script loads the base specification
`firebasevertexai_public_openapi3_0_v1beta.json`, upgrades it to OpenAPI 3.1.0
(standardizing nullable fields and allOf references), merges overrides from
`firebasevertexai-overrides.yaml`, and outputs `firebasevertexai-openapi.yaml`.

---

## 2. Generating Types (`generate_types.py`)

Use [generate_types.py](generate_types.py) to parse the upgraded OpenAPI 3.1.0
specification and write clean Swift types into target folders.

### Command-Line Arguments Reference

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--openapi-spec` | `.../firebasevertexai-openapi.yaml` | Upgraded spec YAML paths. |
| `--overrides-file` | `.../firebasevertexai-overrides.yaml` | YAML overrides file path. |
| `--output-dir` | `Sources/InternalGeminiDataModels` | Output directory. |
| `--roots` | `["GenerateContentRequest", ...]` | Roots to resolve. |
| `--access-level` | `package` | Swift access control. |
| `--strip-prefix` | `["GoogleAi...", "GoogleCloud..."]` | Prefixes to strip. |
| `--namespace` | `GeminiDataModels` | Swift root namespace. |
| `--templates-dir` | `utilities/templates` | Jinja2 templates folder. |

---

## Copy-Paste Recipes

Use the following recipe from the project root to regenerate the unified
`InternalGeminiDataModels` SPM target:

### Regenerating `InternalGeminiDataModels`
```bash
# 1. Upgrade spec & apply overrides
python utilities/scripts/upgrade_spec.py

# 2. Generate Swift types
python utilities/scripts/generate_types.py \
  --openapi-spec \
    utilities/discovery_documents/firebasevertexai-openapi.yaml \
    utilities/discovery_documents/firebasevertexai-openapi.yaml \
  --overrides-file \
    utilities/discovery_documents/firebasevertexai-overrides.yaml \
  --output-dir Sources/InternalGeminiDataModels \
  --roots GenerateContentRequest GenerateContentResponse \
    TemplateGenerateContentRequest CountTokensRequest CountTokensResponse \
  --strip-prefix GoogleAiGenerativelanguageV1beta \
    GoogleCloudAiplatformV1beta1 \
  --namespace GeminiDataModels \
  --access-level package
```
