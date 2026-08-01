# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"

load File.expand_path("../scripts/audit-bun-codegen-reexecution", __dir__) unless defined?(BunCodegenReexecutionAudit)

class BunCodegenReexecutionAuditTest < Minitest::Test
  def setup
    @receipt = JSON.parse(File.read(File.expand_path("../packages/bun/bun-1.3.14-codegen-reexecution-proof.json", __dir__)))
  end

  def test_accepts_the_checked_proof
    assert(BunCodegenReexecutionAudit.validate!(@receipt))
  end

  def test_rejects_input_output_and_completion_drift
    mutations = [
      ->(receipt) { receipt.dig("inputs", "source_built_driver")["sha256"] = "0" * 64 },
      ->(receipt) { receipt.dig("inputs", "build_ninja")["path"] = "wrong.ninja" },
      ->(receipt) { receipt.dig("inputs", "configure_proof")["path"] = "wrong.json" },
      ->(receipt) { receipt.dig("inputs", "source_built_driver")["execution_path"] = "/bin/false" },
      ->(receipt) { receipt.dig("inputs", "lol_html_provider_rpm")["path"] = "wrong.rpm" },
      ->(receipt) { receipt.fetch("runs").first.fetch("commands").first.fetch("argv")[6] = "/bin/false" },
      ->(receipt) { receipt.fetch("runs").first["source_tree_entry_count"] += 1 },
      ->(receipt) { receipt.fetch("runs").first["source_tree_sha256"] = "0" * 64 },
      ->(receipt) { receipt.dig("expected", "codegen_outputs", 0)["sha256"] = "0" * 64 },
      ->(receipt) { receipt.fetch("runs").first["network_isolated"] = false },
      ->(receipt) { receipt.dig("validation")["generated_output_producer_edges_verified"] = true }
    ]

    mutations.each do |mutation|
      receipt = Marshal.load(Marshal.dump(@receipt))
      mutation.call(receipt)
      assert_raises(BunCodegenReexecutionAudit::Error) { BunCodegenReexecutionAudit.validate!(receipt) }
    end
  end

  def test_requires_exact_tree_entry_count_and_false_completion_flags
    receipt = Marshal.load(Marshal.dump(@receipt))
    receipt.fetch("expected")["codegen_tree_entry_count"] += 1
    error = assert_raises(BunCodegenReexecutionAudit::Error) do
      BunCodegenReexecutionAudit.validate!(receipt)
    end
    assert_includes(error.message, "expected output inventory mismatch")

    %w[
      generated_output_producer_edges_verified
      final_npm_codegen_closure_verified
    ].each do |key|
      receipt = Marshal.load(Marshal.dump(@receipt))
      receipt.fetch("validation")[key] = true
      assert_raises(BunCodegenReexecutionAudit::Error) { BunCodegenReexecutionAudit.validate!(receipt) }
    end
  end

  def test_tree_identity_binds_regular_file_modes
    Dir.mktmpdir do |directory|
      path = File.join(directory, "generator")
      File.write(path, "#!/bin/sh\n")
      File.chmod(0o644, path)
      before = BunCodegenReexecutionAudit.tree_content_identity(directory)

      File.chmod(0o755, path)

      refute_equal(before, BunCodegenReexecutionAudit.tree_content_identity(directory))
    end
  end

  def test_tree_identity_binds_directory_modes
    Dir.mktmpdir do |directory|
      path = File.join(directory, "generated")
      Dir.mkdir(path, 0o755)
      before = BunCodegenReexecutionAudit.tree_content_identity(directory)

      File.chmod(0o700, path)

      refute_equal(before, BunCodegenReexecutionAudit.tree_content_identity(directory))
    end
  end

  def test_workspace_roots_reject_symlinks
    Dir.mktmpdir do |directory|
      run_root = File.join(directory, "run1")
      outside = File.join(directory, "outside")
      Dir.mkdir(run_root)
      Dir.mkdir(outside)

      %w[source codegen].each do |name|
        path = File.join(run_root, name)
        File.symlink(outside, path)
        error = assert_raises(BunCodegenReexecutionAudit::Error) do
          BunCodegenReexecutionAudit.verify_directory_path!(path, anchor: run_root, label: "#{name} root")
        end
        assert_includes(error.message, "symlink")
        File.unlink(path)
      end
    end
  end

  def test_tree_identity_rejects_unsupported_entries
    Dir.mktmpdir do |directory|
      File.mkfifo(File.join(directory, "unexpected.fifo"))

      error = assert_raises(BunCodegenReexecutionAudit::Error) do
        BunCodegenReexecutionAudit.tree_content_identity(directory)
      end
      assert_includes(error.message, "unsupported filesystem entry")
    end
  end
end
