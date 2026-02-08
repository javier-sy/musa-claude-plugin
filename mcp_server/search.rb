# frozen_string_literal: true

# Search functions backed by sqlite-vec.
#
# Falls back gracefully when the database is not yet built.

require_relative "db"

module MusaKnowledgeBase
  module Search
    SETUP_HINT =
      "The plugin is not fully configured. " \
      "Please run /musa-claude-plugin:setup to complete the initial setup."

    VOYAGE_ERROR_HINT =
      "The Voyage AI API key is not working (it may be expired, revoked, or mistyped). " \
      "Please run /musa-claude-plugin:setup to diagnose the issue."

    module_function

    def db_path
      DB.default_db_path
    end

    def db_available?
      File.exist?(db_path)
    end

    def api_key_configured?
      key = ENV["VOYAGE_API_KEY"].to_s
      !key.empty? && !key.include?("${")
    end

    # Check preconditions for search. Returns an error message string, or nil if ready.
    def check_preconditions
      return "[Knowledge base not found. #{SETUP_HINT}]" unless db_available?
      unless api_key_configured?
        return "[Voyage API key not configured — no VOYAGE_API_KEY environment variable found. #{SETUP_HINT}]"
      end

      nil
    end

    def semantic_search(query, kind = "all")
      error = check_preconditions
      return error if error

      with_db { |db| DB.search_collections(db, query, kind: kind, n_results: 5) }
    end

    def api_lookup(module_name, method = "")
      error = check_preconditions
      return error if error

      query = "#{module_name} #{method}".strip
      with_db { |db| DB.search_collections(db, query, kind: "api", n_results: 5) }
    end

    def similar_works(description)
      error = check_preconditions
      return error if error

      with_db do |db|
        results_readme = DB.search_collections(db, description, kind: "demo_readme", n_results: 3)
        results_code = DB.search_collections(db, description, kind: "demo_code", n_results: 3)
        "## Demo Descriptions\n#{results_readme}\n\n## Demo Code\n#{results_code}"
      end
    end

    def dependency_chain(concept)
      error = check_preconditions
      return error if error

      with_db do |db|
        docs = DB.search_collections(db, "setup requirements for #{concept}", kind: "docs", n_results: 3)
        code = DB.search_collections(db, "require include #{concept}", kind: "demo_code", n_results: 2)
        "## Documentation\n#{docs}\n\n## Code Examples\n#{code}"
      end
    end

    def code_pattern(technique)
      error = check_preconditions
      return error if error

      with_db do |db|
        code = DB.search_collections(db, technique, kind: "demo_code", n_results: 3)
        docs = DB.search_collections(db, technique, kind: "docs", n_results: 2)
        "## Code Examples\n#{code}\n\n## Related Documentation\n#{docs}"
      end
    end

    # Open DB, yield, close, and catch Voyage AI errors gracefully.
    def with_db
      db = DB.open
      begin
        yield db
      rescue RuntimeError => e
        if e.message.include?("Voyage AI")
          "[#{VOYAGE_ERROR_HINT}]"
        else
          raise
        end
      ensure
        db.close
      end
    end
  end
end
