class Kibana42 < Formula
  desc "Analytics and search dashboard for Elasticsearch"
  homepage "https://www.elastic.co/products/kibana"
  url "https://github.com/elastic/kibana.git", :tag => "v4.2.2", :revision => "0a008cd5e312a99eeff403f9585af2d99a18758a"
  head "https://github.com/elastic/kibana.git"

  conflicts_with "kibana", :because => "Different versions of same formula"

  resource "node" do
    url "https://nodejs.org/dist/v0.12.9/node-v0.12.9.tar.gz"
    sha256 "35daad301191e5f8dd7e5d2fbb711d081b82d1837d59837b8ee224c256cfe5e4"
  end

  def install
    resource("node").stage buildpath/"node"
    cd buildpath/"node" do
      system "./configure", "--prefix=#{libexec}/node"
      system "make", "install"
    end

    # do not download binary installs of Node.js
    inreplace buildpath/"tasks/build/index.js", /('_build:downloadNodeBuilds:\w+',)/, "// \\1"

    # do not build packages for other platforms
    platforms = Set.new(["darwin-x64", "linux-x64", "linux-x86", "windows"])
    if OS.mac? && Hardware::CPU.is_64_bit?
      platform = "darwin-x64"
    elsif OS.linux?
      platform = Hardware::CPU.is_64_bit? ? "linux-x64" : "linux-x86"
    else
      raise "Installing Kibana via Homebrew is only supported on Darwin x86_64, Linux i386, Linux i686, and Linux x86_64"
    end
    platforms.delete(platform)
    sub = platforms.to_a.join("|")
    inreplace buildpath/"tasks/config/platforms.js", /('(#{sub})',?(?!;))/, "// \\1"

    # do not build zip package
    inreplace buildpath/"tasks/build/archives.js", /(await exec\('zip'.*)/, "// \\1"

    ENV.prepend_path "PATH", prefix/"libexec/node/bin"
    system "npm", "install"
    system "npm", "run", "build"
    mkdir "tar" do
      system "tar", "--strip-components", "1", "-xf", Dir[buildpath/"target/kibana-*-#{platform}.tar.gz"].first

      rm_f Dir["bin/*.bat"]
      prefix.install "bin", "config", "node_modules", "optimize", "package.json", "src", "webpackShims"
    end

    inreplace "#{bin}/kibana", %r{/node/bin/node}, "/libexec/node/bin/node"

    cd prefix do
      inreplace "config/kibana.yml", %r{/var/run/kibana.pid}, var/"run/kibana.pid"
      (etc/"kibana").install Dir["config/*"]
      rm_rf "config"
    end
  end

  def post_install
    ln_s etc/"kibana", prefix/"config"

    (var/"lib/kibana/installedPlugins").mkpath
    ln_s var/"lib/kibana/installedPlugins", prefix/"installedPlugins"
  end

  plist_options :manual => "kibana"

  def caveats; <<-EOS.undent
    Plugins: #{var}/kibana/installedPlugins/
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
