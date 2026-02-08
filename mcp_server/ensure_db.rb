#!/usr/bin/env ruby
# frozen_string_literal: true

# Auto-download/update knowledge.db from GitHub Releases.
#
# Called by hooks/hooks.json on SessionStart.
# Design constraints:
# - Non-blocking: always exits 0, even on failure
# - Rate-limited: checks at most once per 24h
# - Graceful degradation: if GitHub unreachable, use existing DB
# - Atomic update: download to temp file, then replace
#
# Uses only stdlib — no bundle exec needed.

require "net/http"
require "json"
require "uri"
require "zlib"
require "stringio"
require "tempfile"
require "fileutils"

GITHUB_REPO = "javier-sy/musa-claude-plugin"
RELEASE_API_URL = URI("https://api.github.com/repos/#{GITHUB_REPO}/releases/latest")
CHECK_INTERVAL_SECONDS = 24 * 60 * 60  # 24 hours

def get_db_path
  env_path = ENV["KNOWLEDGE_DB_PATH"]
  return env_path if env_path

  plugin_root = ENV["CLAUDE_PLUGIN_ROOT"]
  if plugin_root
    File.join(plugin_root, "mcp_server", "knowledge.db")
  else
    File.join(__dir__, "knowledge.db")
  end
end

def should_check?(db_path)
  last_check_file = "#{db_path}.last_check"
  return true unless File.exist?(last_check_file)

  last_check = File.read(last_check_file).strip.to_f
  (Time.now.to_f - last_check) > CHECK_INTERVAL_SECONDS
rescue
  true
end

def update_last_check(db_path)
  File.write("#{db_path}.last_check", Time.now.to_f.to_s)
end

def get_local_version(db_path)
  version_file = "#{db_path}.version"
  return nil unless File.exist?(version_file)

  File.read(version_file).strip
rescue
  nil
end

def fetch_latest_release
  http = Net::HTTP.new(RELEASE_API_URL.host, RELEASE_API_URL.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 10

  request = Net::HTTP::Get.new(RELEASE_API_URL.path)
  request["Accept"] = "application/vnd.github+json"

  response = http.request(request)
  return nil unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body)
  tag = data["tag_name"]
  assets = data["assets"] || []

  asset = assets.find { |a| a["name"] == "knowledge.db.gz" }
  return nil unless asset

  [tag, asset["browser_download_url"]]
rescue
  nil
end

def download_and_replace(url, db_path, version)
  uri = URI(url)

  # Follow redirects (GitHub uses them for asset downloads)
  max_redirects = 5
  max_redirects.times do
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    response = http.request(Net::HTTP::Get.new(uri))

    case response
    when Net::HTTPRedirection
      uri = URI(response["location"])
      next
    when Net::HTTPSuccess
      # Decompress gzip to temp file, then atomic move
      tmpfile = Tempfile.new(["knowledge", ".db"], File.dirname(db_path))
      begin
        gz = Zlib::GzipReader.new(StringIO.new(response.body))
        tmpfile.binmode
        tmpfile.write(gz.read)
        tmpfile.close
        gz.close

        FileUtils.mv(tmpfile.path, db_path)

        File.write("#{db_path}.version", version)
        update_last_check(db_path)
        return true
      rescue
        tmpfile.close
        tmpfile.unlink rescue nil
        return false
      end
    else
      return false
    end
  end

  false
rescue
  false
end

def main
  db_path = get_db_path

  # Ensure parent directory exists
  FileUtils.mkdir_p(File.dirname(db_path))

  # Rate limit check
  unless should_check?(db_path)
    return
  end

  # Query GitHub for latest release
  release_info = fetch_latest_release
  if release_info.nil?
    update_last_check(db_path)
    return
  end

  tag, asset_url = release_info
  local_version = get_local_version(db_path)

  if local_version == tag
    update_last_check(db_path)
    return
  end

  # Download and update
  download_and_replace(asset_url, db_path, tag)
end

if __FILE__ == $PROGRAM_NAME
  begin
    main
  rescue
    # Never fail — graceful degradation
  end
  exit 0
end
