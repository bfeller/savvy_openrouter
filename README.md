# Savvy OpenRouter

Ruby client for [OpenRouter](https://openrouter.ai/) — unified access to chat models, embeddings, reranking, speech, transcription, **video generation**, OAuth, API keys, guardrails, workspaces, and related REST endpoints.

## Installation

Add to your Gemfile:

```ruby
gem "savvy_openrouter"
```

Or install the gem directly:

```bash
gem install savvy_openrouter
```

## Configuration

Precedence is **keyword arguments to `SavvyOpenrouter::Client`** (highest), then **YAML config**, then **environment variables** (lowest).

### Environment variables

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | Bearer token (required for requests) |
| `OPENROUTER_BASE_URL` | API base (default `https://openrouter.ai/api/v1`) |
| `OPENROUTER_DEFAULT_MODEL` | Default `model` when omitted in request bodies |
| `OPENROUTER_HTTP_REFERER` | `HTTP-Referer` header ([app attribution](https://openrouter.ai/docs/app-attribution.mdx)) |
| `OPENROUTER_APP_TITLE` | `X-Title` header |

### YAML config (optional)

If `config/savvy_openrouter.yml` or `.savvy_openrouter.yml` exists in the working directory, it is loaded automatically. Example:

```yaml
api_key: "sk-or-v1-..."
default_model: "openai/gpt-4o-mini"
defaults:
  temperature: 0.7
  max_tokens: 4096
video_defaults:
  aspect_ratio: "16:9"
  resolution: "720p"
http_referer: "https://your-app.example.com"
app_title: "Your App"

# Responses API only (POST /responses) — plugins, tools, max_output_tokens, x_search_filter, etc.
# Use this instead of putting `plugins` under global `defaults` (which would also merge into chat/embeddings).
# See https://openrouter.ai/docs/api/reference/responses/web-search
# responses_defaults:
#   plugins:
#     - id: web
#       max_results: 5
#   max_output_tokens: 4096
```

### API call logging (`api_call_log`)

Optional persistence of **every outbound OpenRouter HTTP request** made through this gem (JSON clients, raw/binary downloads, and streaming chat). Configure **`api_call_log`** in YAML or pass **`api_call_log:`** when building **`SavvyOpenrouter::Client`**.

It depends on **Active Record** (or any Ruby class you configure) exposing **`create!(attributes)`** — the usual Rails pattern. Define a migration for whatever columns you map (strings / integers / booleans / text); avoid indexing huge raw payloads on Postgres without care.

```yaml
# Optional — persist each outbound HTTP exchange for debugging (Faraday JSON + raw + SSE streams)
api_call_log:
  model: OpenRouterApiCallLog
  max_body_bytes: 65536
  columns:
    method: http_method          # GET, POST, …
    path: request_url            # full URL including query string when present
    status: response_status      # integer HTTP status (nil on transport failure before response)
    duration_ms: duration_ms     # float milliseconds
    request_body: request_body   # JSON-ish text; secrets redacted; truncated to max_body_bytes
    response_body: response_body # same treatment
    error_class: error_class     # nil when Faraday returned a response
    error_message: error_message # transport errors or truncated exception message
    streaming: streaming         # true for chat SSE streams
```

Canonical keys on the **left** (`method`, `path`, …) are fixed by the gem; **right-hand** names are your database columns. Omit mappings you do not need. Set **`api_call_log: false`** (or omit `model` / `columns`) to disable.

Logging failures never raise into your app code. Large bodies are truncated; **`Authorization`** / **`sk-or-v1-*`** patterns in serialized bodies are redacted (still treat logs as sensitive).

### Chat completion retries (`chat_retries`)

For **`client.chat.completions`** only (not streaming), you can retry when OpenRouter returns a **successful HTTP 200** but the payload looks broken—common with **free tiers** (`usage.completion_tokens == 0`) or an **empty assistant `content`**—and on selected **HTTP errors** (`429`, `502`, `500`/`501`, `503`).

Configure **`chat_retries`** in YAML or pass **`chat_retries:`** / **`completion_retries:`** to **`SavvyOpenrouter::Client`**. Retries are off unless **`max_attempts`** is **greater than 1**.

```yaml
chat_retries:
  max_attempts: 4
  base_delay_ms: 400
  max_delay_ms: 8000
  exponential_backoff: true   # default true; set false for fixed delay
  jitter_ratio: 0.15          # 0–1, fraction of delay added randomly
  on:                           # optional overrides (default true for each unless set false)
    zero_completion_tokens: true
    empty_assistant_content: true
    rate_limit: true
    bad_gateway: true
    internal_server_error: true
    service_unavailable: true
```

After the last attempt, the gem returns the **final response body** (for 200s) or **re-raises** the last API error. **`completions_stream`** does not use this policy—handle streaming retries in your own code if needed.

### Install templates

**Rails**

```bash
rails generate savvy_openrouter:install
```

**Plain Ruby / scripts**

```bash
bundle exec savvy_openrouter install
```

Creates `config/savvy_openrouter.yml` from the bundled template.

### Responses API: web search and plugins

The [Responses API](https://openrouter.ai/docs/api/reference/responses/overview) accepts parameters such as [`plugins`](https://openrouter.ai/docs/api/reference/responses/web-search) (legacy web plugin), [`tools`](https://openrouter.ai/docs/guides/features/server-tools/web-search) (recommended `openrouter:web_search` server tool for Chat Completions and Responses), `max_output_tokens`, and `x_search_filter` (xAI).

**Do not put those keys in the global `defaults` hash**, because `defaults` is merged into **chat completions, embeddings, rerank, audio,** etc. Instead use **`responses_defaults`** in YAML (or `responses_defaults:` when constructing `SavvyOpenrouter::Client`). Those keys are merged **only** into `client.responses.create(...)`.

Example:

```yaml
responses_defaults:
  plugins:
    - id: web
      max_results: 5
  max_output_tokens: 9000
```

Per-request arguments override the same keys from `responses_defaults`.

OpenRouter documents the legacy `plugins: [{ id: "web" }]` approach as deprecated in favor of the **`openrouter:web_search` server tool** via the `tools` array; you can still pass either shape through this gem as passthrough JSON.

### Models API (`GET /models`)

[`GET /api/v1/models`](https://openrouter.ai/docs/api/api-reference/models/get-models) supports optional **query parameters**, including `category` (for example `programming`, `roleplay`, `science`), `output_modalities` (for example `text`), and `supported_parameters`. Pass them as keywords to **`client.models.list`**:

```ruby
client.models.list(category: "programming", output_modalities: "text")
```

OpenRouter returns models in **curated rank order** within each filtered result set—that order is not “highest `context_length` wins.” To approximate the **top free text model** for a category, call **`first_ranked_free_text_model`**, which keeps API order and returns the **first** model whose **`pricing.prompt`** and **`pricing.completion`** both parse to zero:

```ruby
client.models.first_ranked_free_text_model(category: "programming")
client.models.first_ranked_free_text_model(category: "roleplay")
```

**Use a stored model id for normal traffic.** Resolving the free model calls **`GET /models`** (one request). Each chat turn is **`POST /chat/completions`** (another). If you call `first_ranked_free_text_model` (or `list` and pick) on **every** user message, you pay **two** API calls per turn—list plus chat. Instead, resolve **once** (at deploy, in a Rake task, or on a long TTL), **remember** the returned **`id`** (environment variable, database, cache, or `default_model` in `savvy_openrouter.yml`), and pass that string to **`client.chat.completions(model: ...)`** for ongoing requests. Refresh the stored id when you want to pick up a new “top free” model after OpenRouter changes their list.

That heuristic stays aligned with OpenRouter’s listing **as long as their ranking and pricing rows stay as they are**; it is not a separate benchmark score from the JSON (there is no `rating` field on each model). For chat-specific knobs such as **`tools`**, **`tool_choice`**, and **`response_format`** (including JSON schema), pass them on **`client.chat.completions`**; global YAML **`defaults`** also merge into embeddings and other resources, so prefer per-call args for tool and schema defaults unless you only use chat endpoints.

## Usage

```ruby
require "savvy_openrouter"

client = SavvyOpenrouter::Client.new(api_key: ENV.fetch("OPENROUTER_API_KEY"))

# Chat completion (defaults from YAML/env merged into body)
response = client.chat.completions(
  messages: [{ role: "user", content: "Hello!" }]
)
puts response[:choices].first[:message][:content]

# Streaming (SSE); each yielded string is a JSON `data:` payload from OpenRouter
client.chat.completions_stream(messages: [{ role: "user", content: "Hi" }]) do |data_json|
  chunk = JSON.parse(data_json)
  print chunk.dig("choices", 0, "delta", "content")
end

# Embeddings
client.embeddings.create(model: "openai/text-embedding-3-small", input: "Hello world")

# Video: create (HTTP 202), poll, download binary
job = client.videos.create(model: "google/veo-3.1", prompt: "A calm ocean at dawn")
status = client.videos.poll_until(job[:id])
video_bytes = client.videos.download(job[:id]) if status[:status].to_s == "completed"

# Binary speech (TTS)
audio_bytes = client.audio.speech(model: "elevenlabs/...", input: "Hello")

# Responses API (beta)
client.responses.create(model: "openai/gpt-4o", input: "Hello")

# Discover top free model for a category (GET /models) — run rarely; persist the id, do not call per user message
top_free = client.models.first_ranked_free_text_model(category: "programming")
# e.g. save top_free[:id] to ENV or default_model, then:
client.chat.completions(model: top_free[:id], messages: [{ role: "user", content: "Hello!" }])

# Management APIs (typically require a management key)
client.api_keys.list
client.guardrails.list
client.workspaces.list
```

See the [OpenRouter API reference](https://openrouter.ai/docs/api/reference/overview) for request/response shapes.

## Errors

API failures raise subclasses of `SavvyOpenrouter::ApiError` (for example `AuthenticationError`, `PaymentRequiredError`, `RateLimitError`, `BadGatewayError`). Every error exposes `#status_code` and `#response_body` when available.

## Development

```bash
bin/setup
bundle exec rake   # RSpec + RuboCop
```

Integration tests live in `spec/integration/` and are tagged `:integration`. When `OPENROUTER_API_KEY` is set, they call the live API (WebMock allows net connect only for those examples). Smoke chat examples use the free model `inclusionai/ring-2.6-1t:free`; **`spec/integration/free_model_rank_spec.rb`** asserts curated “first free” model ids for `programming` and `roleplay` against the live models list (these examples can fail if OpenRouter changes ordering or pricing).

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in this project's repositories is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
