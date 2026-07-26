# frozen_string_literal: true

require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "tmpdir"

module Agentlab
  module OpenChamberLicenses
    SCHEMA = "openchamber-source-license-inventory/v2"
    SOURCE_SCHEMA = "openchamber-source-acquisition/v1"
    SHA256 = /\A[0-9a-f]{64}\z/
    ARCHIVE_NAME = /\Asha512-[0-9a-f]{128}\.tgz\z/
    LICENSE_BASENAME = /\A(?:licen[cs]e|copying|notice|copyright)(?:[._-].*)?\z/i
    SPDX_IDENTIFIERS = %w[
      0BSD AFL-2.1 AFL-3.0 Apache-1.1 Apache-2.0 Artistic-2.0 BlueOak-1.0.0
      BSD-2-Clause BSD-3-Clause BSD-4-Clause BSL-1.0 CC-BY-4.0 CC0-1.0 CDDL-1.0
      EPL-1.0 EPL-2.0 GPL-2.0-only GPL-2.0-or-later GPL-3.0-only GPL-3.0-or-later
      ICU ISC LGPL-2.1-only LGPL-2.1-or-later LGPL-3.0-only LGPL-3.0-or-later
      MIT MIT-0 MPL-1.1 MPL-2.0 MS-PL NCSA OFL-1.1 OpenSSL PHP-3.0
      PostgreSQL Python-2.0 Ruby UPL-1.0 Unlicense Unicode-DFS-2016
      WTFPL X11 Zlib
    ].freeze
    FEDORA_LICENSE_DATA = "/usr/share/fedora-license-data/licenses/fedora-licenses.json"
    NORMALIZED_LICENSES = {
      ["qrcode-terminal", "0.12.0"] => "Apache-2.0",
      ["@pierre/diffs", "1.3.0-beta.6"] => "Apache-2.0",
      ["@pierre/theming", "0.0.2"] => "Apache-2.0"
    }.freeze

    module_function

    def audit!(selected_lock_path:, expected_selected_lock_sha256:, source_audit_path:,
               expected_source_audit_sha256:, cache_dir:, receipt_path:, workdir:,
               fedora_license_data_path: FEDORA_LICENSE_DATA, check: false)
      selected_lock_path = File.expand_path(selected_lock_path)
      source_audit_path = File.expand_path(source_audit_path)
      cache_dir = File.realpath(cache_dir)
      receipt_path = File.expand_path(receipt_path)
      workdir = File.expand_path(workdir)
      raise Agentlab::Error, "OpenChamber source-license workdir must be below /srv/tmp" unless workdir.start_with?("/srv/tmp/")
      FileUtils.mkdir_p(workdir)
      selected_sha256 = checked_sha256!(selected_lock_path, expected_selected_lock_sha256, "selected-lock receipt")
      source_sha256 = checked_sha256!(source_audit_path, expected_source_audit_sha256, "source-audit receipt")
      selected = JSON.parse(File.binread(selected_lock_path))
      source_audit = JSON.parse(File.binread(source_audit_path))
      validate_inputs!(selected, source_audit, selected_sha256)

      archives = source_audit.fetch("sources").map do |source|
        inspect_archive!(source, cache_dir, workdir)
      end.sort_by { |record| record.fetch("archive") }
      findings = findings_for(archives)
      review = review_for!(archives, fedora_license_data_path)
      receipt = {
        "schema" => SCHEMA,
        "package" => "openchamber",
        "release" => source_audit.fetch("release"),
        "selected_lock" => {
          "filename" => File.basename(selected_lock_path),
          "sha256" => selected_sha256,
          "selected_package_records" => selected.dig("selection", "selected_packages")
        },
        "source_audit" => {
          "filename" => File.basename(source_audit_path),
          "sha256" => source_sha256,
          "unique_archives" => source_audit.dig("summary", "unique_sources")
        },
        "summary" => {
          "selected_package_records" => selected.dig("selection", "selected_packages"),
          "unique_archives" => archives.length,
          "license_file_count" => archives.sum { |record| record.fetch("license_files").length },
          "sources_without_declared_license" => findings.fetch("missing_declared_license").length,
          "sources_without_license_files" => findings.fetch("missing_license_files").length,
          "ambiguous_declared_license_sources" => findings.fetch("ambiguous_declared_license").length,
          "non_spdx_declared_license_sources" => findings.fetch("non_spdx_declared_license").length
        },
        "archives" => archives,
        "findings" => findings,
        "review" => review,
        "validation" => {
          "selected_lock_binding_verified" => true,
          "source_audit_binding_verified" => true,
          "archive_identity_verified" => true,
          "package_manifest_license_recorded" => true,
          "package_local_license_texts_hashed" => true,
          "missing_evidence_isolated" => true,
          "ambiguous_evidence_isolated" => true,
          "non_spdx_evidence_isolated" => true,
          "safe_license_normalizations_verified" => true,
          "fedora_license_policy_verified" => true,
          "aggregate_license_expression_verified" => false,
          "rpm_license_payload_complete" => false,
          "generated_asset_licenses_verified" => false,
          "binary_inclusion_verified" => false,
          "bundled_provides_verified" => false,
          "offline_build_verified" => false,
          "package_enabled" => false,
          "copr_enabled" => false
        }
      }
      content = JSON.pretty_generate(receipt) + "\n"
      if check
        raise Agentlab::Error, "missing checked OpenChamber source-license receipt #{receipt_path}" unless File.file?(receipt_path)
        raise Agentlab::Error, "checked OpenChamber source-license receipt is stale" unless File.binread(receipt_path) == content
      else
        Agentlab.atomic_write(receipt_path, content)
      end
      receipt
    rescue JSON::ParserError => e
      raise Agentlab::Error, "invalid OpenChamber source-license input: #{e.message}"
    rescue Errno::ENOENT => e
      raise Agentlab::Error, "missing OpenChamber source-license input: #{e.message}"
    end

    def inspect_archive!(source, cache_dir, workdir)
      archive = source.fetch("archive")
      raise Agentlab::Error, "invalid OpenChamber source-license archive identity" unless archive.match?(ARCHIVE_NAME)

      path = File.join(cache_dir, archive)
      raise Agentlab::Error, "missing checked OpenChamber source archive #{path}" unless File.file?(path)
      expected_sha512 = archive.delete_prefix("sha512-").delete_suffix(".tgz")
      raise Agentlab::Error, "OpenChamber source archive SHA-512 identity mismatch: #{archive}" unless Digest::SHA512.file(path).hexdigest == expected_sha512
      raise Agentlab::Error, "OpenChamber source archive size mismatch: #{archive}" unless File.size(path) == source.fetch("size")
      raise Agentlab::Error, "OpenChamber source archive SHA-256 mismatch: #{archive}" unless Digest::SHA256.file(path).hexdigest == source.fetch("sha256")

      package_json = nil
      license_files = []
      Dir.mktmpdir("openchamber-license-", workdir) do |scan_root|
        _output, error, status = Open3.capture3(
          "tar", "-xzf", path, "-C", scan_root,
          "--no-same-owner", "--no-same-permissions", "--delay-directory-restore"
        )
        raise Agentlab::Error, "cannot extract OpenChamber source archive #{archive}: #{error.strip}" unless status.success?

        Find.find(scan_root) do |entry|
          next if entry == scan_root || File.directory?(entry) || File.symlink?(entry)
          next unless File.file?(entry)

          entry_path = entry.delete_prefix("#{scan_root}/")
          if entry_path == source.fetch("package_json")
            package_json = JSON.parse(File.binread(entry))
          elsif File.basename(entry_path).match?(LICENSE_BASENAME)
            bytes = File.binread(entry)
            license_files << { "path" => entry_path, "sha256" => Digest::SHA256.hexdigest(bytes), "size" => bytes.bytesize }
          end
        end
      end
      raise Agentlab::Error, "OpenChamber source package manifest is absent: #{archive}" unless package_json
      unless package_json["name"] == source.fetch("npm_name") && package_json["version"].to_s == source.fetch("version")
        raise Agentlab::Error, "OpenChamber source package identity mismatch: #{archive}"
      end

      declared_license = package_json.key?("license") ? package_json["license"] : package_json["licenses"]
      record = {
        "archive" => archive,
        "sha256" => source.fetch("sha256"),
        "size" => source.fetch("size"),
        "npm_name" => source.fetch("npm_name"),
        "version" => source.fetch("version"),
        "package_paths" => source.fetch("package_paths"),
        "roles" => source.fetch("roles"),
        "package_json" => source.fetch("package_json"),
        "declared_license" => declared_license,
        "license_files" => license_files.sort_by { |file| file.fetch("path") }
      }
      unless record["declared_license"] == source["declared_license"] && record["license_files"] == source.fetch("license_files")
        raise Agentlab::Error, "OpenChamber source-license evidence differs from source audit: #{archive}"
      end
      record
    end

    def findings_for(archives)
      finding = lambda do |record|
        {
          "archive" => record.fetch("archive"),
          "npm_name" => record.fetch("npm_name"),
          "version" => record.fetch("version"),
          "declared_license" => record["declared_license"]
        }
      end
      {
        "missing_declared_license" => archives.select { |record| missing_license?(record["declared_license"]) }.map(&finding),
        "missing_license_files" => archives.select { |record| record.fetch("license_files").empty? }.map(&finding),
        "ambiguous_declared_license" => archives.select { |record| ambiguous_license?(record["declared_license"]) }.map(&finding),
        "non_spdx_declared_license" => archives.select { |record| non_spdx_license?(record["declared_license"]) }.map(&finding)
      }
    end

    def review_for!(archives, fedora_license_data_path)
      normalized = NORMALIZED_LICENSES.map do |(name, version), expression|
        archive = archives.find { |record| record["npm_name"] == name && record["version"] == version }
        next unless archive

        {
          "archive" => archive.fetch("archive"),
          "npm_name" => name,
          "version" => version,
          "declared_license" => archive["declared_license"],
          "normalized_expression" => expression,
          "license_files" => archive.fetch("license_files")
        }
      end.compact.sort_by { |record| [record.fetch("npm_name"), record.fetch("version")] }

      remix = archives.find { |record| record["npm_name"] == "@remixicon/react" && record["version"] == "4.9.0" }
      fedora_path = File.expand_path(fedora_license_data_path)
      entry = nil
      if remix
        fedora = JSON.parse(File.binread(fedora_path))
        entry = fedora.values.map { |record| record["license"] }.compact.find do |license|
          license["expression"] == "LicenseRef-Remix-icon-license-1.0"
        end
        unless entry && entry["status"] == ["not-allowed"]
          raise Agentlab::Error, "Fedora Remix Icon license policy is not the expected not-allowed record"
        end
      end

      {
        "normalizations" => normalized,
        "fedora_license_data" => remix && {
          "filename" => File.basename(fedora_path),
          "sha256" => Digest::SHA256.file(fedora_path).hexdigest
        },
        "not_allowed" => remix ? [{
          "archive" => remix.fetch("archive"),
          "npm_name" => remix.fetch("npm_name"),
          "version" => remix.fetch("version"),
          "declared_license" => remix.fetch("declared_license"),
          "fedora_expression" => entry.fetch("expression"),
          "fedora_status" => entry.fetch("status"),
          "fedora_url" => entry.fetch("url")
        }] : [],
        "aggregate_license_expression_verified" => false,
        "rpm_license_payload_complete" => false
      }
    end

    def missing_license?(license)
      license.nil? || (license.is_a?(String) && license.strip.empty?)
    end

    def ambiguous_license?(license)
      !missing_license?(license) && !license.is_a?(String)
    end

    def non_spdx_license?(license)
      return false unless license.is_a?(String) && !license.strip.empty?

      expression = license.strip
      return true if expression.match?(/\A(?:SEE LICEN[CS]E IN|UNLICENSED)\b/i)

      tokens = expression.scan(/[A-Za-z0-9.+-]+|\(|\)/)
      return true unless tokens.join == expression.gsub(/\s+/, "")

      identifiers = tokens.reject { |token| %w[AND OR WITH ( )].include?(token) }
      identifiers.empty? || identifiers.any? { |identifier| !SPDX_IDENTIFIERS.include?(identifier) }
    end

    def checked_sha256!(path, expected, label)
      raise Agentlab::Error, "invalid OpenChamber #{label} SHA-256" unless expected.to_s.match?(SHA256)

      actual = Digest::SHA256.file(path).hexdigest
      raise Agentlab::Error, "OpenChamber #{label} SHA-256 does not match package metadata" unless actual == expected

      actual
    end

    def validate_inputs!(selected, source_audit, selected_sha256)
      raise Agentlab::Error, "unsupported OpenChamber selected-lock schema" unless selected["schema"] == "openchamber-selected-lock-audit/v2"
      raise Agentlab::Error, "unsupported OpenChamber source-audit schema" unless source_audit["schema"] == SOURCE_SCHEMA
      raise Agentlab::Error, "OpenChamber source-license package mismatch" unless source_audit["package"] == "openchamber"
      raise Agentlab::Error, "OpenChamber source-license receipt binding mismatch" unless source_audit["selected_lock_receipt_sha256"] == selected_sha256
      raise Agentlab::Error, "OpenChamber source-license archive count mismatch" unless source_audit.dig("summary", "unique_sources") == source_audit.fetch("sources").length
    end
  end
end
