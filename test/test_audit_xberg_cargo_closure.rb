# frozen_string_literal: true

require "minitest/autorun"
load File.expand_path("../scripts/audit-xberg-cargo-closure", __dir__)

class XbergCargoClosureTest < Minitest::Test
  def test_accepts_only_links_that_resolve_inside_the_archive_root
    assert_equal(
      "xberg-1.0.1/test_documents/docx",
      XbergCargoClosure.safe_symlink_target("xberg-1.0.1/e2e/dart/docx", "../../test_documents/docx")
    )
    assert_equal(
      "xberg-1.0.1/test_documents/fixture.docx",
      XbergCargoClosure.safe_hardlink_target(
        "xberg-1.0.1/e2e/dart/fixture.docx",
        "xberg-1.0.1/test_documents/fixture.docx"
      )
    )

    assert_raises(XbergCargoClosure::Error) do
      XbergCargoClosure.safe_symlink_target("xberg-1.0.1/e2e/dart/docx", "../../../outside")
    end
    assert_raises(XbergCargoClosure::Error) do
      XbergCargoClosure.safe_symlink_target("xberg-1.0.1/e2e/dart/docx", "/outside")
    end
    assert_raises(XbergCargoClosure::Error) do
      XbergCargoClosure.safe_hardlink_target("xberg-1.0.1/e2e/dart/docx", "other-root/fixture.docx")
    end
  end
end
