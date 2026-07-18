# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "../scripts/lib/bun_webkit_source"

class BunWebKitSourceTest < Minitest::Test
  SCRIPT = File.expand_path("../scripts/package-bun-webkit-source", __dir__)
  COMMIT = "a" * 40
  RELEASE_PIN = "bun-v1.2.3"

  def test_packages_a_deterministic_reduced_source_tree_and_verifies_its_receipt
    Dir.mktmpdir("agentlab-webkit-source-test-", "/srv/tmp") do |temporary|
      complete = File.join(temporary, "complete")
      root = File.join(complete, "WebKit-#{COMMIT}")
      create_fixture_tree(root)
      source = File.join(temporary, "complete.tar.gz")
      create_archive(complete, "WebKit-#{COMMIT}", source)
      canonical_sha256 = Digest::SHA256.file(source).hexdigest

      results = 2.times.map do |index|
        directory = File.join(temporary, "run-#{index}")
        output = File.join(directory, "minimized.tar.gz")
        receipt = File.join(directory, "receipt.json")
        workdir = File.join(directory, "work")
        FileUtils.mkdir_p(workdir)
        result = Agentlab::BunWebKitSource.package!(
          source_archive: source,
          output: output,
          receipt_path: receipt,
          workdir: workdir,
          commit: COMMIT,
          release_pin: RELEASE_PIN,
          canonical_sha256: canonical_sha256
        )
        [result, output, receipt]
      end

      assert_equal(Digest::SHA256.file(results[0][1]).hexdigest, Digest::SHA256.file(results[1][1]).hexdigest)
      assert_equal(File.binread(results[0][2]), File.binread(results[1][2]))
      assert_operator(File.size(results[0][1]), :<, File.size(source))

      entries = capture!("tar", "--list", "--gzip", "--file", results[0][1]).lines.map(&:strip)
      assert_includes(entries, "WebKit-#{COMMIT}/Source/JavaScriptCore/CMakeLists.txt")
      assert_includes(entries, "WebKit-#{COMMIT}/Source/ThirdParty/capstone/CMakeLists.txt")
      refute(entries.any? { |entry| entry.start_with?("WebKit-#{COMMIT}/LayoutTests/") })
      refute(entries.any? { |entry| entry.start_with?("WebKit-#{COMMIT}/Source/WebCore/") })

      extracted = File.join(temporary, "extracted")
      FileUtils.mkdir_p(extracted)
      system("tar", "--extract", "--gzip", "--file", results[0][1], "--directory", extracted) || flunk("cannot extract fixture archive")
      extracted_root = File.join(extracted, "WebKit-#{COMMIT}")
      assert(File.executable?(File.join(extracted_root, "Tools", "Scripts", "rewrite-compile-commands")))
      assert_equal(0o644, File.stat(File.join(extracted_root, "CMakeLists.txt")).mode & 0o777)
      assert_equal(0o755, File.stat(File.join(extracted_root, "Tools", "Scripts", "rewrite-compile-commands")).mode & 0o777)
      assert_equal("../CMakeLists.txt", File.readlink(File.join(extracted_root, "Tools", "root-cmake")))

      metadata = { "commit" => COMMIT, "sha256" => canonical_sha256 }
      verified = Agentlab::BunWebKitSource.verify_receipt!(
        receipt_path: results[0][2],
        archive_path: results[0][1],
        webkit_metadata: metadata,
        release_pin: RELEASE_PIN
      )
      assert_equal(true, verified.dig("validation", "deterministic_regeneration_verified"))
      assert_equal(true, verified.dig("validation", "aarch64_capstone_scope_verified"))
      assert_equal(%w[x86_64 aarch64], verified.dig("retained_scope", "architectures"))
      assert_equal(true, verified.dig("retained_scope", "capstone_retained"))
      assert_equal(false, verified.dig("validation", "source_tree_complete"))
      assert_operator(verified.dig("archive", "saved_bytes"), :>, 0)
      assert_equal(
        verified.dig("archive", "tree_sha256"),
        Agentlab::BunWebKitSource.verify_tree!(staging: extracted, receipt: verified).fetch("tree_sha256")
      )

      tampered = JSON.parse(File.read(results[0][2]))
      tampered["archive"]["tree_sha256"] = "0" * 64
      error = assert_raises(Agentlab::Error) do
        Agentlab::BunWebKitSource.verify_tree!(staging: extracted, receipt: tampered)
      end
      assert_includes(error.message, "does not match its receipt")

      File.write(File.join(extracted_root, "CMakeLists.txt"), "tampered\n")
      restored = Agentlab::BunWebKitSource.extract_verified_tree!(
        archive_path: results[0][1],
        staging: extracted,
        receipt: verified
      )
      assert_equal(verified.dig("archive", "tree_sha256"), restored.fetch("tree_sha256"))
      assert_equal("fixture CMakeLists.txt\n", File.read(File.join(extracted_root, "CMakeLists.txt")))

      tampered_scope = JSON.parse(File.read(results[0][2]))
      tampered_scope.fetch("retained_scope")["architectures"] = ["x86_64"]
      tampered_receipt = File.join(temporary, "tampered-scope.json")
      File.write(tampered_receipt, JSON.pretty_generate(tampered_scope) + "\n")
      error = assert_raises(Agentlab::Error) do
        Agentlab::BunWebKitSource.verify_receipt!(
          receipt_path: tampered_receipt,
          archive_path: results[0][1],
          webkit_metadata: metadata,
          release_pin: RELEASE_PIN
        )
      end
      assert_includes(error.message, "source scope does not match")
    end
  end

  def test_requires_capstone_for_the_dual_architecture_source_profile
    Dir.mktmpdir("agentlab-webkit-capstone-test-", "/srv/tmp") do |temporary|
      complete = File.join(temporary, "complete")
      root = File.join(complete, "WebKit-#{COMMIT}")
      create_fixture_tree(root)
      FileUtils.rm_f(File.join(root, "Source", "ThirdParty", "capstone", "CMakeLists.txt"))
      source = File.join(temporary, "complete.tar.gz")
      create_archive(complete, "WebKit-#{COMMIT}", source)

      error = assert_raises(Agentlab::Error) do
        Agentlab::BunWebKitSource.package!(
          source_archive: source,
          output: File.join(temporary, "minimized.tar.gz"),
          receipt_path: File.join(temporary, "receipt.json"),
          workdir: File.join(temporary, "work"),
          commit: COMMIT,
          release_pin: RELEASE_PIN,
          canonical_sha256: Digest::SHA256.file(source).hexdigest
        )
      end
      assert_includes(error.message, "missing Source/ThirdParty/capstone/CMakeLists.txt")
    end
  end

  def test_rejects_colliding_source_output_and_receipt_paths_before_packaging
    Dir.mktmpdir("agentlab-webkit-collision-test-", "/srv/tmp") do |temporary|
      source = File.join(temporary, "source.tar.gz")
      File.write(source, "fixture")
      workdir = File.join(temporary, "work")

      stdout, stderr, status = Open3.capture3(
        SCRIPT,
        "--source", source,
        "--output", source,
        "--receipt", File.join(temporary, "receipt.json"),
        "--workdir", workdir,
        "--force"
      )
      refute(status.success?, stdout)
      assert_includes(stderr, "source, output, and receipt paths must be distinct")
      assert_equal("fixture", File.read(source))

      shared = File.join(temporary, "shared")
      _stdout, stderr, status = Open3.capture3(
        SCRIPT,
        "--source", source,
        "--output", shared,
        "--receipt", shared,
        "--workdir", workdir,
        "--force"
      )
      refute(status.success?)
      assert_includes(stderr, "source, output, and receipt paths must be distinct")

      canonical = File.join(temporary, "canonical.tar.gz")
      source_link = File.join(temporary, "source-link.tar.gz")
      File.write(canonical, "canonical")
      File.symlink(canonical, source_link)
      _stdout, stderr, status = Open3.capture3(
        SCRIPT,
        "--source", source_link,
        "--output", canonical,
        "--receipt", File.join(temporary, "alias-receipt.json"),
        "--workdir", workdir,
        "--force"
      )
      refute(status.success?)
      assert_includes(stderr, "source, output, and receipt paths must be distinct")
      assert_equal("canonical", File.read(canonical))

      escaped_name = "agentlab-webkit-escaped-output-#{Process.pid}.tar.gz"
      escaped_target = File.join(Agentlab::ROOT, escaped_name)
      escaped_parent = File.join(temporary, "escaped-parent")
      File.symlink(Agentlab::ROOT, escaped_parent)
      _stdout, stderr, status = Open3.capture3(
        SCRIPT,
        "--source", source,
        "--output", File.join(escaped_parent, escaped_name),
        "--receipt", File.join(temporary, "escaped-receipt.json"),
        "--workdir", workdir,
        "--force"
      )
      refute(status.success?)
      assert_includes(stderr, "output path must resolve below /srv/tmp")
      refute(File.exist?(escaped_target))

      dangling_output = File.join(temporary, "dangling-output.tar.gz")
      File.symlink(File.join(Agentlab::ROOT, "missing-webkit-output-#{Process.pid}.tar.gz"), dangling_output)
      _stdout, stderr, status = Open3.capture3(
        SCRIPT,
        "--source", source,
        "--output", dangling_output,
        "--receipt", File.join(temporary, "normal-receipt.json"),
        "--workdir", workdir
      )
      refute(status.success?)
      assert_includes(stderr, "refusing symlinked output path")

      dangling_receipt = File.join(temporary, "dangling-receipt.json")
      File.symlink(File.join(Agentlab::ROOT, "missing-webkit-receipt-#{Process.pid}.json"), dangling_receipt)
      _stdout, stderr, status = Open3.capture3(
        SCRIPT,
        "--source", source,
        "--output", File.join(temporary, "normal-output.tar.gz"),
        "--receipt", dangling_receipt,
        "--workdir", workdir
      )
      refute(status.success?)
      assert_includes(stderr, "refusing symlinked receipt path")
    end
  end

  private

  def create_fixture_tree(root)
    required = Agentlab::BunWebKitSource::REQUIRED_PATHS
    required.each do |relative|
      path = File.join(root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "fixture #{relative}\n")
    end
    File.chmod(0o755, File.join(root, "Tools", "Scripts", "rewrite-compile-commands"))
    File.symlink("../CMakeLists.txt", File.join(root, "Tools", "root-cmake"))

    %w[LayoutTests Source/WebCore Source/ThirdParty/ANGLE Websites].each do |relative|
      path = File.join(root, relative)
      FileUtils.mkdir_p(path)
      File.binwrite(File.join(path, "discarded.bin"), "x" * 65_536)
    end
  end

  def create_archive(parent, root, output)
    File.open(output, "wb") do |file|
      statuses = Open3.pipeline(
        ["tar", "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner", "--format=gnu", "--create", "--file=-", "--directory", parent, root],
        ["gzip", "-n", "-9"],
        out: file
      )
      assert(statuses.all?(&:success?))
    end
  end

  def capture!(*argv)
    stdout, stderr, status = Open3.capture3(*argv)
    assert(status.success?, stderr)
    stdout
  end
end
