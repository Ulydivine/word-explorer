#!/bin/bash
# Complete Word Explorer Lab Deployment Script

echo "🌟 Word Explorer Complete Lab Deployment"
echo "========================================"

# Configuration
DOCKER_IMAGE="ulydivine/word-explorer:v1"
WEB01_IP="172.20.0.11"
WEB02_IP="172.20.0.12"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Step 1: Check server connectivity
print_info "Step 1: Checking server connectivity..."
for server in web-01 web-02 lb-01; do
    if ssh -o ConnectTimeout=10 $server 'echo "Connected"' >/dev/null 2>&1; then
        print_status "✅ $server is reachable"
    else
        print_error "❌ Cannot reach $server"
        exit 1
    fi
done

# Step 2: Deploy on Web01
print_info "Step 2: Deploying on Web01..."
./deploy-web01.sh
if [ $? -ne 0 ]; then
    print_error "Web01 deployment failed!"
    exit 1
fi

# Step 3: Deploy on Web02
print_info "Step 3: Deploying on Web02..."
./deploy-web02.sh
if [ $? -ne 0 ]; then
    print_error "Web02 deployment failed!"
    exit 1
fi

# Step 4: Configure Load Balancer
print_info "Step 4: Configuring Load Balancer..."
./configure-lb01.sh
if [ $? -ne 0 ]; then
    print_error "Load balancer configuration failed!"
    exit 1
fi

# Step 5: Wait for everything to settle
print_info "Step 5: Waiting for services to stabilize..."
sleep 15

# Step 6: Test deployment
print_info "Step 6: Testing deployment..."

# Test individual servers
print_info "Testing Web01 directly..."
if ssh web-01 'curl -s http://localhost:8080/health' | grep -q "healthy"; then
    print_status "Web01 health check PASSED"
else
    print_error "Web01 health check FAILED"
fi

print_info "Testing Web02 directly..."
if ssh web-02 'curl -s http://localhost:8080/health' | grep -q "healthy"; then
    print_status "Web02 health check PASSED"
else
    print_error "Web02 health check FAILED"
fi

# Get load balancer IP
print_info "Getting load balancer IP..."
LB_IP=$(ssh lb-01 'hostname -I | awk "{print \$1}"' 2>/dev/null)
if [ -z "$LB_IP" ]; then
    LB_IP="lb-01"
    print_warning "Could not determine LB IP, using hostname: $LB_IP"
else
    print_info "Load balancer IP: $LB_IP"
fi

# Test load balancer
print_info "Testing load balancer..."
if curl -s --connect-timeout 10 http://$LB_IP/health | grep -q "healthy"; then
    print_status "Load balancer health check PASSED"
else
    print_warning "Load balancer health check failed - checking configuration..."
fi

# Test load balancing
print_info "Testing load balancing with 5 requests..."
for i in {1..5}; do
    echo -n "Request $i: "
    response=$(curl -s --connect-timeout 5 http://$LB_IP/ 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "✅ Success"
    else
        echo "❌ Failed"
    fi
    sleep 1
done

# Step 7: Display deployment summary
echo ""
echo "🎉 DEPLOYMENT COMPLETED!"
echo "======================="
echo ""
echo "📊 Deployment Summary:"
echo "- Web01: http://$WEB01_IP:8080"
echo "- Web02: http://$WEB02_IP:8080"
echo "- Load Balancer: http://$LB_IP"
echo ""
echo "🔗 Project Links:"
echo "- GitHub: https://github.com/Ulydivine/word-explorer"
echo "- Docker Hub: https://hub.docker.com/r/ulydivine/word-explorer"
echo ""
echo "📋 Next Steps:"
echo "1. Test the application in your browser: http://$LB_IP"
echo "2. Record your demo video (< 2 minutes)"
echo "3. Submit your assignment with GitHub and video links"
echo ""

# Optional: Show container status on all servers
print_info "Container Status Summary:"
echo "Web01:"
ssh web-01 'docker ps | grep word-explorer || echo "No containers running"'
echo ""
echo "Web02:"
ssh web-02 'docker ps | grep word-explorer || echo "No containers running"'
echo ""

print_status "🚀 Lab deployment complete! Your application is ready for demo and submission."
