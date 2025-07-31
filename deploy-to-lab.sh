#!/bin/bash

# Word Explorer Lab Deployment Script
# This script deploys the application to Web01, Web02, and configures Lb01

echo "🌟 Word Explorer Lab Deployment Starting..."
echo "============================================="

# Configuration
DOCKER_IMAGE="ulydivine/word-explorer:v1"
CONTAINER_NAME="word-explorer"
APP_PORT="8080"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to deploy on a web server
deploy_web_server() {
    local server=$1
    print_info "Deploying to $server..."
    
    # SSH into server and deploy
    ssh $server << EOF
        echo "📦 Pulling Docker image on $server..."
        docker pull $DOCKER_IMAGE
        
        echo "🛑 Stopping existing container (if any)..."
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
        
        echo "🚀 Starting new container..."
        docker run -d \\
            --name $CONTAINER_NAME \\
            --restart unless-stopped \\
            -p $APP_PORT:$APP_PORT \\
            $DOCKER_IMAGE
        
        echo "🔍 Verifying deployment..."
        sleep 5
        
        # Check if container is running
        if docker ps | grep -q $CONTAINER_NAME; then
            echo "✅ Container is running on $server"
        else
            echo "❌ Container failed to start on $server"
            exit 1
        fi
        
        # Test health endpoint
        if curl -s http://localhost:$APP_PORT/health | grep -q "healthy"; then
            echo "✅ Health check passed on $server"
        else
            echo "❌ Health check failed on $server"
            exit 1
        fi
        
        # Test main application
        if curl -s http://localhost:$APP_PORT | grep -q "Word Explorer"; then
            echo "✅ Application is working on $server"
        else
            echo "❌ Application test failed on $server"
            exit 1
        fi
        
        echo "🎉 Deployment successful on $server!"
EOF
    
    if [ $? -eq 0 ]; then
        print_status "Successfully deployed to $server"
    else
        print_error "Failed to deploy to $server"
        exit 1
    fi
}

# Function to configure load balancer
configure_load_balancer() {
    print_info "Configuring load balancer on lb-01..."
    
    # Create HAProxy configuration
    cat > haproxy.cfg << 'HAPROXY_CONFIG'
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
    
    # Optional: Add some basic monitoring
    stats enable
    stats uri /haproxy-stats
    stats refresh 30s

backend word_explorer_backend
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    
    # Health check every 3 seconds, mark server down after 3 failures, up after 2 successes
    server web01 172.20.0.11:8080 check inter 3000 rise 2 fall 3
    server web02 172.20.0.12:8080 check inter 3000 rise 2 fall 3
HAPROXY_CONFIG

    # Deploy to load balancer
    ssh lb-01 << 'EOF'
        echo "📋 Backing up existing HAProxy configuration..."
        sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        
        echo "📝 Updating HAProxy configuration..."
        # Copy the new configuration (assuming we transferred it)
        sudo cp ~/haproxy.cfg /etc/haproxy/haproxy.cfg
        
        echo "🔍 Testing HAProxy configuration..."
        sudo haproxy -f /etc/haproxy/haproxy.cfg -c
        
        if [ $? -eq 0 ]; then
            echo "✅ HAProxy configuration is valid"
            
            echo "🔄 Reloading HAProxy..."
            # Try different reload methods depending on the setup
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

    # Copy the configuration file to the load balancer
    scp haproxy.cfg lb-01:~/
    
    if [ $? -eq 0 ]; then
        print_status "Load balancer configured successfully"
    else
        print_error "Failed to configure load balancer"
        exit 1
    fi
    
    # Clean up local config file
    rm haproxy.cfg
}

# Function to test the complete deployment
test_deployment() {
    print_info "Testing complete deployment..."
    
    # Test individual servers
    print_info "Testing Web01 directly..."
    if ssh web-01 'curl -s http://localhost:8080/health' | grep -q "healthy"; then
        print_status "Web01 health check passed"
    else
        print_error "Web01 health check failed"
    fi
    
    print_info "Testing Web02 directly..."
    if ssh web-02 'curl -s http://localhost:8080/health' | grep -q "healthy"; then
        print_status "Web02 health check passed"
    else
        print_error "Web02 health check failed"
    fi
    
    # Test load balancer
    print_info "Testing load balancer..."
    
    # Get load balancer IP (you might need to adjust this)
    LB_IP=$(ssh lb-01 'hostname -I | awk "{print \$1}"' 2>/dev/null || echo "lb-01")
    
    print_info "Load balancer IP: $LB_IP"
    
    # Test health endpoint through load balancer
    if curl -s http://$LB_IP/health | grep -q "healthy"; then
        print_status "Load balancer health check passed"
    else
        print_warning "Load balancer health check failed - check configuration"
    fi
    
    # Test load balancing by making multiple requests
    print_info "Testing load balancing (making 10 requests)..."
    for i in {1..10}; do
        echo -n "Request $i: "
        curl -s http://$LB_IP/ | grep -o "Server: nginx/[0-9.]*" || echo "Response received"
        sleep 1
    done
}

# Main deployment sequence
main() {
    print_info "Starting Word Explorer deployment to lab servers..."
    
    # Check if we can reach the servers
    print_info "Checking server connectivity..."
    
    if ! ssh -o ConnectTimeout=5 web-01 'echo "Web01 reachable"' > /dev/null 2>&1; then
        print_error "Cannot reach web-01. Please check your SSH connection."
        exit 1
    fi
    
    if ! ssh -o ConnectTimeout=5 web-02 'echo "Web02 reachable"' > /dev/null 2>&1; then
        print_error "Cannot reach web-02. Please check your SSH connection."
        exit 1
    fi
    
    if ! ssh -o ConnectTimeout=5 lb-01 'echo "Lb01 reachable"' > /dev/null 2>&1; then
        print_error "Cannot reach lb-01. Please check your SSH connection."
        exit 1
    fi
    
    print_status "All servers are reachable"
    
    # Deploy to web servers
    deploy_web_server "web-01"
    deploy_web_server "web-02"
    
    # Configure load balancer
    configure_load_balancer
    
    # Test deployment
    sleep 10  # Wait for everything to settle
    test_deployment
    
    print_status "🎉 Deployment completed successfully!"
    print_info "Your application is now available through the load balancer"
    print_info "GitHub Repository: https://github.com/Ulydivine/word-explorer"
    print_info "Docker Hub: https://hub.docker.com/r/ulydivine/word-explorer"
    
    echo ""
    echo "📋 Next Steps:"
    echo "1. Test the application in your browser using the load balancer IP"
    echo "2. Record your demo video (< 2 minutes)"
    echo "3. Submit your assignment with the GitHub and video links"
}

# Run main function
main "$@"
