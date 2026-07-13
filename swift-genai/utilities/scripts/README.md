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
```

---

## Usage Instructions

Use [generate_types.py](generate_types.py) to parse API discovery docs and write
clean Swift types into target folders.

### Command-Line Arguments Reference

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--discovery-doc` | `utilities/discovery_documents/generativelanguage-discovery.json` | Path to the source discovery JSON file. |
| `--output-dir` | `Sources/GeminiAPIClient/DataModels/GoogleAI` | Target directory for the generated Swift files. |
| `--roots` | `["GenerateContentRequest", "GenerateContentResponse"]` | Starting schemas to resolve transitively. |
| `--access-level` | `public` | Access keyword for generated declarations (`public`, `package`, etc.). |
| `--strip-prefix` | `""` | Optional prefix to strip from schema names/references. |
| `--namespace` | `GoogleAI` | Root Swift namespace enclosing the generated types. |
| `--templates-dir` | `utilities/templates` | Directory containing the Jinja2 Swift template files. |

---

## Copy-Paste Recipes

Use the following recipes from the project root to regenerate the SPM targets:

### 1. Regenerating `GoogleAIDataModels`
```bash
python utilities/scripts/generate_types.py \
  --discovery-doc \
    utilities/discovery_documents/generativelanguage-discovery.json \
  --output-dir Sources/GoogleAIDataModels \
  --roots GenerateContentRequest GenerateContentResponse \
  --namespace GoogleAI \
  --access-level package
```

### 2. Regenerating `AgentPlatformDataModels`
```bash
python utilities/scripts/generate_types.py \
  --discovery-doc \
    utilities/discovery_documents/aiplatform-discovery.json \
  --output-dir Sources/AgentPlatformDataModels \
  --roots GenerateContentRequest GenerateContentResponse \
  --strip-prefix GoogleCloudAiplatformV1beta1 \
  --namespace AgentPlatform \
  --access-level package
```
