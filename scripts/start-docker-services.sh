#!/bin/bash

# Text formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define base directory paths
BASE_DIR="/home/tmone/opensea-qc"
SCRIPT_DIR="$BASE_DIR/scripts"

# Function to print section headers
print_header() {
  echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

# Function to check if a command succeeded
check_status() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ $1 succeeded${NC}"
    return 0
  else
    echo -e "${RED}✗ $1 failed${NC}"
    if [ "$2" = "exit" ]; then
      exit 1
    fi
    return 1
  fi
}

# Check if user has Docker permissions
check_docker_permissions() {
  # Try to run a simple Docker command
  docker info >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error: You don't have permission to access Docker.${NC}"
    echo -e "\nYou have three options to fix this:"
    echo -e "${YELLOW}1. Run this script with sudo:${NC}"
    echo -e "   sudo $0"
    echo -e "${YELLOW}2. Use the sudo environment script instead:${NC}"
    echo -e "   sudo $SCRIPT_DIR/start-qc-environment-sudo.sh"
    echo -e "${YELLOW}3. Add yourself to the docker group (permanent solution):${NC}"
    echo -e "   sudo usermod -aG docker $USER"
    echo -e "   Then log out and log back in."
    echo -e "\n${RED}Exiting...${NC}"
    exit 1
  fi
}

# Function to check and kill processes using specific ports
kill_process_on_port() {
  local port=$1
  local pid=$(lsof -i:"$port" -t)
  
  if [ -n "$pid" ]; then
    echo -e "${YELLOW}Process using port $port found (PID: $pid). Stopping...${NC}"
    kill -15 $pid 2>/dev/null || kill -9 $pid 2>/dev/null
    sleep 1
    if lsof -i:"$port" -t >/dev/null; then
      echo -e "${RED}Failed to stop process on port $port${NC}"
    else
      echo -e "${GREEN}Successfully freed port $port${NC}"
    fi
  else
    echo -e "${GREEN}No process using port $port${NC}"
  fi
}

print_header "STARTING DOCKER SERVICES FOR OPENSEA QC"

# Check Docker permissions before proceeding
check_docker_permissions

# Stop any existing docker containers
print_header "Stopping existing Docker services"
if [ -f "$BASE_DIR/docker/docker-compose.yml" ]; then
  cd "$BASE_DIR/docker"
  echo -e "${YELLOW}Stopping and removing existing containers...${NC}"
  docker-compose down
  check_status "Stopping existing Docker services"
  
  # For any containers that might not be removed
  echo -e "${YELLOW}Checking for any remaining containers...${NC}"
  if docker ps -a | grep 'opensea-' > /dev/null; then
    docker stop $(docker ps -a | grep 'opensea-' | awk '{print $1}') 2>/dev/null
    docker rm $(docker ps -a | grep 'opensea-' | awk '{print $1}') 2>/dev/null
    check_status "Removing remaining containers"
  else
    echo -e "${GREEN}No remaining containers found${NC}"
  fi
  
  cd "$BASE_DIR"
else
  echo -e "${RED}Docker compose file not found. Cannot stop existing containers...${NC}"
fi

# Check for and kill processes on relevant ports
print_header "Checking for processes on reserved ports"
# MongoDB
kill_process_on_port 27017
# PostgreSQL
kill_process_on_port 5432
# Redis
kill_process_on_port 6379
# Elasticsearch
kill_process_on_port 9200
# IPFS
kill_process_on_port 4001
kill_process_on_port 5001
kill_process_on_port 8080

# Start Docker containers
print_header "Starting Docker services"
if [ -f "$BASE_DIR/docker/docker-compose.yml" ]; then
  cd "$BASE_DIR/docker"
  docker-compose up -d
  if check_status "Docker services" "continue"; then
    echo -e "\n${GREEN}Docker services are now running${NC}"
    echo -e "- MongoDB: ${YELLOW}mongodb://localhost:27017${NC}"
    echo -e "- PostgreSQL: ${YELLOW}postgresql://opensea:yourpassword@localhost:5432/opensea_db${NC}"
    echo -e "- Redis: ${YELLOW}localhost:6379${NC}"
    echo -e "- Elasticsearch: ${YELLOW}http://localhost:9200${NC}"
    echo -e "- IPFS: ${YELLOW}http://localhost:5001${NC}"
  else
    echo -e "\n${RED}Error starting Docker services. Please check Docker logs for more information:${NC}"
    echo -e "${YELLOW}docker-compose logs${NC}"
  fi
  cd "$BASE_DIR"
else
  echo -e "${RED}Docker compose file not found. Skipping...${NC}"
fi

echo -e "\n${YELLOW}Now run ./scripts/start-blockchain.sh as your regular user to start the blockchain service${NC}"