#!/bin/bash

# Text formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Define base directory paths
BASE_DIR="/home/tmone/opensea-qc"
SCRIPT_DIR="$BASE_DIR/scripts"
LOG_DIR="$SCRIPT_DIR/logs"

# Array to store PIDs of background processes
declare -a PIDS=()

# Function to handle script exit and cleanup
cleanup() {
  echo -e "\n${YELLOW}Shutting down UI services...${NC}"
  
  # Kill all background processes
  for pid in "${PIDS[@]}"; do
    if ps -p $pid > /dev/null; then
      echo -e "Stopping process ${YELLOW}$pid${NC}..."
      kill $pid 2>/dev/null
      # Also kill any child processes
      pkill -P $pid 2>/dev/null
    fi
  done
  
  echo -e "${GREEN}✓ UI services stopped${NC}"
  exit 0
}

# Register the cleanup function to be called on exit
trap cleanup SIGINT SIGTERM EXIT

# Function to print section headers
print_header() {
  echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

# Function to check if a command succeeded
check_status() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ $1 succeeded${NC}"
  else
    echo -e "${RED}✗ $1 failed${NC}"
    if [ "$2" = "exit" ]; then
      exit 1
    fi
  fi
}

# Function to run commands in background with log and add to monitoring
run_service() {
  local service_name=$1
  local command=$2
  local critical=$3
  
  echo -e "${YELLOW}Starting $service_name...${NC}"
  
  # Clean log file
  mkdir -p "$LOG_DIR"
  echo "" > "$LOG_DIR/$service_name.log"
  
  # Print the exact command being run (for debugging)
  echo "Executing command: $command" >> "$LOG_DIR/$service_name.log"
  
  # Start the service and redirect output to log file
  eval "$command" >> "$LOG_DIR/$service_name.log" 2>&1 &
  local pid=$!
  PIDS+=($pid)
  echo $pid > "$SCRIPT_DIR/.pid.$service_name"
  
  sleep 5
  if kill -0 $pid 2>/dev/null; then
    echo -e "${GREEN}✓ $service_name started successfully (PID: $pid)${NC}"
  else
    echo -e "${RED}✗ $service_name failed to start. Check $LOG_DIR/$service_name.log${NC}"
    echo -e "${YELLOW}Last 10 lines of log:${NC}"
    tail -n 10 "$LOG_DIR/$service_name.log"
    if [ "$critical" = "critical" ]; then
      echo -e "${RED}Critical service failed. Exiting...${NC}"
      exit 1
    fi
  fi
}

# Function to check if blockchain is accessible
check_blockchain_status() {
  local status_code=0
  local timeout=10
  local retries=0
  local max_retries=3
  
  echo -e "${YELLOW}Checking blockchain network status...${NC}"
  
  while [ $retries -lt $max_retries ]; do
    # Try to get network status with curl with proper error handling
    local response=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545)
    
    # Check if response contains result field (valid JSON-RPC response)
    if [ $? -eq 0 ] && echo "$response" | grep -q "result"; then
      echo -e "${GREEN}✓ Blockchain network is accessible${NC}"
      status_code=1
      break
    else
      echo -e "${YELLOW}Waiting for blockchain... (Attempt $((retries+1))/${max_retries})${NC}"
      retries=$((retries+1))
      sleep $timeout
    fi
  done
  
  if [ $status_code -ne 1 ]; then
    echo -e "${YELLOW}Warning: Blockchain network may not be running.${NC}"
    echo -e "${YELLOW}Please ensure you've started the blockchain network using ./scripts/start-blockchain-network.sh${NC}"
    echo -e "${YELLOW}Continuing UI startup anyway...${NC}"
  fi
  
  return $status_code
}

# Function to check for existing processes and stop them
stop_existing_processes() {
  # Check for stored PIDs
  for service in "frontend"; do
    if [ -f "$SCRIPT_DIR/.pid.$service" ]; then
      local pid=$(cat "$SCRIPT_DIR/.pid.$service")
      if ps -p $pid > /dev/null; then
        echo -e "Stopping existing $service process (PID: $pid)..."
        kill $pid 2>/dev/null
        pkill -P $pid 2>/dev/null
        sleep 2
      fi
      rm "$SCRIPT_DIR/.pid.$service"
    fi
  done
  
  # Kill any processes using frontend port
  echo -e "Checking for processes using port 3000 (frontend)..."
  pid=$(lsof -ti:3000)
  if [ ! -z "$pid" ]; then
    echo -e "Killing process using port 3000 (PID: $pid)..."
    kill -9 $pid 2>/dev/null
    sleep 1
  fi
  
  echo -e "${GREEN}✓ Existing UI processes cleared${NC}"
}

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

print_header "STARTING OPENSEA QC UI"

# Clean up existing processes
print_header "Cleaning up existing UI processes"
stop_existing_processes

# Check if blockchain is accessible (just warning, not critical)
check_blockchain_status

# Start the NextJS frontend
print_header "Starting NextJS frontend"
cd "$BASE_DIR"
run_service "frontend" "yarn start" "critical"

# Display useful information
print_header "UI READY"
echo -e "${GREEN}Services running:${NC}"
echo -e "- Frontend: ${YELLOW}http://localhost:3000${NC}"

echo -e "\n${GREEN}QC Testing Tools:${NC}"
echo -e "- Visit ${YELLOW}http://localhost:3000${NC} to access the marketplace"
echo -e "- Frontend tests: ${YELLOW}yarn test:frontend${NC}"
echo -e "- Contract tests: ${YELLOW}yarn test:contracts${NC}"
echo -e "- E2E tests: ${YELLOW}yarn test:e2e${NC}"

echo -e "\n${YELLOW}Press Ctrl+C to stop UI${NC}"
echo -e "${GREEN}Happy QC Testing!${NC}\n"

# Keep the script running to manage the UI process
while true; do
  sleep 60
  # Check if the UI process is still running
  for pid in "${PIDS[@]}"; do
    if ! ps -p $pid > /dev/null; then
      echo -e "${RED}UI process (PID: $pid) has stopped unexpectedly. Exiting...${NC}"
      exit 1
    fi
  done
done