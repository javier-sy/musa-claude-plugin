# musa-claude-plugin

Deep MusaDSL knowledge for Claude Code — semantic search over documentation, API reference, and examples for algorithmic composition.

## What it does

This plugin gives Claude Code accurate, in-depth knowledge of the [MusaDSL](https://musadsl.yeste.studio) framework through three layers:

1. **Static reference** (`rules/musadsl-reference.md`) — always loaded in context (~5-8k tokens)
2. **Semantic search** (MCP server + sqlite-vec) — retrieves relevant docs, API, and code examples on demand
3. **Works catalog** — finds similar compositions from demos and private indexed works

### MCP Tools

| Tool | Purpose |
|------|---------|
| `search` | Semantic search across all knowledge (docs, API, demos) |
| `api_reference` | Exact API reference lookup by module/method |
| `similar_works` | Find similar works and demo examples |
| `dependencies` | Dependency chain for a concept (what setup is needed) |
| `pattern` | Code pattern for a specific technique |

### Skill

- `/musa-claude-plugin:explain` — Explain MusaDSL concepts with accurate, sourced answers

## Installation (end users)

### Prerequisites

- Ruby 3.1+
- `VOYAGE_API_KEY` environment variable (for embedding search queries at runtime)

### Steps

Inside Claude Code, run:

```
/plugin marketplace add javier-sy/musa-claude-plugin
/plugin install musa-claude-plugin@javier-sy-musa-claude-plugin
```

Then set your Voyage AI API key (add to your shell profile for persistence):

```bash
export VOYAGE_API_KEY="your-key-here"
```

The pre-built knowledge base is **automatically downloaded** from GitHub Releases on first session start. No additional setup is needed.

## Development (plugin maintainers)

If you want to modify the plugin or rebuild the knowledge base from source, you need the full MusaDSL ecosystem cloned alongside this plugin (all repos under the same parent directory).

### Prerequisites

- Everything from the end-user section above
- All MusaDSL source repositories cloned as siblings of `musa-claude-plugin/`
- `VOYAGE_API_KEY` with sufficient quota for embedding ~3000 chunks

### Rebuilding the knowledge base

```bash
# Generate chunks only (no API key needed, useful for inspection)
make chunks

# Full build: chunks + embeddings + knowledge.db (requires VOYAGE_API_KEY)
make build

# Package knowledge.db for distribution via GitHub Releases
make package

# Check index status
make status

# Remove all generated artifacts
make clean
```

The CI workflow (`.github/workflows/build-release.yml`) automates building and releasing the knowledge base on tagged commits.

## Project Structure

```
musa-claude-plugin/
├── .claude-plugin/          # Plugin metadata
├── skills/explain/          # Explain skill definition
├── rules/                   # Static reference (always in context)
├── mcp_server/              # Ruby MCP server + sqlite-vec
│   ├── server.rb            # MCP tools (5 tools)
│   ├── search.rb            # sqlite-vec-backed search
│   ├── chunker.rb           # Source material → chunks
│   ├── indexer.rb           # Chunk + embed + store orchestrator
│   ├── embeddings.rb        # Voyage AI integration
│   ├── db.rb                # sqlite-vec database management
│   └── ensure_db.rb         # Auto-download DB from releases
├── hooks/                   # Session lifecycle hooks
├── .mcp.json                # MCP server configuration
├── Gemfile                  # Ruby dependencies
├── Makefile                 # Build targets
└── .github/workflows/       # CI: build + release knowledge DB
```

## License

GPL-3.0-or-later

## Author

Javier Sánchez Yeste — [yeste.studio](https://yeste.studio)
