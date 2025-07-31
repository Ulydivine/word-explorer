# 🔧 Manual Deployment Commands

## Quick Command Reference for Lab Deployment

### Step 1: Deploy on Web01

```bash
# SSH into Web01
ssh web-01

# Pull the Docker image
docker pull ulydivine/word-explorer:v1

# Stop any existing container
docker stop word-explorer 2>/dev/null || true
docker rm word-explorer 2>/dev/null || true

# Run the container
docker run -d \
  --name word-explorer \
  --restart unless-stopped \
  -p 8080:8080 \
  ulydivine/word-explorer:v1

# Verify deployment
docker ps | grep word-explorer
curl http://localhost:8080/health
curl -s http://localhost:8080 | grep "Word Explorer"

# Exit Web01
exit
```

### Step 2: Deploy on Web02

```bash
# SSH into Web02
ssh web-02

# Pull the Docker image
docker pull ulydivine/word-explorer:v1

# Stop any existing container
docker stop word-explorer 2>/dev/null || true
docker rm word-explorer 2>/dev/null || true

# Run the container
docker run -d \
  --name word-explorer \
  --restart unless-stopped \
  -p 8080:8080 \
  ulydivine/word-explorer:v1

# Verify deployment
docker ps | grep word-explorer
curl http://localhost:8080/health
curl -s http://localhost:8080 | grep "Word Explorer"

# Exit Web02
exit
```

### Step 3: Configure Load Balancer

```bash
# SSH into Lb01
ssh lb-01

# Backup existing configuration
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup

# Edit HAProxy configuration
sudo nano /etc/haproxy/haproxy.cfg
```

**Add this configuration:**

```haproxy
global
    daemon
    maxconn 4096

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend web_frontend
    bind *:80
    default_backend word_explorer_backend

backend word_explorer_backend
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server web01 172.20.0.11:8080 check inter 3000 rise 2 fall 3
    server web02 172.20.0.12:8080 check inter 3000 rise 2 fall 3
```

**Then continue:**

```bash
# Test configuration
sudo haproxy -f /etc/haproxy/haproxy.cfg -c

# Reload HAProxy
sudo systemctl reload haproxy
# OR
sudo service haproxy reload
# OR (if using Docker)
docker exec -it lb-01 sh -c 'haproxy -sf $(pidof haproxy) -f /etc/haproxy/haproxy.cfg'

# Exit Lb01
exit
```

### Step 4: Test Deployment

```bash
# Test individual servers
ssh web-01 'curl -s http://localhost:8080/health'
ssh web-02 'curl -s http://localhost:8080/health'

# Test load balancer (replace with actual LB IP)
curl http://YOUR_LB_IP/health

# Test load balancing with multiple requests
for i in {1..5}; do
  echo "Request $i:"
  curl -s http://YOUR_LB_IP/ | head -1
  sleep 1
done
```

## 🚀 Alternative: Using the Automated Script

If you prefer automation, make the script executable and run it:

```bash
chmod +x deploy-to-lab.sh
./deploy-to-lab.sh
```

## 🔍 Troubleshooting Commands

### Check Container Status
```bash
# On Web01 or Web02
docker ps -a | grep word-explorer
docker logs word-explorer
```

### Check Network Connectivity
```bash
# Test from load balancer to web servers
ssh lb-01
curl http://172.20.0.11:8080/health
curl http://172.20.0.12:8080/health
```

### Check HAProxy Status
```bash
# On Lb01
sudo systemctl status haproxy
sudo journalctl -u haproxy -f
```

### Check Ports
```bash
# On any server
netstat -tlnp | grep :8080
netstat -tlnp | grep :80
```

## ✅ Verification Checklist

After deployment, verify:

- [ ] Web01 container running: `ssh web-01 'docker ps | grep word-explorer'`
- [ ] Web02 container running: `ssh web-02 'docker ps | grep word-explorer'`
- [ ] Web01 health check: `ssh web-01 'curl -s http://localhost:8080/health'`
- [ ] Web02 health check: `ssh web-02 'curl -s http://localhost:8080/health'`
- [ ] Load balancer health: `curl http://YOUR_LB_IP/health`
- [ ] Application accessible: Browse to `http://YOUR_LB_IP`
- [ ] Load balancing working: Multiple requests show round-robin

## 📊 Expected Results

### Individual Server Access
- **Web01**: `http://172.20.0.11:8080` → Word Explorer app
- **Web02**: `http://172.20.0.12:8080` → Word Explorer app

### Load Balanced Access
- **Load Balancer**: `http://YOUR_LB_IP` → Alternates between Web01 and Web02

### Health Checks
- All `/health` endpoints should return: `healthy`

## 🎬 Demo Preparation

For your demo video, show:

1. **Browser access** to load balancer IP
2. **Word search functionality** (try "serendipity", "brilliant")
3. **Random word feature**
4. **Favorites functionality**
5. **Multiple requests** to show load balancing
6. **Health check endpoints**

Keep it under 2 minutes and focus on key features!
