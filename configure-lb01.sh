#!/bin/bash
# Configure HAProxy on Lb01

echo "🔧 Configuring load balancer on Lb01..."

# SSH into Lb01 and execute configuration
ssh lb-01 << 'EOF'
    echo "📋 Backing up existing HAProxy configuration..."
    sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    echo "📝 Creating new HAProxy configuration..."

# Create HAProxy configuration
cat > ~/haproxy.cfg << 'HAPROXY_CONFIG'
global
    daemon
    maxconn 4096
    log stdout local0

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option httplog
    log global

frontend web_frontend
    bind *:80
    default_backend word_explorer_backend

backend word_explorer_backend
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server web01 172.20.0.11:8080 check inter 3000 rise 2 fall 3
    server web02 172.20.0.12:8080 check inter 3000 rise 2 fall 3
HAPROXY_CONFIG

    sudo cp ~/haproxy.cfg /etc/haproxy/haproxy.cfg
    
    echo "🔍 Testing HAProxy configuration..."
    sudo haproxy -f /etc/haproxy/haproxy.cfg -c
    
    if [ $? -eq 0 ]; then
        echo "✅ HAProxy configuration is valid"
        
        echo "🔄 Reloading HAProxy..."
        if command -v systemctl > /dev/null; then
            sudo systemctl reload haproxy
        elif command -v service > /dev/null; then
            sudo service haproxy reload
        else
            # If running in Docker
            docker exec -it lb-01 sh -c 'haproxy -sf $(pidof haproxy) -f /etc/haproxy/haproxy.cfg' 2>/dev/null || true
        fi
        
        echo "✅ HAProxy reloaded successfully"
    else
        echo "❌ HAProxy configuration is invalid"
        exit 1
    fi

EOF

if [ $? -eq 0 ]; then
    echo "✅ Load balancer configuration successful!"
else
    echo "❌ Load balancer configuration failed!"
    exit 1
fi
