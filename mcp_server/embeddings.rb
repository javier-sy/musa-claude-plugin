# frozen_string_literal: true

# Voyage AI embedding integration for sqlite-vec.
#
# Uses voyage-code-3 model with asymmetric search:
# - input_type: "document" for indexing
# - input_type: "query" for searching

require "net/http"
require "json"
require "uri"

module NotaKnowledgeBase
  module Voyage
    API_URL    = URI("https://api.voyageai.com/v1/embeddings")
    MODEL      = "voyage-code-3"
    DIMENSIONS = 1024
    BATCH_SIZE = 50

    class Client
      def initialize(api_key: nil, input_type: "document")
        @api_key    = api_key || ENV.fetch("VOYAGE_API_KEY", "")
        @input_type = input_type
      end

      # Embed a list of texts. Returns an array of float arrays.
      def embed(texts)
        return [] if texts.empty?

        all_embeddings = []

        texts.each_slice(BATCH_SIZE) do |batch|
          body = {
            input:      batch,
            model:      MODEL,
            input_type: @input_type,
            truncation: true
          }

          response = post_json(body)
          data = JSON.parse(response.body)

          if data["data"]
            batch_embeddings = data["data"]
              .sort_by { |d| d["index"] }
              .map { |d| d["embedding"] }
            all_embeddings.concat(batch_embeddings)
          else
            error = data["detail"] || data["error"] || "Unknown error"
            raise "Voyage AI API error: #{error}"
          end
        end

        all_embeddings
      end

      private

      def post_json(body)
        http = Net::HTTP.new(API_URL.host, API_URL.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(API_URL.path)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"]  = "application/json"
        request.body = JSON.generate(body)

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Voyage AI HTTP #{response.code}: #{response.body}"
        end

        response
      end
    end

    def self.document_embedder(api_key: nil)
      Client.new(api_key: api_key, input_type: "document")
    end

    def self.query_embedder(api_key: nil)
      Client.new(api_key: api_key, input_type: "query")
    end
  end
end
