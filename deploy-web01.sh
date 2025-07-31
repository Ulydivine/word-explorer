#!/bin/bash
# Deploy Word Explorer on Web01

echo "🚀 Starting deployment on Web01..."

# SSH into Web01 and execute deployment
ssh web-01 << 'EOF'
    echo "📦 Pulling Docker image..."
    docker pull ulydivine/word-explorer:v1
    
    echo "🛑 Stopping any existing containers..."
    docker stop word-explorer 2>/dev/null || true
    docker rm word-explorer 2>/dev/null || true
    
    echo "🚀 Starting Word Explorer container..."
    docker run -d \
        --name word-explorer \
        --restart unless-stopped \
        -p 8080:8080 \
        ulydivine/word-explorer:v1
    
    echo "⏳ Waiting for container to start..."
    sleep 10
    
    echo "🔍 Verifying deployment..."
    
    # Check if container is running
    if docker ps | grep -q word-explorer; then
        echo "✅ Container is running"
    else
        echo "❌ Container failed to start"
        docker logs word-explorer
        exit 1
    fi
    
    # Test health endpoint
    echo "🏥 Testing health endpoint..."
    if curl -s http://localhost:8080/health | grep -q "healthy"; then
        echo "✅ Health check PASSED"
    else
        echo "❌ Health check FAILED"
        exit 1
    fi
    
    # Test main application
    echo "🌐 Testing main application..."
    if curl -s http://localhost:8080 | grep -q "Word Explorer"; then
        echo "✅ Application test PASSED"
    else
        echo "❌ Application test FAILED"
        exit 1
    fi
    
    echo "🎉 Web01 deployment completed successfully!"
    
    # Show container info
    echo "📊 Container Status:"
    docker ps | grep word-explorer
    
EOF

if [ $? -eq 0 ]; then
    echo "✅ Web01 deployment successful!"
else
    echo "❌ Web01 deployment failed!"
    exit 1
fi
