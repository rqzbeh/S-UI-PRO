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
bash <(wget -qO- https://raw.githubusercontent.com/GFW4Fun/S-UI-PRO/master/s-ui-pro.sh) -install yes
```

During installation, you'll be prompted to enter:
1. Main domain for VPN (e.g., nl-main.z3df1lter.uk) - will use port 443
2. Subscription domain (e.g., sub.rqzbe.ir) - will use port 2096

> The script will use your existing SSL certificates from the paths mentioned above
>
> Main domain handles VPN connections on port 443
>
> Subscription domain provides subscription service on port 2096
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖

**Random fake html site**:earth_asia:	
```
bash <(wget -qO- https://raw.githubusercontent.com/GFW4Fun/S-UI-PRO/master/randomfakehtml.sh)
```

**Uninstall**:x:
```
bash <(wget -qO- https://raw.githubusercontent.com/GFW4Fun/S-UI-PRO/master/s-ui-pro.sh) -uninstall yes
```

➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
### Server Configuration :wrench:🐧⚙️
![](https://raw.githubusercontent.com/GFW4Fun/S-UI-PRO/master/media/Server_Config_.png)
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
### Client Configuration :white_check_mark:	:computer:🔌
![](https://raw.githubusercontent.com/GFW4Fun/S-UI-PRO/master/media/ClientUser_Config.png)
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
### Cloudflare Find Good IP (VPN off❗ during scanning)
Cloudflare IP Ranges: https://www.cloudflare.com/ips/

Cloudflare IP Scanner: [vfarid](https://vfarid.github.io/cf-ip-scanner/) | [goldsrc](https://cloudflare-scanner.vercel.app) | [ircfspace](https://ircfspace.github.io/scanner/)

##
[![Star History Chart](https://api.star-history.com/svg?repos=GFW4Fun/S-UI-PRO&type=Date)](https://github.com/GFW4Fun/S-UI-PRO)

