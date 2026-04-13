class Viewglass < Formula
  desc "CLI-first iOS runtime inspector compatible with LookinServer"
  homepage "https://github.com/WZBbiao/viewglass"
  url "https://github.com/WZBbiao/viewglass.git",
      tag: "viewglass-v0.1.0",
      revision: "a07f60c0c91884430b21deb89ed559d08de7029d"
  license "GPL-3.0-only"

  head "https://github.com/WZBbiao/viewglass.git", branch: "main"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/viewglass"
  end

  test do
    assert_match "viewglass", shell_output("#{bin}/viewglass --help")
  end
end
