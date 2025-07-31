# 🚀 Step-by-Step Lab Deployment Commands

## Prerequisites
- Replace `WEB01_IP`, `WEB02_IP`, `LB01_IP` with actual server IPs
- Ensure you have SSH access to all servers
- Have your SSH key or password ready

## Step 1: Deploy on Web01

### Connect to Web01:
```bash
ssh username@WEB01_IP
# OR
ssh web-01  # if hostname is configured
```

### Once connected to Web01, run these commands:
```bash
# Pull the Docker image
docker pull ulydivine/word-explorer:v1

# Stop any existing containers
docker stop word-explorer 2>/dev/null || true
docker rm word-explorer 2>/dev/null || true

# Run the new container
docker run -d \
    --name word-explorer \
    --restart unless-stopped \
    -p 8080:8080 \
    ulydivine/word-explorer:v1

# Wait for container to start
sleep 10

# Verify deployment
docker ps | grep word-explorer
curl http://localhost:8080/health
curl -s http://localhost:8080 | grep "Word Explorer"

# Exit Web01
exit
```

## Step 2: Deploy on Web02

### Connect to Web02:
```bash
ssh username@WEB02_IP
# OR
ssh web-02  # if hostname is configured
```

### Once connected to Web02, run these commands:
```bash
# Pull the Docker image
docker pull ulydivine/word-explorer:v1

# Stop any existing containers
docker stop word-explorer 2>/dev/null || true
docker rm word-explorer 2>/dev/null || true

# Run the new container
docker run -d \
    --name word-explorer \
    --restart unless-stopped \
    -p 8080:8080 \
    ulydivine/word-explorer:v1

# Wait for container to start
sleep 10

# Verify deployment
docker ps | grep word-explorer
curl http://localhost:8080/health
curl -s http://localhost:8080 | grep "Word Explorer"

# Exit Web02
exit
```

## Step 3: Configure Load Balancer (Lb01)

### Connect to Lb01:
```bash
ssh username@LB01_IP
# OR
ssh lb-01  # if hostname is configured
```

### Once connected to Lb01, run these commands:

#### 3.1: Backup existing configuration
```bash
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup.$(date +%Y%m%d_%H%M%S)
```

#### 3.2: Create new HAProxy configuration
```bash
cat > ~/haproxy.cfg << 'EOF'
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
    server web01 WEB01_IP:8080 check inter 3000 rise 2 fall 3
    server web02 WEB02_IP:8080 check inter 3000 rise 2 fall 3
EOF
```

**⚠️ IMPORTANT: Replace `WEB01_IP` and `WEB02_IP` with actual IP addresses in the config above!**

#### 3.3: Apply the configuration
```bash
# Copy configuration to HAProxy directory
sudo cp ~/haproxy.cfg /etc/haproxy/haproxy.cfg

# Test configuration
sudo haproxy -f /etc/haproxy/haproxy.cfg -c

# If test passes, reload HAProxy
sudo systemctl reload haproxy
# OR if systemctl doesn't work:
sudo service haproxy reload
```

#### 3.4: Verify HAProxy is running
```bash
sudo systemctl status haproxy
# OR
sudo service haproxy status
```

## Step 4: Test the Complete Deployment

### From your local machine or any server:

#### Test individual servers:
```bash
# Test Web01 directly
curl http://WEB01_IP:8080/health
curl http://WEB01_IP:8080/

# Test Web02 directly  
curl http://WEB02_IP:8080/health
curl http://WEB02_IP:8080/

# Test Load Balancer
curl http://LB01_IP/health
curl http://LB01_IP/
```

#### Test load balancing (run multiple times):
```bash
for i in {1..5}; do
    echo "Request $i:"
    curl http://LB01_IP/ | head -1
    sleep 1
done
```

## Step 5: Browser Testing

1. **Open your web browser**
2. **Navigate to**: `http://LB01_IP`
3. **Test application features**:
   - Search for words like "serendipity", "brilliant"
   - Try random word feature
   - Add words to favorites
   - Test audio pronunciation

## 🔍 Troubleshooting Commands

### If containers aren't starting:
```bash
# Check Docker logs
docker logs word-explorer

# Check Docker status
docker ps -a

# Restart Docker if needed
sudo systemctl restart docker
```

### If HAProxy isn't working:
```bash
# Check HAProxy logs
sudo journalctl -u haproxy -f

# Check HAProxy configuration
sudo haproxy -f /etc/haproxy/haproxy.cfg -c

# Check if ports are open
netstat -tlnp | grep :80
netstat -tlnp | grep :8080
```

### If servers can't communicate:
```bash
# Test network connectivity
ping WEB01_IP
ping WEB02_IP

# Test from load balancer to web servers
curl http://WEB01_IP:8080/health
curl http://WEB02_IP:8080/health
```

## ✅ Success Indicators

You know the deployment is successful when:

- [ ] ✅ Web01 responds: `curl http://WEB01_IP:8080/health` returns "healthy"
- [ ] ✅ Web02 responds: `curl http://WEB02_IP:8080/health` returns "healthy"
- [ ] ✅ Load balancer responds: `curl http://LB01_IP/health` returns "healthy"
- [ ] ✅ Application loads in browser at `http://LB01_IP`
- [ ] ✅ Multiple requests show traffic distribution between servers
- [ ] ✅ All application features work (search, favorites, etc.)

## 📋 What You Need Before Starting

1. **Server Information**:
   - Web01 IP address or hostname
   - Web02 IP address or hostname  
   - Lb01 IP address or hostname
   - SSH username and authentication method

2. **Access Requirements**:
   - SSH access to all three servers
   - Sudo privileges on Lb01 for HAProxy configuration
   - Docker installed and running on Web01 and Web02

3. **Network Requirements**:
   - Servers can reach Docker Hub to pull images
   - Load balancer can reach both web servers on port 8080
   - Your browser can reach the load balancer on port 80

## 🎬 Ready for Demo Video

Once deployment is complete, you can record your demo video showing:
1. Application working through load balancer
2. Key features (search, favorites, random words)
3. Multiple servers handling requests
4. Health monitoring working

**Your deployment is ready! Let me know if you encounter any issues with these steps.**
