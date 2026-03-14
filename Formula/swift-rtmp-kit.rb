# SPDX-License-Identifier: Apache-2.0
#
# Copyright 2026 Atelier Socle SAS
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Homebrew formula for swift-rtmp-kit
#
# Tap: atelier-socle/homebrew-tools
# Install: brew install atelier-socle/tools/swift-rtmp-kit

class SwiftRtmpKit < Formula
  desc "CLI tool for publishing live streams to RTMP/RTMPS servers"
  homepage "https://github.com/atelier-socle/swift-rtmp-kit"
  url "https://github.com/atelier-socle/swift-rtmp-kit/archive/refs/tags/0.3.0.tar.gz"
  sha256 "UPDATE_SHA256_AFTER_RELEASE"
  license "Apache-2.0"

  depends_on xcode: ["26.2", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/rtmp-cli"
  end

  test do
    # Version check
    assert_match "rtmp-cli", shell_output("#{bin}/rtmp-cli --help")

    # Subcommands present
    help_output = shell_output("#{bin}/rtmp-cli --help")
    assert_match "publish",          help_output
    assert_match "probe",            help_output
    assert_match "record",           help_output
    assert_match "server",           help_output
    assert_match "test-connection",  help_output

    # Subcommand --help (validates wiring)
    assert_match "url",   shell_output("#{bin}/rtmp-cli publish --help")
    assert_match "url",   shell_output("#{bin}/rtmp-cli probe --help")
    assert_match "url",   shell_output("#{bin}/rtmp-cli record --help")
    assert_match "start", shell_output("#{bin}/rtmp-cli server --help")
  end
end
