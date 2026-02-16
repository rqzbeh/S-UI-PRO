#!/bin/bash
############### s-ui-pro v1.2 @ github.com/rqzbeh ##############
[[ $EUID -ne 0 ]] && echo "not root!" && exit 1
Pak=$(type apt &>/dev/null && echo "apt" || echo "yum")
msg_ok() { echo -e "\e[1;42m $1 \e[0m";}
msg_err() { echo -e "\e[1;41m $1 \e[0m";}
msg_inf() { echo -e "\e[1;34m$1\e[0m";}
echo;#https://www.asciiart.eu/text-to-ascii-art
msg_inf '╔═╗   ╦ ╦╦   ╔═╗╦═╗╔═╗';
msg_inf '╚═╗───║ ║║───╠═╝╠╦╝║ ║';
msg_inf '╚═╝   ╚═╝╩   ╩  ╩╚═╚═╝';echo;
RNDSTR=$(tr -dc A-Za-z0-9 </dev/urandom | head -c "$(shuf -i 6-12 -n 1)")
SUIDB="/usr/local/s-ui/db/s-ui.db";domain="";subdomain="";UNINSTALL="x";INSTALL="n";SUI_VERSION=""
while true; do 
    PORT=$(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 ))
    status="$(nc -z 127.0.0.1 $PORT < /dev/null &>/dev/null; echo $?)"
    if [ "${status}" != "0" ]; then
        break
    fi
done
################################Get arguments########################
while [ "$#" -gt 0 ]; do
  case "$1" in
    -install) INSTALL="$2"; shift 2;;
    -domain) domain="$2"; shift 2;;
    -subdomain) subdomain="$2"; shift 2;;
    -version) SUI_VERSION="$2"; shift 2;;
    -uninstall) UNINSTALL="$2"; shift 2;;
    *) shift 1;;
  esac
done
##############################Uninstall##############################
UNINSTALL_SUI(){
	printf 'y\n' | s-ui uninstall
	rm -rf "/usr/local/s-ui/"
	$Pak -y remove nginx nginx-common nginx-core nginx-full
	$Pak -y purge nginx nginx-common nginx-core nginx-full
	$Pak -y autoremove
	$Pak -y autoclean
	rm -rf "/var/www/html/" "/etc/nginx/" "/usr/share/nginx/" 
}
if [[ ${UNINSTALL} == *"y"* ]]; then
	UNINSTALL_SUI	
	clear && msg_ok "Completely Uninstalled!" && exit 1
fi
##############################Domain Validations######################
while true; do
	echo -en "Enter main domain for VPN (e.g., nl-main.z3df1lter.uk): " && read domain 
	if [[ ! -z "$domain" ]]; then
		break
	fi
done

while true; do
	echo -en "Enter subscription domain (e.g., sub.rqzbe.ir): " && read subdomain 
	if [[ ! -z "$subdomain" ]]; then
		break
	fi
done

domain=$(echo "$domain" 2>&1 | tr -d '[:space:]' )
subdomain=$(echo "$subdomain" 2>&1 | tr -d '[:space:]' )
SubDomain=$(echo "$domain" 2>&1 | sed 's/^[^ ]* \|\..*//g')
MainDomain=$(echo "$domain" 2>&1 | sed 's/.*\.\([^.]*\..*\)$/\1/')

if [[ "${SubDomain}.${MainDomain}" != "${domain}" ]] ; then
	MainDomain=${domain}
fi

# Extract base domain from main domain (e.g., z3df1lter.uk from nl-main.z3df1lter.uk)
# This assumes a standard format like subdomain.domain.tld
BaseDomain=$(echo "$domain" 2>&1 | sed 's/.*\.\([^.]*\.[^.]*\)$/\1/')
# If extraction failed (e.g., domain has no subdomain), use the full domain
if [[ -z "$BaseDomain" ]] || [[ "$BaseDomain" == "$domain" ]]; then
	BaseDomain=$domain
fi

###############################Install Packages#############################
if [[ ${INSTALL} == *"y"* ]]; then
	$Pak -y update
	$Pak -y install nginx sqlite3 
	systemctl daemon-reload && systemctl enable --now nginx
fi
systemctl stop nginx 2>/dev/null
sleep 2

# Kill any processes still using the required ports
msg_inf "Checking for processes using ports 80, 443, and 2096..."
msg_inf "WARNING: Any processes using these ports will be forcefully terminated!"
fuser -k 80/tcp 80/udp 443/tcp 443/udp 2096/tcp 2096/udp 2>/dev/null
sleep 2

# Double-check that ports are actually free
for port in 80 443 2096; do
	if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
		msg_err "Port $port is still in use after cleanup. Checking what's using it..."
		lsof -Pi :$port -sTCP:LISTEN 2>/dev/null || netstat -tlnp | grep ":$port "
		msg_err "Please manually stop the process using port $port and try again."
		exit 1
	fi
done
msg_ok "All required ports (80, 443, 2096) are available."
##############################SSL Certificate Paths####################################
# Using existing Cloudflare certificates
# Certificate path structure:
#   Main domain: /root/cert-CF/{BaseDomain}/ (base domain extracted from full domain)
#     Example: For nl-main.z3df1lter.uk -> /root/cert-CF/z3df1lter.uk/
#   Subscription domain: /root/cert/{full-subdomain}/ (full subscription domain)
#     Example: For sub.rqzbe.ir -> /root/cert/sub.rqzbe.ir/
# This matches the user's existing certificate directory structure from Cloudflare

msg_inf "Using existing SSL certificates from:"
msg_inf "Main domain ($domain): /root/cert-CF/$BaseDomain/"
msg_inf "Subscription domain ($subdomain): /root/cert/$subdomain/"

# Verify certificate files exist
if [[ ! -f "/root/cert-CF/$BaseDomain/fullchain.pem" ]] || [[ ! -f "/root/cert-CF/$BaseDomain/privkey.pem" ]]; then
	msg_err "SSL certificates for main domain not found at /root/cert-CF/$BaseDomain/" && exit 1
fi

if [[ ! -f "/root/cert/$subdomain/fullchain.pem" ]] || [[ ! -f "/root/cert/$subdomain/privkey.pem" ]]; then
	msg_err "SSL certificates for subscription domain not found at /root/cert/$subdomain/" && exit 1
fi

###########################################################################
# Add WebSocket upgrade map to nginx.conf if not already present
if ! grep -q "map \$http_upgrade \$connection_upgrade" /etc/nginx/nginx.conf; then
	# Add WebSocket upgrade map after the http { line
	cat > /tmp/websocket_map.conf << 'WSMAP'
    # WebSocket and HTTP upgrade support
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
WSMAP
	sed -i '/http {/r /tmp/websocket_map.conf' /etc/nginx/nginx.conf
	rm -f /tmp/websocket_map.conf
fi

###########################################################################
# Main VPN domain configuration (port 443)
cat > "/etc/nginx/sites-available/$domain" << 'NGXEOF'
server {
	server_name DOMAIN_PLACEHOLDER;
	listen 80;
	listen [::]:80;
	return 301 https://\$server_name\$request_uri;
}

server {
	server_name DOMAIN_PLACEHOLDER;
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	http2_push_preload on;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_certificate CERT_PATH_PLACEHOLDER/fullchain.pem;
	ssl_certificate_key CERT_PATH_PLACEHOLDER/privkey.pem;
	
	location /RNDSTR_PLACEHOLDER/ {
		proxy_redirect off;
		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_pass http://127.0.0.1:PORT_PLACEHOLDER;
	}
	
	# Dynamic port forwarding location with support for multiple transports
	# Supports: WebSocket, gRPC, HTTP/2, HTTP upgrade, and standard HTTP/HTTPS
	# Also supports Reality, Trojan, VLESS with custom SNI (preserves original Host header)
	# For QUIC/Hysteria2/TUIC: These protocols typically use UDP and separate ports
	location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)\$ {
		client_max_body_size 0;
		client_body_timeout 1d;
		grpc_read_timeout 1d;
		grpc_socket_keepalive on;
		proxy_read_timeout 1d;
		proxy_http_version 1.1;
		proxy_buffering off;
		proxy_request_buffering off;
		proxy_socket_keepalive on;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \$connection_upgrade;
		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_pass http://127.0.0.1:\$fwdport/\$fwdpath;
	}
	
	location / { try_files \$uri \$uri/ =404; }
}
NGXEOF

# Replace placeholders with actual values
sed -i "s|DOMAIN_PLACEHOLDER|$domain|g" "/etc/nginx/sites-available/$domain"
sed -i "s|CERT_PATH_PLACEHOLDER|/root/cert-CF/$BaseDomain|g" "/etc/nginx/sites-available/$domain"
sed -i "s|RNDSTR_PLACEHOLDER|$RNDSTR|g" "/etc/nginx/sites-available/$domain"
sed -i "s|PORT_PLACEHOLDER|$PORT|g" "/etc/nginx/sites-available/$domain"

# Subscription domain configuration (port 2096)
cat > "/etc/nginx/sites-available/$subdomain" << EOF
server {
	server_name $subdomain;
	listen 80;
	listen [::]:80;
	return 301 https://\$server_name\$request_uri;
}

server {
	server_name $subdomain;
	listen 2096 ssl http2;
	listen [::]:2096 ssl http2;
	http2_push_preload on;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_certificate /root/cert/$subdomain/fullchain.pem;
	ssl_certificate_key /root/cert/$subdomain/privkey.pem;
	
	location / {
		proxy_redirect off;
		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_pass http://127.0.0.1:$PORT;
	}
}
EOF

###################################Enable Site###############################
if [[ -f "/etc/nginx/sites-available/$domain" ]] && [[ -f "/etc/nginx/sites-available/$subdomain" ]]; then
	unlink /etc/nginx/sites-enabled/default 2>/dev/null
	ln -sf "/etc/nginx/sites-available/$domain" /etc/nginx/sites-enabled/ 2>/dev/null
	ln -sf "/etc/nginx/sites-available/$subdomain" /etc/nginx/sites-enabled/ 2>/dev/null
	
	# Test nginx configuration
	if ! nginx -t 2>&1; then
		msg_err "Nginx configuration test failed!" && exit 1
	fi
	
	# Start nginx and verify it's running
	systemctl start nginx
	sleep 2
	
	if ! systemctl is-active --quiet nginx; then
		msg_err "Nginx failed to start. Checking for port conflicts..."
		for port in 80 443 2096; do
			if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
				msg_err "Port $port is in use:"
				lsof -Pi :$port -sTCP:LISTEN 2>/dev/null || netstat -tlnp | grep ":$port "
			fi
		done
		msg_err "Please resolve port conflicts and try again."
		exit 1
	fi
	msg_ok "Nginx started successfully on ports 80, 443, and 2096"
else
	msg_err "Nginx config files not created!" && exit 1
fi
###################################Update Db##################################
UPDATE_SUIDB(){
if [[ -f $SUIDB ]]; then
	# First, let's check if there are any settings that might be causing port 2096 binding
	msg_inf "Checking s-ui database for port configurations..."
	
	# Display all current port-related settings for debugging
	msg_inf "Current port settings in database:"
	sqlite3 $SUIDB "SELECT key, value FROM settings WHERE key LIKE '%port%';" 2>/dev/null || true
	
	sqlite3 $SUIDB <<EOF
	DELETE FROM "settings" WHERE ( "key"="webPort" ) OR ( "key"="webCertFile" ) OR ( "key"="webKeyFile" ) OR ( "key"="webPath" ); 
	INSERT INTO "settings" ("key", "value") VALUES ("webPort",  "${PORT}");
	INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  "");
	INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile", "");
	INSERT INTO "settings" ("key", "value") VALUES ("webPath", "/${RNDSTR}/");
EOF
	
	# Check if there's a subPort or subscriptionPort setting and remove it
	# since nginx will handle port 2096 instead
	msg_inf "Removing any subscription port settings (nginx will handle port 2096)..."
	sqlite3 $SUIDB "DELETE FROM settings WHERE key='subPort' OR key='subscriptionPort' OR key='subListenPort';" 2>/dev/null || true
	
	# Also check for any inbound configurations that might be using port 2096
	msg_inf "Checking for inbounds using port 2096..."
	INBOUNDS_2096=$(sqlite3 $SUIDB "SELECT COUNT(*) FROM inbounds WHERE CAST(port AS INTEGER)=2096;" 2>/dev/null || echo "0")
	if [ "$INBOUNDS_2096" != "0" ]; then
		msg_err "Warning: Found $INBOUNDS_2096 inbound(s) configured to use port 2096"
		msg_err "These will conflict with nginx. Please reconfigure them to use different ports."
		sqlite3 $SUIDB "SELECT id, remark, port FROM inbounds WHERE CAST(port AS INTEGER)=2096;" 2>/dev/null || true
	fi
	
	msg_ok "Database updated successfully"
else
	msg_err "s-ui.db file not exist! Maybe s-ui isn't installed." && exit 1;
fi
}
###################################Install Panel#########################
if systemctl is-active --quiet s-ui; then
	UPDATE_SUIDB
	
	# Before restarting s-ui, ensure nginx is running on port 2096
	if ! systemctl is-active --quiet nginx; then
		msg_err "Nginx is not running before s-ui restart. Starting nginx..."
		systemctl start nginx
		sleep 2
	fi
	
	# Verify nginx has port 2096
	if ! lsof -Pi :2096 -sTCP:LISTEN -c nginx >/dev/null 2>&1; then
		msg_err "Warning: Nginx is not listening on port 2096. The subscription service requires this."
		msg_inf "Attempting to restart nginx..."
		systemctl restart nginx
		sleep 2
	fi
	
	msg_inf "Restarting s-ui service..."
	s-ui restart
	# Wait for service to fully start (allowing up to 5 seconds for initialization)
	sleep 5
else
	printf 'n\n' | bash <(wget -qO- "https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh") $SUI_VERSION
	
	UPDATE_SUIDB
	if ! systemctl is-enabled --quiet s-ui; then
		systemctl daemon-reload
  		systemctl enable sing-box.service
    		systemctl enable s-ui.service 
	fi
	
	# Before starting s-ui, ensure nginx is running on port 2096
	if ! systemctl is-active --quiet nginx; then
		msg_err "Nginx is not running before s-ui start. Starting nginx..."
		systemctl start nginx
		sleep 2
	fi
	
	# Verify nginx has port 2096
	if ! lsof -Pi :2096 -sTCP:LISTEN -c nginx >/dev/null 2>&1; then
		msg_err "Warning: Nginx is not listening on port 2096. The subscription service requires this."
		msg_inf "Attempting to restart nginx..."
		systemctl restart nginx
		sleep 2
	fi
	
	msg_inf "Starting s-ui service..."
	s-ui restart
	# Wait for service to fully start (allowing up to 5 seconds for initialization)
	sleep 5
fi
######################Wait for service to be ready##################
# Wait up to 30 seconds for the service to become active
SERVICE_STARTED=false
for i in {1..30}; do
	if systemctl is-active --quiet s-ui; then
		msg_inf "s-ui service is now running"
		SERVICE_STARTED=true
		break
	fi
	
	# Check if s-ui failed due to port conflict
	if systemctl is-failed --quiet s-ui; then
		msg_err "s-ui service failed to start. Checking for port conflicts..."
		
		# Check recent logs for port 2096 error
		if journalctl -u s-ui -n 20 --no-pager | grep -q "listen tcp.*:2096.*address already in use"; then
			msg_err "ERROR: s-ui is trying to bind to port 2096, which is already used by nginx!"
			msg_err "This is a configuration issue with s-ui."
			msg_err ""
			msg_err "SOLUTION:"
			msg_err "1. Stop both services:"
			msg_err "   systemctl stop s-ui nginx"
			msg_err "2. Check s-ui database for port 2096 configuration:"
			msg_err "   sqlite3 /usr/local/s-ui/db/s-ui.db \"SELECT * FROM settings WHERE value='2096';\""
			msg_err "3. Check for inbounds using port 2096:"
			msg_err "   sqlite3 /usr/local/s-ui/db/s-ui.db \"SELECT * FROM inbounds WHERE CAST(port AS INTEGER)=2096;\""
			msg_err "4. Remove any port 2096 configurations and restart:"
			msg_err "   systemctl start nginx && systemctl start s-ui"
			msg_err ""
			msg_err "For support, visit: https://github.com/alireza0/s-ui"
			exit 1
		fi
		break
	fi
	
	sleep 1
done

# Check if service failed to start
if [ "$SERVICE_STARTED" = false ]; then
	msg_err "s-ui service failed to start after 30 seconds."
	msg_err "Checking for port conflicts..."
	
	# Check if nginx is still running
	if ! systemctl is-active --quiet nginx; then
		msg_err "Nginx has stopped running. This may indicate a port conflict."
	fi
	
	# Check port 2096 specifically since that's a common issue
	if lsof -Pi :2096 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
		msg_err "Port 2096 is in use by:"
		lsof -Pi :2096 -sTCP:LISTEN 2>/dev/null || netstat -tlnp | grep ":2096 "
	fi
	
	msg_err "Recent s-ui service logs:"
	journalctl -u s-ui -n 20 --no-pager
	
	msg_err "Please check logs with: journalctl -u s-ui -n 50"
	exit 1
fi

# Verify nginx is still running after s-ui started
if ! systemctl is-active --quiet nginx; then
	msg_err "Warning: Nginx stopped after s-ui started. Attempting to restart..."
	systemctl start nginx
	sleep 2
	if ! systemctl is-active --quiet nginx; then
		msg_err "Nginx failed to restart. There may be a port conflict with s-ui."
		msg_err "Check nginx logs with: journalctl -u nginx -n 50"
	fi
fi
######################cronjob for reload service##################
crontab -l | grep -v "s-ui" | crontab -
(crontab -l 2>/dev/null; echo '0 1 * * * s-ui restart > /dev/null 2>&1 && nginx -s reload;') | crontab -
##################################Show Details############################
SUIPORT=$(sqlite3 -list $SUIDB 'SELECT "value" FROM settings WHERE "key"="webPort" LIMIT 1;' 2>&1)
if systemctl is-active --quiet s-ui && [[ $SUIPORT -eq $PORT ]]; then clear
	printf '0\n' | s-ui | grep --color=never -i ':'
	msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	nginx -T | grep -i 'ssl_certificate\|ssl_certificate_key'
	msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	msg_inf "\nMain VPN Domain: https://${domain}/${RNDSTR}"
	msg_inf "Subscription URL: https://${subdomain}:2096/sub/USERNAME?format=json\n"
 	echo -n "Username:  " && sqlite3 $SUIDB 'SELECT "username" FROM users;'
	echo -n "Password:  " && sqlite3 $SUIDB 'SELECT "password" FROM users;'
	msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	msg_inf "Please Save this Screen!!"
else
	nginx -t && printf '0\n' | s-ui | grep --color=never -i ':'
	msg_err "sqlite and s-ui to be checked, try on a new clean linux! "
fi
#####N-joy##### 
