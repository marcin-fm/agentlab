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
  def test_binds_archive_to_release_tree_and_hashes_downstream_patches
    with_release_fixture do |fixture|
      result = OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit))

      assert_equal("agentlab-opencode-upstream-release-audit/v3", result.fetch("schema"))
      assert_equal(fixture.fetch(:new_commit), result.dig("latest_release", "commit"))
      assert_equal("opencode-1.0.1", result.dig("latest_release", "archive_root"))
      assert(result.dig("latest_release", "archive_matches_commit_tree"))
      assert(result.dig("delta", "release_sensitive_paths", "bun.lock"))
      assert(result.dig("delta", "downstream_patch_revalidation_required"))
      assert(result.dig("delta", "selected_source_evidence_refresh_required"))
      assert(result.dig("package_state", "blocked_state_preserved"))
      refute(result.dig("package_state", "copr_enabled"))

      patches = result.dig("packaging_patch_inputs", "patches")
      assert_equal(["downstream.patch"], patches.map { |patch| patch.fetch("path") })
      assert_equal(Digest::SHA256.file(fixture.fetch(:patch)).hexdigest, patches.first.fetch("sha256"))
      assert_equal(["Source0"], patches.first.fetch("applications").map { |application| application.fetch("root") })
      refute(result.fetch("delta").key?("patch_inputs_changed"))
      assert_equal(
        "evidence/opencode/upstream-release-audit.json",
        result.dig("reproduction", "receipt_path"),
      )
      assert_empty(OpenCodeUpstreamReleaseAudit.receipt_errors(
        package_manifest: fixture.fetch(:manifest),
        package_spec: fixture.dig(:audit, :package_spec),
        receipt: result,
      ))
    end
  end

  def test_receipt_rejects_an_uncovered_package_update
    with_release_fixture do |fixture|
      result = OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit))
      package = YAML.safe_load_file(fixture.fetch(:manifest), aliases: false)
      package.fetch("upstream")["current_version"] = "1.0.2"
      package.fetch("upstream")["source_tag"] = "v1.0.2"
      package.fetch("upstream")["source_commit"] = "f" * 40
      package.fetch("upstream")["source_sha256"] = "f" * 64
      File.write(fixture.fetch(:manifest), YAML.dump(package))

      errors = OpenCodeUpstreamReleaseAudit.receipt_errors(
        package_manifest: fixture.fetch(:manifest),
        package_spec: fixture.dig(:audit, :package_spec),
        receipt: result,
      )
      assert_includes(errors, "receipt does not cover packaged version 1.0.2")
    end
  end

  def test_receipt_rejects_tampered_release_identity_and_spec_hash
    with_release_fixture do |fixture|
      result = OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit))
      result.fetch("latest_release")["tag"] = "v9.9.9"
      result.fetch("latest_release")["archive_root"] = "wrong-root"
      result.fetch("latest_release")["commit"] = "not-a-commit"
      result.fetch("packaging_patch_inputs")["spec_sha256"] = "0" * 64

      errors = OpenCodeUpstreamReleaseAudit.receipt_errors(
        package_manifest: fixture.fetch(:manifest),
        package_spec: fixture.dig(:audit, :package_spec),
        receipt: result,
      )
      assert_includes(errors, "receipt latest tag is inconsistent")
      assert_includes(errors, "receipt latest archive root is inconsistent")
      assert_includes(errors, "receipt latest commit is invalid")
      assert_includes(errors, "receipt packaging patch inputs mismatch")
    end
  end

  def test_receipt_covers_the_exact_audited_release_after_update
    with_release_fixture do |fixture|
      result = OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit))
      package = YAML.safe_load_file(fixture.fetch(:manifest), aliases: false)
      latest = result.fetch("latest_release")
      package.fetch("upstream")["current_version"] = latest.fetch("version")
      package.fetch("upstream")["source_tag"] = latest.fetch("tag")
      package.fetch("upstream")["source_commit"] = latest.fetch("commit")
      package.fetch("upstream")["source_sha256"] = latest.fetch("archive_sha256")
      File.write(fixture.fetch(:manifest), YAML.dump(package))

      assert_empty(OpenCodeUpstreamReleaseAudit.receipt_errors(
        package_manifest: fixture.fetch(:manifest),
        package_spec: fixture.dig(:audit, :package_spec),
        receipt: result,
      ))
    end
  end

  def test_rejects_archive_with_matching_version_but_wrong_release_content
    with_release_fixture do |fixture|
      write_archive(fixture.fetch(:archive), "opencode-1.0.1", [
        ["packages/opencode/package.json", JSON.generate({ "version" => "1.0.1" })],
      ])

      error = assert_raises(RuntimeError) { OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit)) }
      assert_match(/archive (?:PAX identity|tree) does not match resolved release commit/, error.message)
    end
  end

  def test_rejects_wrong_root_and_duplicate_members
    Dir.mktmpdir("agentlab-opencode-archive-test-", "/srv/tmp") do |directory|
      archive = File.join(directory, "archive.tar.gz")
      write_archive(archive, "wrong-root", [["packages/opencode/package.json", "{}"]])
      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.archive_tree(archive, "opencode-1.0.1")
      end
      assert_match(/outside exact root/, error.message)

      write_archive(archive, "opencode-1.0.1", [
        ["packages/opencode/package.json", "{}"],
        ["packages/opencode/package.json", "{}"],
      ])
      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.archive_tree(archive, "opencode-1.0.1")
      end
      assert_match(/duplicate member/, error.message)
    end
  end

  def test_rejects_unsafe_paths
    Dir.mktmpdir("agentlab-opencode-archive-test-", "/srv/tmp") do |directory|
      archive = File.join(directory, "archive.tar.gz")
      write_archive(archive, "opencode-1.0.1", [["../escape", "bad"]])

      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.archive_tree(archive, "opencode-1.0.1")
      end
      assert_match(/unsafe/, error.message)
    end
  end

  def test_rejects_member_and_archive_size_limits
    Dir.mktmpdir("agentlab-opencode-archive-test-", "/srv/tmp") do |directory|
      archive = File.join(directory, "archive.tar.gz")
      write_archive(archive, "opencode-1.0.1", [["packages/opencode/package.json", "123456789"]])

      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.archive_tree(
          archive,
          "opencode-1.0.1",
          limits: { member_bytes: 8 },
        )
      end
      assert_match(/member exceeds size limit/, error.message)

      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.archive_tree(
          archive,
          "opencode-1.0.1",
          limits: { archive_bytes: File.size(archive) - 1 },
        )
      end
      assert_match(/compressed size limit/, error.message)
    end
  end

  def test_fails_closed_when_copr_is_enabled
    with_release_fixture do |fixture|
      package = YAML.safe_load_file(fixture.fetch(:manifest), aliases: false)
      package.fetch("copr")["enabled"] = true
      File.write(fixture.fetch(:manifest), YAML.dump(package))

      error = assert_raises(RuntimeError) { OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit)) }
      assert_equal("OpenCode COPR package must remain disabled", error.message)
    end
  end

  private

  def with_release_fixture
    Dir.mktmpdir("agentlab-opencode-release-audit-", "/srv/tmp") do |directory|
      repo = File.join(directory, "upstream")
      FileUtils.mkdir_p(File.join(repo, "packages", "opencode"))
      FileUtils.mkdir_p(File.join(repo, "patches"))
      git(repo, "init", "--quiet")
      git(repo, "config", "user.name", "Test")
      git(repo, "config", "user.email", "test@example.invalid")

      write_release(repo, "1.0.0", "old-lock", "old-upstream-patch")
      git(repo, "add", ".")
      git(repo, "commit", "--quiet", "-m", "old release")
      git(repo, "tag", "v1.0.0")
      old_commit = git(repo, "rev-parse", "HEAD")

      write_release(repo, "1.0.1", "new-lock", "new-upstream-patch")
      git(repo, "add", ".")
      git(repo, "commit", "--quiet", "-m", "new release")
      git(repo, "tag", "v1.0.1")
      new_commit = git(repo, "rev-parse", "HEAD")

      package_directory = File.join(directory, "package")
      FileUtils.mkdir_p(package_directory)
      manifest = File.join(package_directory, "package.yml")
      File.write(manifest, YAML.dump({
        "name" => "opencode",
        "status" => "blocked",
        "upstream" => {
          "repository" => "example/opencode",
          "current_version" => "1.0.0",
          "tag_prefix" => "v",
          "source_url_template" => "https://github.com/example/opencode/archive/refs/tags/v{version}.tar.gz",
          "source_tag" => "v1.0.0",
          "source_commit" => old_commit,
          "source_sha256" => "0" * 64,
        },
        "copr" => { "enabled" => false },
      }))
      spec = File.join(package_directory, "opencode.spec")
      File.write(spec, <<~SPEC)
        Patch0: downstream.patch
        %prep
        %autosetup -N
        patch -p1 < %{PATCH0}
      SPEC
      patch = File.join(package_directory, "downstream.patch")
      File.write(patch, "downstream packaging patch\n")
      archive = File.join(directory, "opencode-1.0.1.tar.gz")
      git(repo, "archive", "--format=tar.gz", "--prefix=opencode-1.0.1/", "--output=#{archive}", "v1.0.1")

      yield({
        archive: archive,
        manifest: manifest,
        patch: patch,
        new_commit: new_commit,
        audit: {
          package_manifest: manifest,
          package_spec: spec,
          repo: repo,
          archive: archive,
          latest_version: "1.0.1",
        },
      })
    end
  end

  def git(repo, *arguments)
    output, error, status = Open3.capture3("git", "-C", repo, *arguments)
    raise error unless status.success?

    output.strip
  end

  def write_release(repo, version, lock, upstream_patch)
    File.write(File.join(repo, "bun.lock"), lock)
    File.write(File.join(repo, "package.json"), JSON.generate({ "version" => version }))
    File.write(File.join(repo, "packages", "opencode", "package.json"), JSON.generate({ "version" => version }))
    File.write(File.join(repo, "patches", "dependency.patch"), upstream_patch)
  end

  def write_archive(path, root, members)
    Zlib::GzipWriter.open(path) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        tar.mkdir(root, 0o755)
        directories = Set.new
        members.each do |relative_path, content|
          parent = File.dirname(relative_path)
          unless parent == "." || directories.include?(parent)
            current = ""
            parent.split("/").each do |segment|
              current = current.empty? ? segment : "#{current}/#{segment}"
              next if directories.include?(current)

              tar.mkdir("#{root}/#{current}", 0o755)
              directories << current
            end
          end
          tar.add_file_simple("#{root}/#{relative_path}", 0o644, content.bytesize) { |file| file.write(content) }
        end
      end
    end
  end
end
