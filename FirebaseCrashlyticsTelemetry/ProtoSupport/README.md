# ProtoSupport

This directory manages the fetching, configuration, and compilation of **OpenTelemetry (OTel) proto schemas** using `nanopb`.

---

## 🛠️ Prerequisites

| Dependency | Requirement | Why |
| :--- | :--- | :--- |
| **Python** | `<= 3.10` | Firebase nanopb generation scripts are incompatible with Python 3.11+. |
| **Protobuf** | `pip install protobuf` | Required by the compiler to parse schemas. |

---

## 📂 Directory Layout & Rules

* **`ProtoSupport/`**
  * `generate_protos.sh` — The core generation script.
  * `Options/` — **Modify configs here.** Contains `.options` files. The script automatically pairs these with matching `.proto` files.
  * `third_party/opentelemetry-proto/Protos/` — **Do not edit.** This is an upstream mirror. It is entirely wiped and recreated on every run.
* **`../Sources/Protogen/nanopb`** — **Output destination** for the compiled `.pb.c` and `.pb.h` files.

---

## 🚀 How to Run

Execute the script from this directory:

```bash
./generate_protos.sh
```

### What it does:
1. **Cleans** previous schemas and compiled outputs.
2. **Clones** OTel protos into `Protos/`.
3. **Pairs** them with the custom configurations from `Options/`.
4. **Compiles** consistent C/H files using the shared `firebase-ios-sdk` script.
