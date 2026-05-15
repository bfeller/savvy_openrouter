## [Unreleased]

## [0.4.1] - 2026-05-15

### Added

- **`file_parser_pdf_engine`** in YAML / `Configuration` (or **`OPENROUTER_FILE_PARSER_PDF_ENGINE`**): choose OpenRouter **`file-parser`** PDF engine (`native`, `cloudflare-ai`, `mistral-ocr`, …). **`RequestPlugins.prepare_chat_body!(body, pdf_engine: …)`** applies it when injecting or completing the **`file-parser`** plugin.
- **`api_call_log`:** failed JSON HTTP responses populate **`error_message`** from the API **`error.message`** when the column is mapped (`response_json` still holds the full body).

### Documentation

- README: PDF engine configuration.

## [0.4.0] - 2026-05-15

### Added

- **`require "savvy_openrouter/patterns"`:** Pure-Ruby structured JSON validation after HTTP 200 for chat (`json_object` / `json_schema`) and Responses (`text.format`). Raises **`SavvyOpenrouter::StructuredOutputError`** (`reason`, `response_body`).
- **`require "savvy_openrouter/request_plugins"`:** **`prepare_chat_body!`** / **`prepare_responses_body!`** inject OpenRouter **response-healing** and **file-parser** (Cloudflare PDF) for chat when applicable.
- **`responses_retries`** in YAML or on **`Client`:** same shape as **`chat_retries`** for **`POST /responses`** — zero **`usage.output_tokens`**, selected **`status`** values, and optional HTTP error retries; **`Resources::Responses#create`** runs the retry loop with backoff.
- **`api_call_log.responses_attempts`:** **`final`** defers Responses logging to the last HTTP attempt (like **`chat_attempts`**); **`all`** logs every attempt (default). **`Connection#flush_deferred_responses_log!`** flushes after the loop.

### Documentation

- README: patterns, request plugins, `responses_retries`, `responses_attempts`.

## [0.3.0] - 2026-05-15

### Changed

- **`api_call_log`:** Column map keys are a **whitelist**: every `source => db_column` entry is copied from the logged attrs when `source` is present, so apps can map **passthrough** context (for example `bill_forward_event_id`) without gem changes.
- **`api_call_log` / connection:** Additional canonical attrs populated on JSON requests when mapped: **`http_status`**, **`success`**, **`generation_id`** (from `x-generation-id` or JSON `id`), **`usage`**, **`cost`** (derived from usage when possible), **`logical_model`**, **`endpoint` / resource context**, structured **`request_json`** / **`response_json`** (JSON columns should receive serialized objects; coercion formats these for storage).
- **`chat_attempts`:** `final` defers chat completion logging until the **last** HTTP attempt of a retry loop (one row per logical call); `all` logs **each** attempt (default). Set under `api_call_log` in YAML or client options.
- **`Connection#with_call_context`:** Merges a shallow hash into the active logging context for nested calls (e.g. billing ids); **`suppress_api_call_log: true`** skips persistence for that scope.
- **`Connection#record_manual_api_call` / `Client#record_api_call`:** Persist a row after HTTP success for **logical** failures (invalid structured JSON, validation), merged with the current call context.

### Documentation

- README and install template: expanded `api_call_log` examples and new options.

## [0.2.0] - 2026-05-09

### Added

- **`Chat`:** configurable **`chat_retries`** / **`completion_retries`** for **`client.chat.completions`** — retries on empty assistant text, **`usage.completion_tokens == 0`**, and HTTP **429** / **502** / **500**/**501** / **503** with backoff (streaming unchanged).
- **`Models`:** `SavvyOpenrouter::Resources::Models#list` forwards keyword arguments as **`GET /models`** query parameters (`category`, `output_modalities`, `supported_parameters`, etc.).
- **`Models`:** `SavvyOpenrouter::Resources::Models#first_ranked_free_text_model(category:, output_modalities: "text")` returns the first model in the API response whose **`pricing.prompt`** and **`pricing.completion`** are both zero, preserving OpenRouter’s list order (used to mirror curated “top free” picks per category when combined with text modality filters).
- **`Configuration`:** `api_call_log` in YAML or `api_call_log:` on the client — optional persistence of each HTTP exchange to a model class (`create!`) with user-defined column mappings for debugging (JSON, raw, and streaming paths).
- **`Configuration`:** `responses_defaults` / `defaults_responses` in YAML or `responses_defaults:` on the client: merged only into **`POST /responses`**, so Responses-only fields (plugins, server tools, `max_output_tokens`, …) are not merged into chat, embeddings, rerank, audio, or Anthropic bodies.

### Documentation

- **README:** chat completion retries (`chat_retries`), API call logging (`api_call_log`), Models API, usage snippets, and integration test notes.

## [0.1.0] - 2026-05-09

### Added

- `SavvyOpenrouter::Client` with resources for chat (incl. SSE streaming), Responses beta, Anthropic `/messages`, embeddings, rerank, models, credits, providers, generations, endpoints (ZDR), analytics (`/activity`), audio (speech + transcription), video generation (create, poll, download, stream, `poll_until`), OAuth PKCE helpers, API keys, organization members, guardrails, and workspaces.
- YAML configuration discovery (`config/savvy_openrouter.yml`, `.savvy_openrouter.yml`) with merge defaults for chat and video requests.
- Rails generator `savvy_openrouter:install` and CLI `savvy_openrouter install`.
