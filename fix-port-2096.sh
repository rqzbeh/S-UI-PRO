#!/bin/bash
############### s-ui Port Configuration Helper ##############
# This script helps configure s-ui to avoid port conflicts
# The new setup uses only ports 80 and 443 (standard HTTPS)

[[ $EUID -ne 0 ]] && echo "Please run as root!" && exit 1

msg_ok() { echo -e "\e[1;42m $1 \e[0m";}
msg_err() { echo -e "\e[1;41m $1 \e[0m";}
msg_inf() { echo -e "\e[1;34m$1\e[0m";}

echo
msg_inf "╔═╗   ╦ ╦╦   ╔═╗╔═╗╦═╗╔╦╗  ╦ ╦╔═╗╦  ╔═╗╔═╗╦═╗"
msg_inf "╚═╗───║ ║║───╠═╝║ ║╠╦╝ ║───╠═╣║╣ ║  ╠═╝║╣ ╠╦╝"
msg_inf "╚═╝   ╚═╝╩   ╩  ╚═╝╩╚═ ╩   ╩ ╩╚═╝╩═╝╩  ╚═╝╩╚═"
echo

SUIDB="/usr/local/s-ui/db/s-ui.db"

# Check if s-ui is installed
if [[ ! -f $SUIDB ]]; then
    msg_err "s-ui database not found at $SUIDB"
    msg_err "Is s-ui installed?"
    exit 1
fi

msg_inf "Current Configuration Overview"
msg_inf "=============================="
echo

msg_inf "Port Usage:"
echo "- Port 80:  HTTP (redirects to HTTPS)"
echo "- Port 443: HTTPS (handles BOTH main and subscription domains via SNI)"
echo

msg_inf "How it works:"
echo "1. Nginx listens on port 443"
echo "2. Uses SNI (Server Name Indication) to route by domain:"
echo "   - Main domain → s-ui web panel (internal port)"
echo "   - Sub domain  → s-ui subscription service (internal port)"
echo "3. s-ui runs on internal ports only (NO external port binding)"
echo

msg_inf "Checking s-ui service status..."
systemctl status s-ui --no-pager -l | head -15
echo
echo

echo "Inbounds using port 2096:"
INBOUNDS_2096=$(sqlite3 $SUIDB "SELECT COUNT(*) FROM inbounds WHERE CAST(port AS INTEGER)=2096;" 2>/dev/null || echo "0")
if [ "$INBOUNDS_2096" != "0" ]; then
    msg_err "Found $INBOUNDS_2096 inbound(s) using port 2096:"
    sqlite3 $SUIDB "SELECT id, remark, port, listen FROM inbounds WHERE CAST(port AS INTEGER)=2096;" 2>/dev/null
    echo
    msg_err "These inbounds will conflict with nginx on port 2096!"
    msg_inf "You should change them to use different ports (e.g., 10001, 10002, etc.)"
else
    msg_ok "No inbounds configured to use port 2096"
fi
echo

msg_inf "Step 5: Checking nginx status..."
systemctl status nginx --no-pager | head -10
echo

# Offer to fix
echo
msg_inf "Would you like to attempt an automatic fix? (y/n)"
read -r AUTOFIX

if [[ $AUTOFIX == "y" ]] || [[ $AUTOFIX == "Y" ]]; then
    msg_inf "Applying automatic fixes..."
    
    # Stop services
    msg_inf "Stopping services..."
    systemctl stop s-ui
    systemctl stop nginx
    sleep 2
    
    # Kill anything still on port 2096
    msg_inf "Killing processes on port 2096..."
    fuser -k 2096/tcp 2>/dev/null || true
    sleep 1
    
    # Generate a random internal port for s-ui's subscription service
    while true; do 
        SUBPORT=$(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 ))
        status="$(nc -z 127.0.0.1 $SUBPORT < /dev/null &>/dev/null; echo $?)"
        if [ "${status}" != "0" ]; then
            break
        fi
    done
    
    # Configure s-ui's subscription service to use internal port
    msg_inf "Configuring s-ui subscription service on internal port ${SUBPORT}..."
    msg_inf "(Nginx will handle external port 2096 and proxy to s-ui)"
    sqlite3 $SUIDB <<SQLEOF
    DELETE FROM "settings" WHERE ( "key"="subPort" ) OR ( "key"="subCertFile" ) OR ( "key"="subKeyFile" );
    INSERT INTO "settings" ("key", "value") VALUES ("subPort",  "${SUBPORT}");
    INSERT INTO "settings" ("key", "value") VALUES ("subCertFile",  "");
    INSERT INTO "settings" ("key", "value") VALUES ("subKeyFile", "");
SQLEOF
    
    # Update any inbounds using port 2096
    if [ "$INBOUNDS_2096" != "0" ]; then
        msg_err "WARNING: Cannot automatically fix inbounds using port 2096"
        msg_err "Please manually change these inbounds to use different ports in the s-ui panel"
        msg_err "After fixing inbounds, run: systemctl restart s-ui"
    fi
    
    # Start nginx first (it should own port 2096)
    msg_inf "Starting nginx (should bind to port 2096)..."
    systemctl start nginx
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        msg_ok "Nginx started successfully"
        
        if lsof -Pi :2096 -sTCP:LISTEN -c nginx >/dev/null 2>&1; then
            msg_ok "Nginx is now listening on port 2096"
        else
            msg_err "Nginx is running but not listening on port 2096"
            msg_err "Check nginx configuration: /etc/nginx/sites-enabled/"
        fi
    else
        msg_err "Nginx failed to start"
        systemctl status nginx --no-pager
        exit 1
    fi
    
    # Start s-ui
    msg_inf "Starting s-ui service..."
    systemctl start s-ui
    sleep 3
    
    if systemctl is-active --quiet s-ui; then
        msg_ok "s-ui started successfully"
    else
        msg_err "s-ui failed to start"
        journalctl -u s-ui -n 20 --no-pager
        exit 1
    fi
    
    echo
    msg_ok "Fix attempt completed!"
    msg_inf "Checking final status..."
    echo
    
    systemctl status nginx --no-pager | head -5
    echo
    systemctl status s-ui --no-pager | head -5
    
else
    echo
    msg_inf "No automatic fixes applied."
    msg_inf "To manually fix:"
    msg_inf "1. systemctl stop s-ui nginx"
    msg_inf "2. fuser -k 2096/tcp"
    msg_inf "3. Fix any inbounds using port 2096 in s-ui database"
    msg_inf "4. systemctl start nginx"
    msg_inf "5. systemctl start s-ui"
fi

echo
msg_inf "Done!"
