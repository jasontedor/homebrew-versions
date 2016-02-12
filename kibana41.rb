class Kibana41 < Formula
  desc "Analytics and search dashboard for Elasticsearch"
  homepage "https://www.elastic.co/products/kibana"
  url "https://github.com/elastic/kibana.git", :tag => "v4.1.5", :revision => "04efeb4ca2305809137225ae6aa22e13de899d51"
  head "https://github.com/elastic/kibana.git"

  bottle do
    sha256 "abdc7a48eb0123e9942ec7cac51194682f760799d5f03f27c3a28673fb6dda5c" => :el_capitan
    sha256 "3a715512faf54f477792a656227dd02c952efab6a6d6f410349b5f9ccaad9f6d" => :yosemite
    sha256 "a9d3a8e678f4ad263d79eed44702f380d3adf5c52bdaaf29946eae03fbe2b28f" => :mavericks
  end

  conflicts_with "kibana", :because => "Different versions of same formula"

  resource "node" do
    url "https://nodejs.org/dist/v0.10.42/node-v0.10.42.tar.gz"
    sha256 "ebc1d53698f80c5a7b0b948e1108d7858f93d2d9ebf4541c12688d85704de105"
  end

  def install
    resource("node").stage buildpath/"node"
    cd buildpath/"node" do
      system "./configure", "--prefix=#{libexec}/node"
      system "make", "install"
    end

    # do not download binary installs of Node.js
    inreplace buildpath/"tasks/build.js", /('download_node_binaries',)/, "// \\1"

    # do not build packages for other platforms
    if OS.mac? && Hardware::CPU.is_64_bit?
      platform = "darwin-x64"
    elsif OS.linux?
      platform = Hardware::CPU.is_64_bit? ? "linux-x64" : "linux-x86"
    else
      raise "Installing Kibana via Homebrew is only supported on Darwin x86_64, Linux i386, Linux i686, and Linux x86_64"
    end
    inreplace buildpath/"Gruntfile.js", /^(\s+)platforms: .*/, "\\1platforms: [ '#{platform}' ],"

    # do not build zip packages
    inreplace buildpath/"tasks/config/compress.js", /(build_zip: .*)/, "// \\1"

    ENV.prepend_path "PATH", prefix/"libexec/node/bin"
    system "npm", "install", "grunt-cli", "bower"
    system "npm", "install"
    system "node_modules/.bin/bower", "install"
    system "node_modules/.bin/grunt", "build"

    mkdir "tar" do
      system "tar", "--strip-components", "1", "-xf", Dir[buildpath/"target/kibana-*-#{platform}.tar.gz"].first

      rm_f Dir["bin/*.bat"]
      prefix.install "bin", "config", "plugins", "src"
    end

    inreplace "#{bin}/kibana", %r{/node/bin/node}, "/libexec/node/bin/node"

    cd prefix do
      inreplace "config/kibana.yml", %r{/var\/run\/kibana.pid}, var/"run/kibana.pid"
      (etc/"kibana").install Dir["config/*"]
      rm_rf "config"

      (var/"kibana/plugins").install Dir["plugins/*"]
      rm_rf "plugins"
    end
  end

  def post_install
    ln_s etc/"kibana", prefix/"config"
    ln_s var/"kibana/plugins", prefix/"plugins"
  end

  plist_options :manual => "kibana"

  def caveats; <<-EOS.undent
    Plugins: #{var}/kibana/plugins/
    Config: #{etc}/kibana/
    EOS
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/kibana</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    ENV["BABEL_CACHE_PATH"] = testpath/".babelcache.json"
    assert_match /#{version}/, shell_output("#{bin}/kibana -V")
  end
end
