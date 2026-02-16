#!/bin/bash
############### s-ui-pro v1.2 @ github.com/GFW4Fun ##############
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
BaseDomain=$(echo "$domain" 2>&1 | sed 's/.*\.\([^.]*\.[^.]*\)$/\1/')
# Extract base domain from subscription domain (e.g., rqzbe.ir from sub.rqzbe.ir)
SubBaseDomain=$(echo "$subdomain" 2>&1 | sed 's/.*\.\([^.]*\.[^.]*\)$/\1/')

###############################Install Packages#############################
if [[ ${INSTALL} == *"y"* ]]; then
	$Pak -y update
	$Pak -y install nginx sqlite3 
	systemctl daemon-reload && systemctl enable --now nginx
fi
systemctl stop nginx 
fuser -k 80/tcp 80/udp 443/tcp 443/udp 2096/tcp 2096/udp 2>/dev/null
##############################SSL Certificate Paths####################################
# Using existing Cloudflare certificates
# Main domain cert path: /root/cert-CF/{BaseDomain}/
# Subscription domain cert path: /root/cert/{subdomain}/

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
# Main VPN domain configuration (port 443)
cat > "/etc/nginx/sites-available/$domain" << EOF
server {
	server_name $domain;
	listen 80;
	listen [::]:80;
	return 301 https://\$server_name\$request_uri;
}

server {
	server_name $domain;
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	http2_push_preload on;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_certificate /root/cert-CF/$BaseDomain/fullchain.pem;
	ssl_certificate_key /root/cert-CF/$BaseDomain/privkey.pem;
	
	location /$RNDSTR/ {
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:$PORT;
	}
	
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
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		if (\$content_type = "application/grpc") {
			grpc_pass grpc://127.0.0.1:\$fwdport;
			break;
		}
		if (\$http_upgrade = "websocket") {
			proxy_pass http://127.0.0.1:\$fwdport/\$fwdport/\$fwdpath;
			break;
		}	
	}
	
	location / { try_files \$uri \$uri/ =404; }
}
EOF

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
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:$PORT;
	}
}
EOF

###################################Enable Site###############################
if [[ -f "/etc/nginx/sites-available/$domain" ]] && [[ -f "/etc/nginx/sites-available/$subdomain" ]]; then
	unlink /etc/nginx/sites-enabled/default 2>/dev/null
	ln -sf "/etc/nginx/sites-available/$domain" /etc/nginx/sites-enabled/ 2>/dev/null
	ln -sf "/etc/nginx/sites-available/$subdomain" /etc/nginx/sites-enabled/ 2>/dev/null
	nginx -t && systemctl start nginx 
else
	msg_err "Nginx config files not created!" && exit 1
fi
###################################Update Db##################################
UPDATE_SUIDB(){
if [[ -f $SUIDB ]]; then
	sqlite3 $SUIDB <<EOF
	DELETE FROM "settings" WHERE ( "key"="webPort" ) OR ( "key"="webCertFile" ) OR ( "key"="webKeyFile" ) OR ( "key"="webPath" ); 
	INSERT INTO "settings" ("key", "value") VALUES ("webPort",  "${PORT}");
	INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  "");
	INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile", "");
	INSERT INTO "settings" ("key", "value") VALUES ("webPath", "/${RNDSTR}/");
EOF
else
	msg_err "s-ui.db file not exist! Maybe s-ui isn't installed." && exit 1;
fi
}
###################################Install Panel#########################
if systemctl is-active --quiet s-ui; then
	UPDATE_SUIDB
	s-ui restart
else
	printf 'n\n' | bash <(wget -qO- "https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh") $SUI_VERSION
	
	UPDATE_SUIDB
	if ! systemctl is-enabled --quiet s-ui; then
		systemctl daemon-reload
  		systemctl enable sing-box.service
    		systemctl enable s-ui.service 
	fi
	s-ui restart
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
