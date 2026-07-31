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

      assert_equal("agentlab-opencode-upstream-release-audit/v5", result.fetch("schema"))
      assert_equal(fixture.fetch(:witness_sha256), result.dig("immutable_witness", "sha256"))
      assert_equal(fixture.fetch(:new_commit), result.dig("latest_release", "commit"))
      assert_equal("opencode-1.0.1", result.dig("latest_release", "archive_root"))
      assert(result.dig("latest_release", "archive_matches_commit_tree"))
      assert(result.dig("delta", "release_sensitive_paths", "bun.lock"))
      assert(result.dig("delta", "downstream_patch_revalidation_required"))
      assert(result.dig("delta", "selected_source_evidence_refresh_required"))
      assert_equal(
        [
          ["@modelcontextprotocol/client", "2.0.0-beta.5", nil],
          ["@modelcontextprotocol/server", "2.0.0-beta.5", nil],
          ["@modelcontextprotocol/sdk", nil, "1.29.0"],
        ],
        result.dig("delta", "mcp_dependency_transition").map do |entry|
          [entry.fetch("package"), entry["packaged_requirement"], entry["latest_requirement"]]
        end,
      )
      assert_equal(
        "https://registry.npmjs.org/@modelcontextprotocol/sdk/-/sdk-1.29.0.tgz",
        result.dig("delta", "mcp_dependency_transition", 2, "latest_source", "source_url"),
      )
      assert_equal(
        fixture.fetch(:new_lock_blob),
        result.dig("delta", "release_sensitive_blobs", "bun.lock", "latest"),
      )
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
      assert_empty(receipt_errors(fixture, result))
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

      errors = receipt_errors(fixture, result)
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

      errors = receipt_errors(fixture, result)
      assert_includes(errors, "receipt latest tag is inconsistent")
      assert_includes(errors, "receipt latest archive root is inconsistent")
      assert_includes(errors, "receipt latest commit is invalid")
      assert_includes(errors, "receipt packaging patch inputs mismatch")
    end
  end

  def test_receipt_rejects_incomplete_mcp_source_mapping
    with_release_fixture do |fixture|
      result = OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit))
      result.dig("delta", "mcp_dependency_transition", 2, "latest_source")["integrity"] = nil
      result.dig("delta", "release_sensitive_blobs", "bun.lock")["latest"] = "invalid"

      errors = receipt_errors(fixture, result)
      assert_includes(errors, "receipt MCP dependency source mapping is incomplete")
      assert_includes(errors, "receipt release-sensitive blob mapping is incomplete")
    end
  end

  def test_rejects_valid_looking_short_and_forged_sha512_integrities
    short = "sha512-#{Base64.strict_encode64('short')}"
    forged = "sha512-#{"A" * 85}==="

    error = assert_raises(RuntimeError) do
      OpenCodeUpstreamReleaseAudit.npm_source("@modelcontextprotocol/sdk@1.29.0", short)
    end
    assert_match(/digest length/, error.message)
    error = assert_raises(RuntimeError) do
      OpenCodeUpstreamReleaseAudit.npm_source("@modelcontextprotocol/sdk@1.29.0", forged)
    end
    assert_match(/invalid npm SHA-512 integrity/, error.message)
  end

  def test_generation_rejects_lock_identity_that_does_not_match_manifest_requirement
    with_release_fixture do |fixture|
      lock = File.read(File.join(fixture.fetch(:repo), "bun.lock"))
      lock.sub!("@modelcontextprotocol/sdk@1.29.0", "@modelcontextprotocol/sdk@1.28.0")
      File.write(File.join(fixture.fetch(:repo), "bun.lock"), lock)
      git(fixture.fetch(:repo), "add", "bun.lock")
      git(fixture.fetch(:repo), "commit", "--quiet", "-m", "wrong lock identity")
      git(fixture.fetch(:repo), "tag", "--force", "v1.0.1")

      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.mcp_dependency_transition(fixture.fetch(:repo), "v1.0.0", "v1.0.1")
      end
      assert_match(/lock identity does not match/, error.message)
    end
  end

  def test_generation_ignores_matching_records_outside_bun_packages_map
    with_release_fixture do |fixture|
      integrity = fixture.fetch(:integrities).fetch(:sdk)
      File.write(File.join(fixture.fetch(:repo), "bun.lock"), <<~LOCK)
        {
          "workspaces": {
            "@modelcontextprotocol/sdk": ["@modelcontextprotocol/sdk@1.29.0", "", {}, "#{integrity}"],
          },
          "packages": {
          },
        }
      LOCK
      git(fixture.fetch(:repo), "add", "bun.lock")
      git(fixture.fetch(:repo), "commit", "--quiet", "-m", "misplaced lock source")
      git(fixture.fetch(:repo), "tag", "--force", "v1.0.1")

      error = assert_raises(RuntimeError) do
        OpenCodeUpstreamReleaseAudit.mcp_dependency_transition(fixture.fetch(:repo), "v1.0.0", "v1.0.1")
      end
      assert_match(/missing root lock source/, error.message)
    end
  end

  def test_receipt_rejects_arbitrary_well_formed_blob_ids
    with_release_fixture do |fixture|
      result = OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit))
      result.dig("delta", "release_sensitive_blobs", "bun.lock")["latest"] = "f" * 40

      errors = receipt_errors(fixture, result)
      assert_includes(errors, "receipt release-sensitive blobs do not match immutable witness")
    end
  end

  def test_receipt_rejects_rehashed_witness_tampering
    with_release_fixture do |fixture|
      result = OpenCodeUpstreamReleaseAudit.audit(**fixture.fetch(:audit))
      witness = JSON.parse(File.read(fixture.fetch(:witness)))
      witness.dig("releases", "latest", "release_sensitive_blobs")["bun.lock"] = "f" * 40
      File.write(fixture.fetch(:witness), JSON.pretty_generate(witness) + "\n")
      result.fetch("immutable_witness")["sha256"] = Digest::SHA256.file(fixture.fetch(:witness)).hexdigest

      errors = receipt_errors(fixture, result)
      assert_includes(errors.first, "OpenCode release witness SHA-256 mismatch")
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

      assert_empty(receipt_errors(fixture, result))
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

      write_release(repo, "1.0.0", :packaged, "old-upstream-patch")
      git(repo, "add", ".")
      git(repo, "commit", "--quiet", "-m", "old release")
      git(repo, "tag", "v1.0.0")
      old_commit = git(repo, "rev-parse", "HEAD")

      write_release(repo, "1.0.1", :latest, "new-upstream-patch")
      git(repo, "add", ".")
      git(repo, "commit", "--quiet", "-m", "new release")
      git(repo, "tag", "v1.0.1")
      new_commit = git(repo, "rev-parse", "HEAD")

      integrities = {
        client: integrity("client"),
        server: integrity("server"),
        sdk: integrity("sdk"),
      }

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
      witness = File.join(directory, "upstream-release-witness.json")
      File.write(witness, JSON.pretty_generate({
        "schema" => "agentlab-opencode-upstream-release-witness/v1",
        "repository" => "example/opencode",
        "releases" => {
          "packaged" => release_witness(repo, "1.0.0", old_commit),
          "latest" => release_witness(repo, "1.0.1", new_commit),
        },
        "mcp_dependency_transition" => fixture_transition(integrities),
      }) + "\n")
      witness_sha256 = Digest::SHA256.file(witness).hexdigest

      yield({
        archive: archive,
        repo: repo,
        manifest: manifest,
        patch: patch,
        new_commit: new_commit,
        new_lock_blob: git(repo, "rev-parse", "v1.0.1:bun.lock"),
        witness: witness,
        witness_sha256: witness_sha256,
        integrities: integrities,
        audit: {
          package_manifest: manifest,
          package_spec: spec,
          repo: repo,
          archive: archive,
          latest_version: "1.0.1",
          witness_path: witness,
          expected_witness_sha256: witness_sha256,
        },
      })
    end
  end

  def git(repo, *arguments)
    output, error, status = Open3.capture3("git", "-C", repo, *arguments)
    raise error unless status.success?

    output.strip
  end

  def write_release(repo, version, release, upstream_patch)
    packaged = release == :packaged
    lock_records = if packaged
                     <<~LOCK
                       {
                         "packages": {
                           "@modelcontextprotocol/client": ["@modelcontextprotocol/client@2.0.0-beta.5", "", {}, "#{integrity("client")}"],
                           "@modelcontextprotocol/server": ["@modelcontextprotocol/server@2.0.0-beta.5", "", {}, "#{integrity("server")}"],
                         },
                       }
                     LOCK
                   else
                     <<~LOCK
                       {
                         "packages": {
                           "@modelcontextprotocol/sdk": ["@modelcontextprotocol/sdk@1.29.0", "", {}, "#{integrity("sdk")}"],
                         },
                       }
                     LOCK
                   end
    dependencies = packaged ? { "@modelcontextprotocol/client" => "2.0.0-beta.5" } : { "@modelcontextprotocol/sdk" => "1.29.0" }
    dev_dependencies = packaged ? { "@modelcontextprotocol/server" => "2.0.0-beta.5" } : {}
    File.write(File.join(repo, "bun.lock"), lock_records)
    File.write(File.join(repo, "package.json"), JSON.generate({ "version" => version }))
    File.write(File.join(repo, "packages", "opencode", "package.json"), JSON.generate({
      "version" => version,
      "dependencies" => dependencies,
      "devDependencies" => dev_dependencies,
    }))
    File.write(File.join(repo, "patches", "dependency.patch"), upstream_patch)
  end

  def receipt_errors(fixture, receipt)
    OpenCodeUpstreamReleaseAudit.receipt_errors(
      package_manifest: fixture.fetch(:manifest),
      package_spec: fixture.dig(:audit, :package_spec),
      receipt: receipt,
      witness_path: fixture.fetch(:witness),
      expected_witness_sha256: fixture.fetch(:witness_sha256),
    )
  end

  def integrity(value)
    "sha512-#{Base64.strict_encode64(Digest::SHA512.digest(value))}"
  end

  def release_witness(repo, version, commit)
    tag = "v#{version}"
    {
      "version" => version,
      "tag" => tag,
      "commit" => commit,
      "release_sensitive_blobs" => OpenCodeUpstreamReleaseAudit::RELEASE_SENSITIVE_PATHS.to_h do |path|
        [path, git(repo, "rev-parse", "#{tag}:#{path}")]
      end,
    }
  end

  def fixture_transition(integrities)
    [
      fixture_transition_entry("@modelcontextprotocol/client", "2.0.0-beta.5", nil, integrities.fetch(:client), nil),
      fixture_transition_entry("@modelcontextprotocol/server", "2.0.0-beta.5", nil, integrities.fetch(:server), nil),
      fixture_transition_entry("@modelcontextprotocol/sdk", nil, "1.29.0", nil, integrities.fetch(:sdk)),
    ]
  end

  def fixture_transition_entry(package, packaged_requirement, latest_requirement, packaged_integrity, latest_integrity)
    {
      "package" => package,
      "packaged_requirement" => packaged_requirement,
      "latest_requirement" => latest_requirement,
      "packaged_source" => packaged_requirement && fixture_source(package, packaged_requirement, packaged_integrity),
      "latest_source" => latest_requirement && fixture_source(package, latest_requirement, latest_integrity),
    }
  end

  def fixture_source(package, requirement, integrity_value)
    basename = package.split("/").last
    {
      "identity" => "#{package}@#{requirement}",
      "integrity" => integrity_value,
      "source_url" => "https://registry.npmjs.org/#{package}/-/#{basename}-#{requirement}.tgz",
    }
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
