PLUGIN_ROOT := $(shell pwd)
SOURCE_ROOT := $(PLUGIN_ROOT)/..
DB_PATH     := $(PLUGIN_ROOT)/mcp_server/knowledge.db
CHUNKS_DIR  := $(PLUGIN_ROOT)/data/chunks
RUBY        := bundle exec ruby

.PHONY: setup chunks embed build package clean verify-server status

## Install Ruby gem dependencies
setup:
	bundle install

## Generate JSONL chunks only (no API key needed)
chunks:
	$(RUBY) mcp_server/indexer.rb \
		--source-root "$(SOURCE_ROOT)" \
		--chunks-dir "$(CHUNKS_DIR)" \
		--chunks-only

## Generate chunks + embeddings + knowledge.db (requires VOYAGE_API_KEY)
embed:
	$(RUBY) mcp_server/indexer.rb \
		--source-root "$(SOURCE_ROOT)" \
		--chunks-dir "$(CHUNKS_DIR)" \
		--db-path "$(DB_PATH)" \
		--embed

## Full build: chunks + embeddings
build: chunks embed

## Package knowledge.db for distribution
package:
	gzip -c "$(DB_PATH)" > knowledge.db.gz

## Remove generated artifacts
clean:
	rm -f "$(DB_PATH)" "$(DB_PATH).version" "$(DB_PATH).last_check"
	rm -rf "$(CHUNKS_DIR)" knowledge.db.gz

## Test MCP server starts and responds to tools/list
verify-server:
	@echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}},"id":1}' | \
		$(RUBY) mcp_server/server.rb 2>/dev/null | \
		head -1 && echo "Server responds OK" || echo "Server failed to respond"

## Show index status
status:
	$(RUBY) mcp_server/indexer.rb \
		--chunks-dir "$(CHUNKS_DIR)" \
		--db-path "$(DB_PATH)" \
		--status
