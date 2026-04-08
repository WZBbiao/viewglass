class LookinCli < Formula
  desc "Programmable CLI for Lookin iOS view hierarchy inspector"
  homepage "https://lookin.work"
  url "https://github.com/WZBbiao/Lookin.git",
      tag: "cli-v0.1.0",
      revision: "e59816764ddd68d49a7ffc3f19793e9e88b4da50"
  license "MIT"

  head "https://github.com/WZBbiao/Lookin.git", branch: "codex/lookin-cli"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/lookin-cli"
  end

  test do
    assert_match "lookin-cli", shell_output("#{bin}/lookin-cli --help")
  end
end
