#!/bin/bash

# ScholarAI API Gateway - Local Development Script
# This script provides a robust way to build, run, and test the Spring Boot application

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="api_gateway"
DEFAULT_PORT="8989"
JAR_NAME="${APP_NAME}-0.0.1-SNAPSHOT.jar"
PID_FILE="${PROJECT_ROOT}/target/${APP_NAME}.pid"
LOG_FILE="${PROJECT_ROOT}/target/${APP_NAME}.log"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check Java
    if ! command_exists java; then
        missing_deps+=("Java")
    else
        local java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [[ "$java_version" -lt 21 ]]; then
            print_warning "Java version $java_version detected. This project requires Java 21+"
        else
            print_success "Java $java_version found"
        fi
    fi
    
    # Check Maven
    if ! command_exists mvn; then
        missing_deps+=("Maven")
    else
        print_success "Maven found"
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "${PROJECT_ROOT}/pom.xml" ]]; then
        print_error "pom.xml not found. Please run this script from the project root directory."
        exit 1
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Please install the missing dependencies and try again."
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Function to clean the project
clean_project() {
    print_status "Cleaning project..."
    cd "$PROJECT_ROOT"
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "Application is still running (PID: $pid). Stopping it first..."
            kill "$pid" || true
            sleep 2
        fi
        rm -f "$PID_FILE"
    fi
    
    mvn clean
    print_success "Project cleaned"
}

# Function to build the project
build_project() {
    print_status "Building project..."
    cd "$PROJECT_ROOT"
    
    # Clean first
    clean_project
    
    # Build with tests
    if mvn clean compile test-compile; then
        print_success "Project compiled successfully"
    else
        print_error "Compilation failed"
        exit 1
    fi
    
    # Package the application
    if mvn package -DskipTests; then
        print_success "Application packaged successfully"
    else
        print_error "Packaging failed"
        exit 1
    fi
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    cd "$PROJECT_ROOT"
    
    if mvn test; then
        print_success "All tests passed"
    else
        print_error "Tests failed"
        exit 1
    fi
}

# Function to start the application
start_application() {
    print_status "Starting application..."
    cd "$PROJECT_ROOT"
    
    # Check if JAR exists
    if [[ ! -f "target/$JAR_NAME" ]]; then
        print_warning "JAR file not found. Building project first..."
        build_project
    fi
    
    # Check if application is already running
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "Application is already running (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    # Start the application
    print_status "Starting $APP_NAME on port $DEFAULT_PORT..."
    nohup java -jar "target/$JAR_NAME" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment for the application to start
    sleep 3
    
    # Check if the application started successfully
    if kill -0 "$pid" 2>/dev/null; then
        print_success "Application started successfully (PID: $pid)"
        print_status "Logs are being written to: $LOG_FILE"
        print_status "Application URL: http://localhost:$DEFAULT_PORT"
        print_status "Health check: http://localhost:$DEFAULT_PORT/actuator/health"
        print_status "API Documentation: http://localhost:$DEFAULT_PORT/swagger-ui.html"
    else
        print_error "Failed to start application"
        print_status "Check logs at: $LOG_FILE"
        exit 1
    fi
}

# Function to stop the application
stop_application() {
    print_status "Stopping application..."
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_status "Stopping process $pid..."
            kill "$pid"
            
            # Wait for graceful shutdown
            local count=0
            while kill -0 "$pid" 2>/dev/null && [[ $count -lt 30 ]]; do
                sleep 1
                ((count++))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                print_warning "Application didn't stop gracefully. Force killing..."
                kill -9 "$pid" 2>/dev/null || true
            fi
            
            print_success "Application stopped"
        else
            print_warning "Application is not running"
        fi
        
        rm -f "$PID_FILE"
    else
        print_warning "No PID file found. Application may not be running."
    fi
}

# Function to show application status
show_status() {
    print_status "Checking application status..."
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_success "Application is running (PID: $pid)"
            print_status "Application URL: http://localhost:$DEFAULT_PORT"
            
            # Try to get health status
            if command_exists curl; then
                local health_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$DEFAULT_PORT/actuator/health" 2>/dev/null || echo "000")
                if [[ "$health_status" == "200" ]]; then
                    print_success "Health check: OK"
                else
                    print_warning "Health check: Failed (HTTP $health_status)"
                fi
            fi
        else
            print_warning "PID file exists but application is not running"
            rm -f "$PID_FILE"
        fi
    else
        print_warning "Application is not running"
    fi
}

# Function to show logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        print_status "Showing application logs (last 50 lines):"
        echo "----------------------------------------"
        tail -n 50 "$LOG_FILE"
        echo "----------------------------------------"
        print_status "Full log file: $LOG_FILE"
    else
        print_warning "No log file found"
    fi
}

# Function to show help
show_help() {
    echo "ScholarAI API Gateway - Local Development Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build     Build the project (clean, compile, package)"
    echo "  test      Run all tests"
    echo "  start     Start the application"
    echo "  stop      Stop the application"
    echo "  restart   Restart the application"
    echo "  status    Show application status"
    echo "  logs      Show application logs"
    echo "  clean     Clean the project"
    echo "  all       Build, test, and start the application"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 start"
    echo "  $0 all"
    echo ""
}

# Main script logic
main() {
    # Check prerequisites first
    check_prerequisites
    
    # Parse command line arguments
    case "${1:-help}" in
        build)
            build_project
            ;;
        test)
            run_tests
            ;;
        start)
            start_application
            ;;
        stop)
            stop_application
            ;;
        restart)
            stop_application
            sleep 2
            start_application
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        clean)
            clean_project
            ;;
        all)
            build_project
            run_tests
            start_application
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Trap to ensure cleanup on script exit
trap 'print_status "Script interrupted. Cleaning up..."; stop_application' INT TERM

# Run main function with all arguments
main "$@"
