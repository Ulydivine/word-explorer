# Word Explorer Deployment Script
# This script helps deploy the Word Explorer application

param(
    [string]$DockerUsername = "",
    [string]$Action = "build"
)

Write-Host "🌟 Word Explorer Deployment Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

switch ($Action.ToLower()) {
    "build" {
        Write-Host "🔨 Building Docker image..." -ForegroundColor Yellow
        docker build -t word-explorer:v1 .
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Docker image built successfully!" -ForegroundColor Green
            Write-Host "📦 Image name: word-explorer:v1" -ForegroundColor Blue
        } else {
            Write-Host "❌ Failed to build Docker image" -ForegroundColor Red
            exit 1
        }
    }
    
    "test" {
        Write-Host "🧪 Testing the application locally..." -ForegroundColor Yellow
        
        # Stop any existing container
        docker stop word-explorer-local 2>$null
        docker rm word-explorer-local 2>$null
        
        # Run the container
        Write-Host "🚀 Starting container on port 8080..." -ForegroundColor Blue
        docker run -d -p 8080:8080 --name word-explorer-local word-explorer:v1
        
        if ($LASTEXITCODE -eq 0) {
            Start-Sleep -Seconds 3
            
            # Test health endpoint
            Write-Host "🔍 Testing health endpoint..." -ForegroundColor Blue
            try {
                $healthResponse = Invoke-WebRequest -Uri "http://localhost:8080/health" -TimeoutSec 10
                if ($healthResponse.StatusCode -eq 200) {
                    Write-Host "✅ Health check passed!" -ForegroundColor Green
                } else {
                    Write-Host "❌ Health check failed!" -ForegroundColor Red
                }
            } catch {
                Write-Host "❌ Could not reach health endpoint: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Test main page
            Write-Host "🔍 Testing main application..." -ForegroundColor Blue
            try {
                $mainResponse = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 10
                if ($mainResponse.Content -like "*Word Explorer*") {
                    Write-Host "✅ Main application is working!" -ForegroundColor Green
                    Write-Host "🌐 Application available at: http://localhost:8080" -ForegroundColor Cyan
                } else {
                    Write-Host "❌ Main application test failed!" -ForegroundColor Red
                }
            } catch {
                Write-Host "❌ Could not reach main application: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Write-Host ""
            Write-Host "Container is running. To stop it, run:" -ForegroundColor Yellow
            Write-Host "docker stop word-explorer-local && docker rm word-explorer-local" -ForegroundColor Gray
        } else {
            Write-Host "❌ Failed to start container" -ForegroundColor Red
        }
    }
    
    "push" {
        if (-not $DockerUsername) {
            Write-Host "❌ Docker username required for push action" -ForegroundColor Red
            Write-Host "Usage: .\deploy.ps1 -Action push -DockerUsername your-username" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "🏷️ Tagging image for Docker Hub..." -ForegroundColor Yellow
        docker tag word-explorer:v1 "$DockerUsername/word-explorer:v1"
        docker tag word-explorer:v1 "$DockerUsername/word-explorer:latest"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Images tagged successfully!" -ForegroundColor Green
            Write-Host "📤 Pushing to Docker Hub..." -ForegroundColor Yellow
            
            docker push "$DockerUsername/word-explorer:v1"
            docker push "$DockerUsername/word-explorer:latest"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Images pushed successfully!" -ForegroundColor Green
                Write-Host "🔗 Docker Hub URL: https://hub.docker.com/r/$DockerUsername/word-explorer" -ForegroundColor Cyan
            } else {
                Write-Host "❌ Failed to push images to Docker Hub" -ForegroundColor Red
                Write-Host "💡 Make sure you're logged in: docker login" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ Failed to tag images" -ForegroundColor Red
        }
    }
    
    "clean" {
        Write-Host "🧹 Cleaning up containers and images..." -ForegroundColor Yellow
        
        # Stop and remove containers
        docker stop word-explorer-local 2>$null
        docker rm word-explorer-local 2>$null
        
        # Remove images
        docker rmi word-explorer:v1 2>$null
        if ($DockerUsername) {
            docker rmi "$DockerUsername/word-explorer:v1" 2>$null
            docker rmi "$DockerUsername/word-explorer:latest" 2>$null
        }
        
        Write-Host "✅ Cleanup completed!" -ForegroundColor Green
    }
    
    "stop" {
        Write-Host "🛑 Stopping local test container..." -ForegroundColor Yellow
        docker stop word-explorer-local 2>$null
        docker rm word-explorer-local 2>$null
        Write-Host "✅ Container stopped!" -ForegroundColor Green
    }
    
    default {
        Write-Host "🤔 Unknown action: $Action" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available actions:" -ForegroundColor Yellow
        Write-Host "  build  - Build the Docker image" -ForegroundColor White
        Write-Host "  test   - Test the application locally" -ForegroundColor White
        Write-Host "  push   - Push to Docker Hub (requires -DockerUsername)" -ForegroundColor White
        Write-Host "  clean  - Clean up containers and images" -ForegroundColor White
        Write-Host "  stop   - Stop the local test container" -ForegroundColor White
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\deploy.ps1 -Action build" -ForegroundColor Gray
        Write-Host "  .\deploy.ps1 -Action test" -ForegroundColor Gray
        Write-Host "  .\deploy.ps1 -Action push -DockerUsername myusername" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🎉 Script completed!" -ForegroundColor Green
