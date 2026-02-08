---
name: setup
description: >-
  Use this skill when the user asks about setting up the MusaDSL plugin,
  configuring API keys, checking plugin status, troubleshooting
  the knowledge base connection, on first use of the plugin,
  or when the user wants to know what capabilities are available.
version: 0.2.0
---

# MusaDSL Plugin Setup & Welcome

Guide the user through the initial setup and configuration of the MusaDSL knowledge base plugin. Also serves as the main entry point for users who want to understand the plugin's capabilities.

## Process

1. **Check status** using the `check_setup` MCP tool to determine what's configured.

2. **Guide the user** based on the results:

### If Voyage API key is NOT SET

Explain to the user:

- They need a Voyage AI API key for semantic search to work
- Get one at https://dash.voyageai.com/
- Add it to their shell profile:

  ```bash
  # For zsh (default on macOS)
  echo 'export VOYAGE_API_KEY="your-key-here"' >> ~/.zshrc
  source ~/.zshrc

  # For bash
  echo 'export VOYAGE_API_KEY="your-key-here"' >> ~/.bashrc
  source ~/.bashrc
  ```

- After setting the variable, restart Claude Code for the MCP server to pick it up

### If knowledge base is NOT FOUND

Explain that the knowledge base should auto-download on session start. Suggest:

- Restart Claude Code to trigger the auto-download
- Check internet connectivity
- The download comes from GitHub Releases and is cached locally (~20MB)

### If everything is configured

Present a **welcome and capabilities overview**. This is the full picture of what the plugin provides:

---

**Welcome!** The MusaDSL knowledge base plugin is fully configured and ready.

**How it works:** The plugin gives Claude accurate, in-depth knowledge of the MusaDSL framework for algorithmic composition in Ruby. It works through three layers:

1. **Static reference** — A condensed API reference always loaded in context, covering all MusaDSL subsystems (series, sequencer, neumas, scales, generative tools, transcription, transport, MIDI, etc.)

2. **Semantic search** — An MCP server with a vector database that retrieves relevant documentation, API details, and code examples on demand. This is what makes answers accurate and sourced.

3. **Works catalog** — Find similar compositions from the demo projects and from your own indexed private works.

**Two databases, two purposes:**

- **Public knowledge base** (`knowledge.db`) — Contains the official MusaDSL documentation, API reference, 23 demo projects, and supporting gem docs. This database is automatically downloaded and updated from GitHub Releases. You don't need to maintain it.

- **Private works database** (`private.db`) — An optional local database for your own composition projects. If you index your works, Claude can reference them when searching for similar compositions or code patterns. This database is never touched by automatic updates — your private content is always safe.

  To index your own works:
  ```bash
  ruby mcp_server/indexer.rb --add-work /path/to/your/composition
  ruby mcp_server/indexer.rb --scan /path/to/your/works
  ```

**Available skills:**

- `/musa-claude-plugin:explain` — Ask about any MusaDSL concept and get an accurate, sourced explanation. Examples: "explain series operations", "how does the sequencer work", "show me neumas syntax", "explain Markov chains"

- `/musa-claude-plugin:setup` — (this skill) Check plugin status, see this capabilities overview, or troubleshoot configuration issues

**Available MCP tools** (used automatically when answering questions):

| Tool | What it does |
|------|-------------|
| `search` | Semantic search across all knowledge — docs, API, demos, and private works (kind: `"all"`, `"docs"`, `"api"`, `"demo_readme"`, `"demo_code"`, `"gem_readme"`, `"private_works"`) |
| `api_reference` | Look up exact API reference by module and method name |
| `similar_works` | Find demo projects and private works similar to a description |
| `dependencies` | What setup is needed for a concept (gems, objects, config) |
| `pattern` | Get a working code pattern for a specific composition technique |
| `check_setup` | Check the status of the plugin configuration |

If the `check_setup` results show a private works database is present, mention how many chunks it contains. If not present, mention that the user can optionally index their own compositions.

---

## Security

- **NEVER** ask the user to type, paste, or share their API key in this conversation
- Only check for the **presence** of the key via the `check_setup` tool — it never reveals the value
- If the user volunteers their key in the chat, warn them that sharing secrets in conversations is not recommended
