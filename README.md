## s-ui-pro (s-ui + nginx) :octocat:	:open_file_folder:	
- Auto Installation (lightweight)
- Compatible with Cloudflare
- Multi-domain support (main VPN domain and subscription domain)
- Handle WebSocket and GRPC via nginx
- Support for existing SSL certificates (no automatic generation)
- Multi-user and config via port 443
- Access to s-ui panel via nginx
- Subscription service on port 2096
- Compatible with Debian 10+ and Ubuntu 20+
- More security and low detection with nginx
- Random 150+ fake template!
  
**Install Panel**:dvd::package:

**Prerequisites**: 
- Have your SSL certificates ready from Cloudflare or other provider
- Main domain certificates should be at: `/root/cert-CF/{base-domain}/`
- Subscription domain certificates should be at: `/root/cert/{subdomain}/`

Example certificate paths:
- Main domain (nl-main.z3df1lter.uk): Certs at `/root/cert-CF/z3df1lter.uk/fullchain.pem` and `privkey.pem`
  - Note: Certificate path uses base domain (z3df1lter.uk) extracted from full domain (nl-main.z3df1lter.uk)
- Sub domain (sub.rqzbe.ir): Certs at `/root/cert/sub.rqzbe.ir/fullchain.pem` and `privkey.pem`
  - Note: Certificate path uses full subscription domain

```
bash <(wget -qO- https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/s-ui-pro.sh) -install yes
```

During installation, you'll be prompted to enter:
1. Main domain for VPN (e.g., nl-main.z3df1lter.uk) - will use port 443
2. Subscription domain (e.g., sub.rqzbe.ir) - will use port 2096

> The script will use your existing SSL certificates from the paths mentioned above
>
> Main domain handles VPN connections on port 443
>
> Subscription domain provides subscription service on port 2096

---

## How to Configure Inbounds in S-UI :gear:

After installation, you need to configure your inbounds in s-ui to work through the nginx reverse proxy. Here's how:

### Access S-UI Panel
- URL: `https://your-main-domain.com/RANDOM_PATH/`
- The random path is shown after installation (save it!)
- Login with the credentials provided during installation

### Supported Transport Protocols

The nginx configuration supports the following transports:
- ✅ **WebSocket** - Recommended for most users
- ✅ **gRPC** - Good for bypassing DPI
- ✅ **HTTP/2** - Native support
- ✅ **HTTP Upgrade** - Standard upgrade mechanism
- ✅ **TCP** - Via HTTP proxy
- ✅ **Reality Protocol** - With custom SNI support
- ✅ **Trojan** - With different SNI values
- ✅ **VLESS** - With custom serverNames

**Note**: QUIC, Hysteria2, and TUIC use UDP and typically run on separate ports outside nginx.

### Configuration Examples

#### 1. WebSocket Inbound (Recommended)

**In S-UI Panel:**
- **Protocol**: VLESS, VMess, Trojan, or Shadowsocks
- **Port**: Choose any port (e.g., 10001, 10002, etc.)
- **Transport**: WebSocket
- **Path**: `/10001/ws` (format: `/{PORT}/{ANY_PATH}`)
- **Host**: Leave empty or use your domain

**Client Configuration:**
- **Address**: `your-main-domain.com`
- **Port**: `443`
- **TLS**: Enable
- **SNI**: `your-main-domain.com` (or custom SNI for Reality)
- **Path**: `/10001/ws`

**How it works:**
```
Client → nginx:443 → nginx proxy → s-ui:10001
```

#### 2. gRPC Inbound

**In S-UI Panel:**
- **Protocol**: VLESS or VMess
- **Port**: Choose any port (e.g., 10002)
- **Transport**: gRPC
- **ServiceName**: `10002/grpc` (format: `{PORT}/{SERVICE_NAME}`)
- **Mode**: Multi or Gun mode

**Client Configuration:**
- **Address**: `your-main-domain.com`
- **Port**: `443`
- **TLS**: Enable
- **SNI**: `your-main-domain.com`
- **ServiceName**: `10002/grpc`

#### 3. Reality Protocol with Custom SNI

**In S-UI Panel:**
- **Protocol**: VLESS-Reality
- **Port**: Choose any port (e.g., 10003)
- **Transport**: TCP or gRPC
- **Path** (if using WebSocket): `/10003/reality`
- **Dest (SNI)**: `www.google.com` or any legitimate site
- **ServerNames**: `www.google.com`

**Client Configuration:**
- **Address**: `your-main-domain.com`
- **Port**: `443`
- **TLS**: Enable
- **SNI**: `www.google.com` (matches your Reality dest)
- **Path**: `/10003/reality` (if using WebSocket transport)

**Important**: The nginx config uses `$http_host` to preserve your custom SNI, so Reality will work correctly!

#### 4. HTTP/2 (h2) Inbound

**In S-UI Panel:**
- **Protocol**: VLESS or VMess
- **Port**: Choose any port (e.g., 10004)
- **Transport**: HTTP/2
- **Path**: `/10004/h2`
- **Host**: `your-main-domain.com`

**Client Configuration:**
- **Address**: `your-main-domain.com`
- **Port**: `443`
- **TLS**: Enable
- **Path**: `/10004/h2`

### Important Rules for Port/Path Configuration

**The Dynamic Routing Pattern:**
The nginx configuration includes a dynamic location that matches: `/{PORT}/{PATH}`

This means:
- Use format: `/{YOUR_BACKEND_PORT}/{ANY_PATH}` 
- Example: If s-ui listens on port `10001`, use path `/10001/ws` or `/10001/anything`
- The nginx will automatically proxy to `127.0.0.1:10001`

**Examples:**
```
/10001/ws        → proxies to 127.0.0.1:10001/ws
/10002/grpc      → proxies to 127.0.0.1:10002/grpc
/10003/reality   → proxies to 127.0.0.1:10003/reality
/12345/mypath    → proxies to 127.0.0.1:12345/mypath
```

### Best Practices

1. **Use Different Ports**: Create each inbound on a different port (10001, 10002, 10003, etc.)
2. **Match Path Format**: Always use `/{PORT}/{PATH}` format for the path
3. **Enable TLS on Client**: Always enable TLS in client and use port 443
4. **Custom SNI for Reality**: The configuration preserves custom SNI, so Reality works perfectly
5. **WebSocket Recommended**: WebSocket transport is most reliable through nginx
6. **Test Each Inbound**: After creating an inbound, test it before sharing with users

### Troubleshooting

**Connection Failed:**
- Check that the inbound port in s-ui matches the port in your path
- Verify TLS is enabled on the client side
- Ensure you're using port 443 (not the backend port)

**Reality Not Working:**
- Make sure the SNI on client matches the Reality `dest` configured in s-ui
- The nginx config uses `$http_host` which preserves custom SNI

**WebSocket Connection Issues:**
- Check that the path starts with `/{PORT}/`
- Verify nginx has the WebSocket upgrade map configured (automatically added during installation)

**Port 2096 Already in Use Error:**

If you see errors like `listen tcp :2096: bind: address already in use`, this means another process is using port 2096:

**Quick Fix - Use the automated fix script:**
```bash
bash <(wget -qO- https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/fix-port-2096.sh)
```

This script will:
- Diagnose what's using port 2096
- Check s-ui database for conflicting configurations
- Attempt to automatically fix the issue
- Provide detailed guidance if manual intervention is needed

**Manual Diagnosis:**

1. **Check what's using the port:**
   ```bash
   lsof -i :2096
   # or
   netstat -tlnp | grep :2096
   ```

2. **Common causes:**
   - Another instance of s-ui or nginx is running
   - A previous installation wasn't fully removed
   - Another application is using port 2096

3. **Solutions:**
   - Stop the conflicting service: `systemctl stop <service-name>`
   - Kill the process: `kill <PID>` (replace `<PID>` with the process ID from step 1)
   - Uninstall completely and reinstall:
     ```bash
     bash <(wget -qO- https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/s-ui-pro.sh) -uninstall yes
     bash <(wget -qO- https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/s-ui-pro.sh) -install yes
     ```

4. **Check service status:**
   ```bash
   systemctl status s-ui
   systemctl status nginx
   journalctl -u s-ui -n 50
   ```

5. **Verify ports are free before reinstalling:**
   ```bash
   # This should return nothing if ports are free
   lsof -i :80 -i :443 -i :2096
   ```

### Subscription Service

The subscription domain works on port **2096** with SSL:
- **URL Format**: `https://sub-domain.com:2096/sub/{USERNAME}?format=json`
- **How it works**: Nginx listens on port 2096 with SSL and proxies requests to s-ui's subscription service
- s-ui runs TWO separate listeners - one for web panel, one for subscription service
- Nginx handles SSL termination for both main domain (port 443) and subscription domain (port 2096)

#### Port Configuration Explained

**Q: What port does s-ui subscription service listen on?**

**A:** s-ui runs **TWO separate HTTP listeners** on **TWO different internal ports**:
- Web panel listener: `http://127.0.0.1:PORT1` (e.g., 15234)
- Subscription listener: `http://127.0.0.1:PORT2` (e.g., 23451)

Both run in the same s-ui process, but they listen on different ports.

**Nginx routing:**
```nginx
# Main domain → s-ui web panel port
server {
    listen 443 ssl;
    server_name nl-main.z3df1lter.uk;
    location /panel-path/ {
        proxy_pass http://127.0.0.1:15234;  # Web panel port
    }
}

# Subscription domain → s-ui subscription port (DIFFERENT!)
server {
    listen 2096 ssl;
    server_name sub.rqzbe.ir;
    location / {
        proxy_pass http://127.0.0.1:23451;  # Subscription port
    }
}
```

**Database Configuration:**
```bash
webPort=15234          # s-ui web panel listener port
subPort=23451          # s-ui subscription listener port (DIFFERENT!)
```

**Why different ports?** s-ui has two separate HTTP server listeners - one for the admin panel and one for the subscription service. They must be on different ports.

#### Different Domain Support

The subscription service can use a **completely different domain** from the main VPN domain:
- **Main domain**: `nl-main.z3df1lter.uk` (VPN connections on port 443)
- **Subscription domain**: `sub.rqzbe.ir` (subscription service on port 2096)

**Database Configuration:**
```bash
subDomain=sub.rqzbe.ir          # Domain for subscription URLs
subURI=https://sub.rqzbe.ir:2096  # Full base URL
subPath=/sub/                    # Subscription endpoint path
subPort=<internal-port>          # Same as web panel port
```

s-ui uses these settings to generate subscription URLs with the correct domain, regardless of the server's hostname.

#### CDN and Proxy Support

The subscription domain can be behind a CDN with proxy enabled:
- **DNS Setup**: Point subscription domain to CDN or directly to server IP
- **CDN Proxy**: If using CDN proxy, the subscription domain may resolve to a different IP
- **Works Transparently**: Nginx handles requests locally regardless of how traffic arrives
- **SSL**: Nginx terminates SSL with your certificates, then proxies to s-ui

**Example Setup:**
```
User → https://sub.rqzbe.ir:2096/sub/USER (CDN IP: 104.x.x.x)
       ↓
    CDN (proxied, SSL passthrough or re-encryption)
       ↓
    Your Server (Real IP: 45.x.x.x)
       ↓
    Nginx (port 2096, terminates SSL)
       ↓
    s-ui (internal port, generates URLs with sub.rqzbe.ir)
```

This allows you to:
- Hide your real server IP behind CDN
- Use different domains for different services
- Keep existing user subscription links working
- Benefit from CDN caching and DDoS protection

---

### Reverse Proxy Options for DPI Bypass :shield:

This project uses **Nginx** as the reverse proxy, which is well-suited for bypassing Deep Packet Inspection (DPI) in Iran and similar censorship environments. However, you might wonder about alternatives:

**Why Nginx (Current Choice)?**
- Lightweight and high-performance
- Excellent WebSocket and gRPC support (critical for modern VPN protocols)
- Wide adoption and extensive documentation
- Lower resource usage compared to alternatives
- Strong track record for DPI bypass when properly configured

**Caddy vs HAProxy Comparison:**

**Caddy:**
- ✅ Automatic HTTPS with Let's Encrypt (not needed here since we use Cloudflare certs)
- ✅ Simpler configuration syntax
- ✅ Good WebSocket support
- ❌ Higher memory usage than Nginx
- ❌ Less mature for high-traffic scenarios
- ⚠️ For DPI bypass: Similar effectiveness to Nginx

**HAProxy:**
- ✅ Excellent for TCP load balancing
- ✅ Very efficient for high-traffic scenarios
- ✅ Advanced traffic manipulation features
- ❌ More complex HTTP/2 and gRPC configuration
- ❌ Requires additional setup for WebSocket
- ⚠️ For DPI bypass: Good, but not optimized for HTTP-based protocols

**Recommendation for Iran:**
Stick with **Nginx** for this setup because:
1. It handles WebSocket and gRPC natively (both used by modern VPN protocols)
2. Lower resource footprint = better performance on VPS
3. HTTP/2 support is excellent for mimicking normal HTTPS traffic
4. The current configuration is already optimized for DPI bypass

The key to bypassing DPI is not the reverse proxy choice, but rather:
- Using proper SNI (Server Name Indication) with Cloudflare domains
- Proper WebSocket/gRPC configuration (already included)
- Random path obfuscation (implemented via `$RNDSTR`)
- TLS 1.3 support (enabled in config)

---

## Quick Reference Table :bookmark_tabs:

| Transport | S-UI Port | S-UI Path/Service | Client Address | Client Port | Client Path/Service |
|-----------|-----------|-------------------|----------------|-------------|---------------------|
| WebSocket | 10001 | `/10001/ws` | main-domain.com | 443 | `/10001/ws` |
| gRPC | 10002 | `10002/grpc` | main-domain.com | 443 | `10002/grpc` |
| HTTP/2 | 10003 | `/10003/h2` | main-domain.com | 443 | `/10003/h2` |
| Reality+WS | 10004 | `/10004/reality` | main-domain.com | 443 | `/10004/reality` |
| TCP | 10005 | `/10005/tcp` | main-domain.com | 443 | `/10005/tcp` |

**Pattern**: Always use `/{S-UI_PORT}/{ANY_PATH}` format for dynamic routing!

➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖

**Random fake html site**:earth_asia:	
```
bash <(wget -qO- https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/randomfakehtml.sh)
```

**Uninstall**:x:
```
bash <(wget -qO- https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/s-ui-pro.sh) -uninstall yes
```

**Fix Port Conflicts**:wrench:
If you experience port 2096 binding errors:
```
bash <(wget -qO- https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/fix-port-2096.sh)
```

➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
### Server Configuration :wrench:🐧⚙️
![](https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/media/Server_Config_.png)
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
### Client Configuration :white_check_mark:	:computer:🔌
![](https://raw.githubusercontent.com/rqzbeh/S-UI-PRO/master/media/ClientUser_Config.png)
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
### Cloudflare Find Good IP (VPN off❗ during scanning)
Cloudflare IP Ranges: https://www.cloudflare.com/ips/

Cloudflare IP Scanner: [vfarid](https://vfarid.github.io/cf-ip-scanner/) | [goldsrc](https://cloudflare-scanner.vercel.app) | [ircfspace](https://ircfspace.github.io/scanner/)

##
[![Star History Chart](https://api.star-history.com/svg?repos=rqzbeh/S-UI-PRO&type=Date)](https://github.com/rqzbeh/S-UI-PRO)

