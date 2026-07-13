# API Discovery Documents

This directory contains the Google API Discovery Documents used as the source of
truth for generating type-safe Swift structures.

## Document List

*   [generativelanguage-discovery.json](generativelanguage-discovery.json): The
    schema definitions for the Gemini Developer API (Google AI).
*   [aiplatform-discovery.json](aiplatform-discovery.json): The schema
    definitions for the Gemini Enterprise Agent Platform API (formerly Vertex
    AI).

---

## Fetching Updates

These JSON documents describe the API metadata and can be fetched directly from
Google's Discovery Service using the following REST endpoints:

### Gemini Developer API
*   **API Version**: `v1beta`
*   **Discovery URL**:
    `https://generativelanguage.googleapis.com/$discovery/rest?version=v1beta`
*   **Fetch Command**:
    ```bash
    curl -o generativelanguage-discovery.json \
      "https://generativelanguage.googleapis.com/\$discovery/rest?version=v1beta"
    ```

### Gemini Enterprise Agent Platform API
*   **API Version**: `v1beta1`
*   **Discovery URL**:
    `https://aiplatform.googleapis.com/$discovery/rest?version=v1beta1`
*   **Fetch Command**:
    ```bash
    curl -o aiplatform-discovery.json \
      "https://aiplatform.googleapis.com/\$discovery/rest?version=v1beta1"
    ```
