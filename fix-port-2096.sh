#!/bin/bash
############### s-ui Port 2096 Conflict Fixer ##############
# This script helps diagnose and fix port 2096 binding conflicts
# Run this if you're getting "listen tcp :2096: bind: address already in use" errors

[[ $EUID -ne 0 ]] && echo "Please run as root!" && exit 1

msg_ok() { echo -e "\e[1;42m $1 \e[0m";}
msg_err() { echo -e "\e[1;41m $1 \e[0m";}
msg_inf() { echo -e "\e[1;34m$1\e[0m";}

echo
msg_inf "╔═╗   ╦ ╦╦   ╔═╗╔═╗╦═╗╔╦╗  ╔═╗╦═╗ ╦╔═╗╦═╗"
msg_inf "╚═╗───║ ║║───╠═╝║ ║╠╦╝ ║───╠╣ ║╔╝ ║╣ ╠╦╝"
msg_inf "╚═╝   ╚═╝╩   ╩  ╚═╝╩╚═ ╩   ╚  ╩╚═╩╚═╝╩╚═"
echo

SUIDB="/usr/local/s-ui/db/s-ui.db"

# Check if s-ui is installed
if [[ ! -f $SUIDB ]]; then
    msg_err "s-ui database not found at $SUIDB"
    msg_err "Is s-ui installed?"
    exit 1
fi

msg_inf "Step 1: Checking what's using port 2096..."
if lsof -Pi :2096 -sTCP:LISTEN >/dev/null 2>&1; then
    lsof -Pi :2096 -sTCP:LISTEN
    echo
else
    msg_ok "Port 2096 is currently free"
fi

msg_inf "Step 2: Checking s-ui service status..."
systemctl status s-ui --no-pager -l | head -20
echo

msg_inf "Step 3: Checking recent s-ui logs for port errors..."
if journalctl -u s-ui -n 30 --no-pager | grep -i "2096"; then
    echo
    msg_err "Found port 2096 references in s-ui logs"
else
    msg_ok "No port 2096 errors in recent logs"
fi
echo

msg_inf "Step 4: Checking s-ui database for port 2096 settings..."
echo "Port-related settings:"
sqlite3 $SUIDB "SELECT key, value FROM settings WHERE key LIKE '%port%' OR CAST(value AS TEXT)='2096';" 2>/dev/null || msg_err "Failed to query database"
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
    
    # Remove subscription port settings from database
    msg_inf "Removing subscription port settings from database..."
    sqlite3 $SUIDB "DELETE FROM settings WHERE key='subPort' OR key='subscriptionPort' OR key='subListenPort';" 2>/dev/null || true
    
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
