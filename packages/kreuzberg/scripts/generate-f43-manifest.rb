#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "open3"

root = ARGV.fetch(0, "/srv/tmp/agentlab-kreuzberg/final-f43")
repo = File.join(root, "repo")
rows = Dir.glob(File.join(repo, "*.rpm")).sort.map do |rpm|
  output, status = Open3.capture2("rpm", "-qp", "--qf", "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\t%{SOURCERPM}", rpm)
  abort("cannot query #{rpm}") unless status.success?
  nevra, source_rpm = output.split("\t", 2)
  [nevra, source_rpm, Digest::SHA256.file(rpm).hexdigest, rpm]
end

duplicates = rows.group_by(&:first).select { |_nevra, entries| entries.length > 1 }
abort("duplicate NEVRA: #{duplicates.keys.join(", ")}") unless duplicates.empty?

manifest = File.join(root, "repo-manifest.tsv")
File.write(manifest, "NEVRA\tSourceRPM\tSHA256\tPath\n" + rows.map { |row| row.join("\t") }.join("\n") + "\n")
File.write(File.join(root, "repo-manifest.summary"), "RPM_COUNT=#{rows.length}\nSHA256=#{Digest::SHA256.file(manifest).hexdigest}\n")
