---
name: setup
description: >-
  Use this skill when the user asks about setting up the MusaDSL plugin,
  configuring API keys, checking plugin status, troubleshooting
  the knowledge base connection, or on first use of the plugin.
version: 0.1.0
---

# MusaDSL Plugin Setup

Guide the user through the initial setup and configuration of the MusaDSL knowledge base plugin.

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
- The download comes from GitHub Releases and is cached locally

### If everything is configured

Confirm the plugin is ready and briefly mention the available capabilities:

- `/explain` — Ask about any MusaDSL concept
- MCP tools: `search`, `api_reference`, `similar_works`, `dependencies`, `pattern`

## Security

- **NEVER** ask the user to type, paste, or share their API key in this conversation
- Only check for the **presence** of the key via the `check_setup` tool — it never reveals the value
- If the user volunteers their key in the chat, warn them that sharing secrets in conversations is not recommended
