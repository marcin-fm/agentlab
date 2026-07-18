# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"

class AuditBunRelinkMaterialsTest < Minitest::Test
  SCRIPT = File.expand_path("../scripts/audit-bun-relink-materials", __dir__)

  def write(path, content = "fixture\n")
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
  end

  def run_script(*arguments)
    stdout, stderr, status = Open3.capture3(SCRIPT, *arguments)
    assert(status.success?, stderr)
    stdout
  end

  def build_fixture(root)
    build_root = File.join(root, "build", "release-local")
    zig_objects = 32.times.map { |index| "bun-zig.#{index}.o" }
    tinycc_objects = 10.times.map { |index| "obj/vendor/tinycc/tinycc-#{index}.o" }
    generic_objects = 1120.times.map { |index| "obj/generic/generic-#{index}.o" }
    objects = zig_objects + tinycc_objects + generic_objects
    archives = %w[
      deps/lolhtml/release/liblolhtml.a
      deps/WebKit/lib/libWTF.a
      deps/WebKit/lib/libJavaScriptCore.a
      deps/WebKit/lib/libbmalloc.a
    ]
    inputs = objects + archives
    inputs.each { |relative| write(File.join(build_root, relative), "#{relative}\n") }

    write(File.join(root, "source", "src", "symbols.dyn"), "{ global: *; };\n")
    write(File.join(root, "source", "src", "linker.lds"), "SECTIONS {}\n")
    write(File.join(root, "source", "LICENSE.md"), "JavaScriptCore is available under LGPL-2.\n")
    write(File.join(root, "source", "vendor", "tinycc", "COPYING"), "LESSER GENERAL PUBLIC LICENSE\nVersion 2.1\n")
    write(File.join(root, "source", "package.json"), JSON.generate("name" => "bun", "version" => "1.3.14"))
    write(File.join(root, "seed", "bun"), "bootstrap seed\n")
    write(File.join(build_root, "bun-profile"), "retained profile\n")
    write(File.join(build_root, "bun-profile.linker-map"))
    write(File.join(build_root, "compile_commands.json"), "[]\n")
    write(File.join(build_root, "configure.json"), "{}\n")

    header_specs = {
      "deps/WebKit/JavaScriptCore/Headers" => 9,
      "deps/WebKit/JavaScriptCore/PrivateHeaders" => 1415,
      "deps/WebKit/WTF/Headers" => 510,
      "deps/WebKit/bmalloc/Headers" => 360
    }
    target = File.join(root, "webkit", "WebKit-fixture", "Source", "Target.h")
    write(target, "#pragma once\n")
    header_specs.each_with_index do |(relative, count), tree_index|
      directory = File.join(build_root, relative)
      FileUtils.mkdir_p(directory)
      count.times do |index|
        path = File.join(directory, format("header-%04d.h", index))
        if tree_index.zero? && index.zero?
          File.symlink(Pathname(target).relative_path_from(Pathname(File.dirname(path))).to_s, path)
        elsif tree_index.zero? && index == 1
          File.symlink("header-0002.h", path)
        else
          write(path, "#{relative} #{index}\n")
        end
      end
    end

    ninja = <<~NINJA
      rule link
        command = #{root}/seed/bun #{root}/source/scripts/build/stream.ts link --console /usr/lib64/llvm21/bin/clang++ @$out.rsp $ldflags -o $out
        rspfile = $out.rsp
        rspfile_content = $in_newline

      build bun-profile: link #{inputs.join(' ')} | ../../source/src/symbols.dyn ../../source/src/linker.lds
        ldflags = -Wl,-Map=#{root}/build/release-local/bun-profile.linker-map -Wl,--dynamic-list=#{root}/source/src/symbols.dyn -Wl,--version-script=#{root}/source/src/linker.lds -lstdc++ -lgcc_s -lc -lpthread -ldl -l:libatomic.a -licudata -licui18n -licuuc
    NINJA
    write(File.join(build_root, "build.ninja"), ninja)
    inputs
  end

  def test_materializes_a_deterministic_wrapper_free_relink_kit
    Dir.mktmpdir("agentlab-bun-relink-", "/srv/tmp") do |temporary|
      root = File.join(temporary, "proof")
      inputs = build_fixture(root)
      output_dir = File.join(temporary, "output")
      audit_path = File.join(temporary, "audit.json")
      arguments = [
        "--root", root,
        "--date", "2026-07-18",
        "--output", audit_path,
        "--kit-output-dir", output_dir
      ]

      run_script(*arguments)
      kit_name = "bun-1.3.14-relink-kit"
      kit_root = File.join(output_dir, kit_name)
      archive = File.join(output_dir, "#{kit_name}.tar.zst")
      receipt_path = File.join(output_dir, "#{kit_name}-receipt.json")
      first_archive_sha256 = Digest::SHA256.file(archive).hexdigest
      first_receipt = File.binread(receipt_path)

      command = JSON.parse(File.read(File.join(kit_root, "relink", "link-command.json")))
      assert_equal("/usr/lib64/llvm21/bin/clang++", command.fetch("argv").first)
      assert(command.fetch("bootstrap_wrapper_removed"))
      assert(command.fetch("proof_root_paths_removed_from_argv"))
      refute_includes(JSON.generate(command), root)
      assert_equal(inputs, File.readlines(File.join(kit_root, "relink", "bun-profile.rsp"), chomp: true))

      manifest = JSON.parse(File.read(File.join(kit_root, "relink", "payload-manifest.json")))
      assert_equal(1162, manifest.dig("summary", "object_count"))
      assert_equal(4, manifest.dig("summary", "archive_count"))
      assert_equal(2294, manifest.dig("summary", "generated_header_entry_count"))
      assert_equal(2, manifest.dig("summary", "generated_header_target_count"))
      assert_equal(1166, manifest.dig("summary", "response_file_input_count"))
      symlink = manifest.fetch("entries").find { |entry| entry["kind"] == "symlink" }
      refute_nil(symlink)
      assert(File.file?(File.realpath(File.join(kit_root, symlink.fetch("path")))))

      receipt = JSON.parse(first_receipt)
      assert_equal("bun-relink-kit/v1", receipt.fetch("schema"))
      assert(receipt.dig("validation", "archive_generated"))
      assert(receipt.dig("validation", "response_file_reconstructed"))
      refute(receipt.dig("validation", "network_isolated_link_verified"))
      refute(receipt.fetch("complete_lgpl_relink_materials_verified"))

      listing, listing_error, listing_status = Open3.capture3("tar", "-tf", archive)
      assert(listing_status.success?, listing_error)
      assert(listing.lines.all? { |line| line.start_with?("#{kit_name}/") })

      audit_alias = File.join(temporary, "audit-alias.json")
      File.symlink(archive, audit_alias)
      _stdout, collision_error, collision_status = Open3.capture3(
        SCRIPT,
        "--root", root,
        "--date", "2026-07-18",
        "--output", audit_alias,
        "--kit-output-dir", output_dir,
        "--force"
      )
      refute(collision_status.success?)
      assert_includes(collision_error, "--output collides with generated relink-kit outputs")
      assert_equal(first_archive_sha256, Digest::SHA256.file(archive).hexdigest)

      real_parent = File.join(temporary, "real-parent")
      alias_parent = File.join(temporary, "alias-parent")
      FileUtils.mkdir_p(real_parent)
      File.symlink(real_parent, alias_parent)
      future_output = File.join(real_parent, "future-output")
      future_archive_alias = File.join(alias_parent, "future-output", "#{kit_name}.tar.zst")
      _stdout, ancestor_error, ancestor_status = Open3.capture3(
        SCRIPT,
        "--root", root,
        "--date", "2026-07-18",
        "--output", future_archive_alias,
        "--kit-output-dir", future_output
      )
      refute(ancestor_status.success?)
      assert_includes(ancestor_error, "--output collides with generated relink-kit outputs")
      refute(Dir.exist?(future_output))

      run_script(*arguments, "--force")
      assert_equal(first_archive_sha256, Digest::SHA256.file(archive).hexdigest)
      assert_equal(first_receipt, File.binread(receipt_path))

      ninja_path = File.join(root, "build", "release-local", "build.ninja")
      write(ninja_path, File.read(ninja_path).sub("rspfile_content = $in_newline", "rspfile_content = $in"))
      _stdout, semantics_error, semantics_status = Open3.capture3(
        SCRIPT,
        "--root", root,
        "--date", "2026-07-18",
        "--output", File.join(temporary, "invalid-audit.json"),
        "--kit-output-dir", File.join(temporary, "invalid-output")
      )
      refute(semantics_status.success?)
      assert_includes(semantics_error, "link rule does not retain $in_newline response-file semantics")
    end
  end
end
