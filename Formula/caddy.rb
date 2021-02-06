class Caddy < Formula
  desc "Powerful, enterprise-ready, open source web server with automatic HTTPS"
  homepage "https://caddyserver.com/"
  url "https://github.com/caddyserver/caddy/archive/v2.3.0.tar.gz"
  sha256 "4688b122ac05be39622aa81324d1635f1642e4a66d731e82d210aef78cf2766a"
  license "Apache-2.0"
  head "https://github.com/caddyserver/caddy.git"

  depends_on "go" => :build

  resource "xcaddy" do
    url "https://github.com/caddyserver/xcaddy/archive/v0.1.7.tar.gz"
    sha256 "9915970e69c07324f4d032741741516523147b6250e1426b16e6b794d4a56f05"
  end

  CADDY_MODULES = {
    alidns:                "github.com/caddy-dns/alidns",
    azure:                 "github.com/caddy-dns/azure",
    cloudflare:            "github.com/caddy-dns/cloudflare",
    digitalocean:          "github.com/caddy-dns/digitalocean",
    dnspod:                "github.com/caddy-dns/dnspod",
    duckdns:               "github.com/caddy-dns/duckdns",
    gandi:                 "github.com/caddy-dns/gandi",
    hetzner:               "github.com/caddy-dns/hetzner",
    "lego-deprecated":     "github.com/caddy-dns/lego-deprecated",
    "openstack-designate": "github.com/caddy-dns/openstack-designate",
    route53:               "github.com/caddy-dns/route53",
    vultr:                 "github.com/caddy-dns/vultr",
  }.freeze

  CADDY_MODULES.each do |k, v|
    option "with-#{k}", "Compile with #{v}"
  end

  def with_list
    CADDY_MODULES.map do |k, v|
      ["--with", v] if build.with? k.to_s
    end.compact.flatten
  end

  def install
    revision = build.head? ? version.commit : "v#{version}"

    resource("xcaddy").stage do
      system "go", "run", "cmd/xcaddy/main.go", "build", revision, "--output", bin/"caddy", *with_list
    end
  end

  plist_options manual: "caddy run --config #{HOMEBREW_PREFIX}/etc/Caddyfile"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <true/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_bin}/caddy</string>
            <string>run</string>
            <string>--config</string>
            <string>#{etc}/Caddyfile</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>StandardOutPath</key>
          <string>#{var}/log/caddy.log</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/caddy.log</string>
        </dict>
      </plist>
    EOS
  end

  test do
    port1 = free_port
    port2 = free_port

    (testpath/"Caddyfile").write <<~EOS
      {
        admin 127.0.0.1:#{port1}
      }

      http://127.0.0.1:#{port2} {
        respond "Hello, Caddy!"
      }
    EOS

    fork do
      exec bin/"caddy", "run", "--config", testpath/"Caddyfile"
    end
    sleep 2

    assert_match "\":#{port2}\"",
      shell_output("curl -s http://127.0.0.1:#{port1}/config/apps/http/servers/srv0/listen/0")
    assert_match "Hello, Caddy!", shell_output("curl -s http://127.0.0.1:#{port2}")

    assert_match version.to_s, shell_output("#{bin}/caddy version")
  end
end