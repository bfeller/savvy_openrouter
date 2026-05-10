## [Unreleased]

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
