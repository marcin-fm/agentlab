#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "digest"
require "fileutils"

root = File.expand_path(ARGV.fetch(0, "/srv/tmp/agentlab-kreuzberg/final-f43"))
input = ARGV.fetch(1, "/srv/tmp/agentlab-kreuzberg/final-f44/manifest.tsv")
output = File.join(root, "source-manifest.tsv")
srpm_dir = File.join(root, "srpms")

  "rust-comrak0.54-0.54.0-1.fc44.src.rpm" => File.join(root, "fixes/comrak/srpm/rust-comrak0.54-0.54.0-1.fc43.src.rpm"),
  "rust-hayro-jbig2_0.3-0.3.0-1.fc44.src.rpm" => File.join(root, "fixes/hayro-jbig2/srpm/rust-hayro-jbig2_0.3-0.3.0-1.fc43.src.rpm"),
}

rows = CSV.read(input, col_sep: "\t", headers: true)
packages = rows.reject { |row| row["SourceRPM"].start_with?("pdfium-") }.group_by { |row| [row["SourceRPM"], row["Origin"]] }
FileUtils.mkdir_p(srpm_dir)

CSV.open(output, "w", col_sep: "\t") do |csv|
  csv << %w[SourceRPM SHA256 Origin SourcePath]
  packages.sort.each do |(source_rpm, origin), _entries|
    source = overrides[source_rpm]
    if source
      destination = File.join(srpm_dir, File.basename(source))
      FileUtils.cp(source, destination)
      csv << [File.basename(source), Digest::SHA256.file(destination).hexdigest, "#{root}/fixes", source]
      next
    end

    candidates = Dir.glob(File.join(origin, "**", source_rpm)).select { |path| File.file?(path) }.uniq
    abort "missing exact source #{source_rpm} below #{origin}" if candidates.empty?
    abort "ambiguous exact source #{source_rpm}: #{candidates.join(", ")}" unless candidates.one?
    source = candidates.first
    destination = File.join(srpm_dir, source_rpm)
    FileUtils.cp(source, destination)
    csv << [source_rpm, Digest::SHA256.file(destination).hexdigest, origin, source]
  end
end
