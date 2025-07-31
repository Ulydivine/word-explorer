# 🏗️ Lab Deployment Instructions

## Prerequisites
- Access to Web01, Web02, and Lb01 servers
- Docker installed on Web01 and Web02
- HAProxy configured on Lb01
- Network connectivity between servers

## 🚀 Step 1: Deploy on Web01

SSH into Web01 and run the following commands:

```bash
# Pull the Docker image
docker pull ulydivine/word-explorer:v1

# Stop any existing containers
docker stop word-explorer 2>/dev/null || true
docker rm word-explorer 2>/dev/null || true

# Run the application container
docker run -d \
  --name word-explorer \
  --restart unless-stopped \
  -p 8080:8080 \
  ulydivine/word-explorer:v1

# Verify the container is running
docker ps | grep word-explorer

# Test the application
curl http://localhost:8080/health
# Expected output: healthy

curl -s http://localhost:8080 | grep "Word Explorer"
# Should return HTML content with "Word Explorer" title
```

## 🚀 Step 2: Deploy on Web02

SSH into Web02 and run the same commands:

```bash
# Pull the Docker image
docker pull ulydivine/word-explorer:v1

# Stop any existing containers
docker stop word-explorer 2>/dev/null || true
docker rm word-explorer 2>/dev/null || true

# Run the application container
docker run -d \
  --name word-explorer \
  --restart unless-stopped \
  -p 8080:8080 \
  ulydivine/word-explorer:v1

# Verify the container is running
docker ps | grep word-explorer

# Test the application
curl http://localhost:8080/health
# Expected output: healthy
```

## 🚀 Step 3: Configure Load Balancer (Lb01)

### Option A: HAProxy Configuration

1. **Edit HAProxy configuration:**

```bash
# SSH into Lb01
ssh lb-01

# Backup existing configuration
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup

# Edit the configuration file
sudo nano /etc/haproxy/haproxy.cfg
```

2. **Add/update the configuration:**

```haproxy
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
```

3. **Reload HAProxy:**

```bash
# Test configuration syntax
sudo haproxy -f /etc/haproxy/haproxy.cfg -c

# If using Docker HAProxy
docker exec -it lb-01 sh -c 'haproxy -sf $(pidof haproxy) -f /etc/haproxy/haproxy.cfg'

# If using system HAProxy
sudo systemctl reload haproxy
# or
sudo service haproxy reload
```

### Option B: Nginx Load Balancer Configuration

If using Nginx instead of HAProxy:

```bash
# Create/edit Nginx configuration
sudo nano /etc/nginx/sites-available/word-explorer
```

```nginx
upstream word_explorer_backend {
    server 172.20.0.11:8080 max_fails=3 fail_timeout=30s;
    server 172.20.0.12:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://word_explorer_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Health check passthrough
        proxy_connect_timeout 5s;
        proxy_read_timeout 10s;
    }
    
    location /health {
        proxy_pass http://word_explorer_backend/health;
    }
}
```

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/word-explorer /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

## 🧪 Step 4: Testing the Deployment

### Test Individual Servers

```bash
# Test Web01 directly
curl http://172.20.0.11:8080/health
curl -s http://172.20.0.11:8080 | grep "Word Explorer"

# Test Web02 directly
curl http://172.20.0.12:8080/health
curl -s http://172.20.0.12:8080 | grep "Word Explorer"
```

### Test Load Balancer

```bash
# Test load balancer health
curl http://lb-01-ip/health

# Test round-robin load balancing
for i in {1..10}; do
    echo "Request $i:"
    curl -s http://lb-01-ip/ | grep -o "Server: nginx/[0-9.]*" || echo "Response received"
    sleep 1
done
```

### Browser Testing

1. Open your browser and navigate to the load balancer's IP address
2. Test the application functionality:
   - Search for words like "serendipity", "brilliant", "adventure"
   - Try the random word feature
   - Add words to favorites
   - Test the audio pronunciation feature
3. Refresh multiple times to verify load balancing

## 🔍 Troubleshooting

### Container Issues

```bash
# Check container logs
docker logs word-explorer

# Check container status
docker ps -a | grep word-explorer

# Restart container
docker restart word-explorer
```

### Network Issues

```bash
# Check if ports are open
netstat -tlnp | grep :8080

# Test connectivity between servers
ping 172.20.0.11
ping 172.20.0.12

# Check firewall rules (if applicable)
sudo ufw status
```

### Load Balancer Issues

```bash
# Check HAProxy status
sudo systemctl status haproxy

# Check HAProxy logs
sudo journalctl -u haproxy -f

# Test HAProxy configuration
sudo haproxy -f /etc/haproxy/haproxy.cfg -c
```

## 📊 Performance Monitoring

### Basic Monitoring Commands

```bash
# Monitor container resource usage
docker stats word-explorer

# Monitor server resources
htop
free -h
df -h

# Check HAProxy stats (if stats page is enabled)
curl http://lb-01-ip/stats
```

## 🔧 Maintenance

### Update Application

```bash
# Pull latest image
docker pull ulydivine/word-explorer:latest

# Rolling update (zero downtime)
# On Web01:
docker pull ulydivine/word-explorer:latest
docker stop word-explorer
docker rm word-explorer
docker run -d --name word-explorer --restart unless-stopped -p 8080:8080 ulydivine/word-explorer:latest

# Wait for health check, then repeat on Web02
```

### Backup and Recovery

```bash
# Backup HAProxy configuration
sudo cp /etc/haproxy/haproxy.cfg ~/haproxy-backup-$(date +%Y%m%d).cfg

# Save Docker image locally
docker save ulydivine/word-explorer:v1 | gzip > word-explorer-v1.tar.gz
```

## ✅ Deployment Checklist

- [ ] Web01: Container running and responding to health checks
- [ ] Web02: Container running and responding to health checks
- [ ] Load balancer: Configuration updated and reloaded
- [ ] Network connectivity: All servers can communicate
- [ ] Health checks: Load balancer can reach both backend servers
- [ ] Round-robin: Traffic is distributed between servers
- [ ] Application functionality: All features working through load balancer
- [ ] Performance: Response times are acceptable
- [ ] Monitoring: Basic monitoring in place

## 📋 Expected Results

After successful deployment:

1. **Individual Server Access:**
   - http://172.20.0.11:8080 → Web01 application
   - http://172.20.0.12:8080 → Web02 application

2. **Load Balanced Access:**
   - http://lb-01-ip → Alternates between Web01 and Web02

3. **Health Checks:**
   - All `/health` endpoints return "healthy" status

4. **Application Features:**
   - Word search functionality
   - Random word generation
   - Favorites and history management
   - Responsive design on all devices

## 🎯 Demo Preparation

For your demo video, show:

1. **Individual server access** - demonstrating each server works
2. **Load balancer functionality** - showing traffic distribution
3. **Application features** - word search, favorites, etc.
4. **Mobile responsiveness** - if possible
5. **Health monitoring** - showing health check endpoints

Remember to keep your demo under 2 minutes and focus on the key technical achievements!
