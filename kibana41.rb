class Kibana41 < Formula
  desc "Analytics and search dashboard for Elasticsearch"
  homepage "https://www.elastic.co/products/kibana"
  url "https://github.com/elastic/kibana.git", :tag => "v4.1.4", :revision => "3df681b3f205b2b75e11ddf68c0985f80460d7bc"
  head "https://github.com/elastic/kibana.git"

  bottle do
    sha256 "a324b8d38a6f488aedbbaf58410e247e7319c502e259c889e68a35a829a2e757" => :el_capitan
    sha256 "29b5cc931a3bcfbd6df658b1f7a160245a4afea9fb8818689a99420dfb5c36b8" => :yosemite
    sha256 "9036742597f5ef7cbea88f4e04f9d3a0227a3effad6ce9547142b31efdc67cd1" => :mavericks
  end

  resource "node" do
    url "https://nodejs.org/dist/v0.10.35/node-v0.10.35.tar.gz"
    sha256 "0043656bb1724cb09dbdc960a2fd6ee37d3badb2f9c75562b2d11235daa40a03"
  end

  def install
    resource("node").stage buildpath/"node"
    cd buildpath/"node" do
      system "./configure", "--prefix=#{libexec}/node"
      system "make", "install"
    end

    # do not download binary installs of Node.js
    inreplace buildpath/"tasks/build.js", %r{('download_node_binaries',)}, "// \\1"

    # do not build packages for other platforms
    if OS.mac? && Hardware::CPU.is_64_bit?
      platform = "darwin-x64"
    elsif OS.linux?
      platform = if Hardware::CPU.is_64_bit? then "linux-x64" else "linux-x86" end
    else
      raise "Installing Kibana via Homebrew is only supported on Darwin x86_64, Linux i386, Linux i686, and Linux x86_64"
    end
    inreplace buildpath/"Gruntfile.js", %r{^(\s+)platforms: .*}, "\\1platforms: [ '#{platform}' ],"

    # do not build zip packages
    inreplace buildpath/"tasks/config/compress.js", %r{(build_zip: .*)}, "// \\1"

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
      inreplace "config/kibana.yml", %{/var/run/kibana.pid}, var/"run/kibana.pid"
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
