# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rubygems/package"
require "tmpdir"
require "yaml"
require "zlib"
load File.expand_path("../scripts/audit-opencode-upstream-release", __dir__)

class AuditOpenCodeUpstreamReleaseTest < Minitest::Test
  def test_reports_release_sensitive_changes_without_enabling_package
    Dir.mktmpdir("agentlab-opencode-release-audit-", "/srv/tmp") do |directory|
      repo = File.join(directory, "upstream")
      FileUtils.mkdir_p(File.join(repo, "packages", "opencode"))
      FileUtils.mkdir_p(File.join(repo, "patches"))
      git(repo, "init", "--quiet")
      git(repo, "config", "user.name", "Test")
      git(repo, "config", "user.email", "test@example.invalid")

      write_release(repo, "1.0.0", "old-lock", "old-patch")
      git(repo, "add", ".")
      git(repo, "commit", "--quiet", "-m", "old release")
      git(repo, "tag", "v1.0.0")
      old_commit = git(repo, "rev-parse", "HEAD")

      write_release(repo, "1.0.1", "new-lock", "new-patch")
      git(repo, "add", ".")
      git(repo, "commit", "--quiet", "-m", "new release")
      git(repo, "tag", "v1.0.1")

      manifest = File.join(directory, "package.yml")
      File.write(manifest, YAML.dump({
        "name" => "opencode",
        "status" => "blocked",
        "upstream" => {
          "current_version" => "1.0.0",
          "tag_prefix" => "v",
          "source_tag" => "v1.0.0",
          "source_commit" => old_commit,
          "source_sha256" => "0" * 64,
        },
        "copr" => { "enabled" => false },
      }))
      archive = File.join(directory, "opencode-1.0.1.tar.gz")
      create_archive(archive, "1.0.1")

      result = OpenCodeUpstreamReleaseAudit.audit(
        package_manifest: manifest,
        repo: repo,
        archive: archive,
        latest_version: "1.0.1",
      )

      assert_equal("1.0.1", result.dig("latest_release", "version"))
      assert(result.dig("delta", "release_sensitive_paths", "bun.lock"))
      assert(result.dig("delta", "release_sensitive_paths", "packages/opencode/package.json"))
      assert(result.dig("delta", "patch_inputs_changed"))
      assert(result.dig("delta", "selected_source_evidence_refresh_required"))
      assert(result.dig("package_state", "blocked_state_preserved"))
      refute(result.dig("package_state", "copr_enabled"))

      package = YAML.safe_load_file(manifest, aliases: false)
      package.fetch("copr")["enabled"] = true
      File.write(manifest, YAML.dump(package))
      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.audit(
          package_manifest: manifest,
          repo: repo,
          archive: archive,
          latest_version: "1.0.1",
        )
      end
      assert_equal("OpenCode COPR package must remain disabled", error.message)
    end
  end

  private

  def git(repo, *arguments)
    output, error, status = Open3.capture3("git", "-C", repo, *arguments)
    raise error unless status.success?

    output.strip
  end

  def write_release(repo, version, lock, patch)
    File.write(File.join(repo, "bun.lock"), lock)
    File.write(File.join(repo, "package.json"), JSON.generate({ "version" => version }))
    File.write(File.join(repo, "packages", "opencode", "package.json"), JSON.generate({ "version" => version }))
    File.write(File.join(repo, "patches", "dependency.patch"), patch)
  end

  def create_archive(path, version)
    Zlib::GzipWriter.open(path) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        content = JSON.generate({ "version" => version })
        tar.add_file_simple("opencode-#{version}/packages/opencode/package.json", 0o644, content.bytesize) do |file|
          file.write(content)
        end
      end
    end
  end
end
