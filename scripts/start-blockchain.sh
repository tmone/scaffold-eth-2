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
NETWORK_CONFIG_PATH="$BASE_DIR/packages/nextjs/public/network-status.json"

# Array to store PIDs of background processes
declare -a PIDS=()

# Flag to track if network status has been updated
NETWORK_STATUS_UPDATED=0

# Track the last seen transaction count for event detection
LAST_TX_COUNT=0

# Function to update network status
update_network_status() {
  local status=$1
  local message=$2
  local severity=$3
  
  # Only update if the status has changed or it's the first update
  if [ "$NETWORK_STATUS_UPDATED" -eq 0 ] || [ "$PREV_STATUS" != "$status" ]; then
    local timestamp=$(date +%s)
    echo '{
      "isRunning": '$status',
      "networkType": "local",
      "message": "'$message'",
      "severity": "'$severity'",
      "timestamp": "'$timestamp'",
      "apiEndpoint": "http://localhost:3000/api",
      "lastRefresh": "'$timestamp'"
    }' > "$NETWORK_CONFIG_PATH"
    
    NETWORK_STATUS_UPDATED=1
    PREV_STATUS=$status
  fi
}

# Function to handle script exit and cleanup
cleanup() {
  echo -e "\n${YELLOW}Shutting down blockchain services...${NC}"
  
  # Kill all background processes
  for pid in "${PIDS[@]}"; do
    if ps -p $pid > /dev/null; then
      echo -e "Stopping process ${YELLOW}$pid${NC}..."
      kill $pid 2>/dev/null
      # Also kill any child processes
      pkill -P $pid 2>/dev/null
    fi
  done
  
  # Update network status to indicate shutdown - use our function
  update_network_status false "Mạng blockchain local đã tắt. Các tính năng NFT sẽ không hoạt động." "error"
  
  echo -e "${GREEN}✓ Blockchain services stopped${NC}"
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

# Function to check if blockchain is running
check_blockchain_status() {
  local status_code=0
  local timeout=30
  local retries=0
  local max_retries=5
  
  echo -e "${YELLOW}Checking blockchain network status...${NC}"
  
  while [ $retries -lt $max_retries ]; do
    # Try to get network status with curl with proper error handling
    local response=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545)
    
    # Check if response contains result field (valid JSON-RPC response)
    if [ $? -eq 0 ] && echo "$response" | grep -q "result"; then
      echo -e "${GREEN}✓ Blockchain network is running and responding${NC}"
      status_code=1
      break
    else
      echo -e "${YELLOW}Waiting for blockchain... (Attempt $((retries+1))/${max_retries})${NC}"
      echo -e "${YELLOW}Response: ${response:0:100}...${NC}"
      retries=$((retries+1))
      sleep $timeout
    fi
  done
  
  # Create network status config for frontend using our function
  if [ $status_code -eq 1 ]; then
    # Network is running
    update_network_status true "Đang sử dụng mạng blockchain local (Hardhat)" "info"
  else
    # Network is not running
    update_network_status false "Mạng blockchain local không sẵn sàng. Một số tính năng có thể không hoạt động." "warning"
    echo -e "${RED}✗ Blockchain network is not responding${NC}"
  fi
  
  return $status_code
}

# Function to refresh token data if new transactions are detected
refresh_token_data() {
  # Make the JSON-RPC call with proper error handling
  local response=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockTransactionCountByNumber","params":["latest"],"id":1}' http://localhost:8545)
  
  # Only process if we got a valid response
  if [ $? -eq 0 ] && echo "$response" | grep -q "result"; then
    local current_tx_count=$(echo "$response" | grep -o '"result":"[^"]*"' | sed 's/"result":"//;s/"$//' | xargs printf "%d" 2>/dev/null || echo "0")
    
    # Check if parsing was successful and current_tx_count is a number
    if [[ "$current_tx_count" =~ ^[0-9]+$ ]]; then
      if [ "$current_tx_count" -gt "$LAST_TX_COUNT" ]; then
        echo -e "${CYAN}New transactions detected. Refreshing token data...${NC}"
        # Add logic to refresh token data here
        LAST_TX_COUNT=$current_tx_count
      fi
    else
      echo -e "${YELLOW}Failed to parse transaction count from response: ${response:0:100}...${NC}"
    fi
  else
    echo -e "${YELLOW}Failed to get transaction count. Blockchain may be unresponsive.${NC}"
  fi
}

# Function to check for existing processes and stop them
stop_existing_processes() {
  # Check for stored PIDs
  for service in "blockchain" "frontend"; do
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
  
  # Kill any processes using common ports
  echo -e "Checking for processes using ports 8545 (blockchain) and 3000 (frontend)..."
  for port in 8545 3000; do
    pid=$(lsof -ti:$port)
    if [ ! -z "$pid" ]; then
      echo -e "Killing process using port $port (PID: $pid)..."
      kill -9 $pid 2>/dev/null
      sleep 1
    fi
  done
  
  echo -e "${GREEN}✓ Existing processes cleared${NC}"
}

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

print_header "STARTING OPENSEA QC BLOCKCHAIN SERVICES"

# Clean up existing processes
print_header "Cleaning up existing blockchain processes"
stop_existing_processes

# Start local blockchain
print_header "Starting local blockchain"
cd "$BASE_DIR/packages/hardhat"

# Find the hardhat binary directly in node_modules
if [ -f "./node_modules/.bin/hardhat" ]; then
  echo "Found hardhat binary in package's node_modules..."
  HARDHAT_BIN="./node_modules/.bin/hardhat"
elif [ -f "$BASE_DIR/node_modules/.bin/hardhat" ]; then
  echo "Found hardhat binary in workspace's node_modules..."
  HARDHAT_BIN="$BASE_DIR/node_modules/.bin/hardhat"
else
  echo "Searching for hardhat binary..."
  HARDHAT_BIN=$(find "$BASE_DIR" -path "*/node_modules/.bin/hardhat" -type f | head -1)
  if [ -z "$HARDHAT_BIN" ]; then
    echo -e "${RED}Could not find hardhat binary. Installing hardhat...${NC}"
    yarn add --dev hardhat
    HARDHAT_BIN="./node_modules/.bin/hardhat"
  else
    echo "Found hardhat at $HARDHAT_BIN"
  fi
fi

echo "Using direct hardhat binary to start blockchain..."
run_service "blockchain" "$HARDHAT_BIN node --network hardhat --hostname 127.0.0.1 --port 8545" "critical"

# Wait for blockchain to be ready - increase wait time for proper initialization
echo "Waiting for blockchain to be ready..."
sleep 15

# Check if blockchain is running and create config for frontend
check_blockchain_status
BLOCKCHAIN_READY=$?

if [ $BLOCKCHAIN_READY -ne 1 ]; then
  echo -e "${RED}Failed to start blockchain. Exiting...${NC}"
  exit 1
fi

# Deploy Seaport protocol
print_header "Building Seaport protocol"
cd "$BASE_DIR/components/seaport"
yarn build
check_status "Building Seaport"
cd "$BASE_DIR"

# Deploy ERC721 contracts
print_header "Deploying ERC721 contracts"
cd "$BASE_DIR/components/erc721"
yarn deploy
check_status "Deploying ERC721 contracts"
cd "$BASE_DIR"

# Deploy ERC1155 contracts
print_header "Deploying ERC1155 contracts"
cd "$BASE_DIR/components/erc1155"
yarn deploy
check_status "Deploying ERC1155 contracts"
cd "$BASE_DIR"

# Deploy Operator Filter Registry
print_header "Deploying Operator Filter Registry"
cd "$BASE_DIR/components/operator-filter"
yarn deploy
check_status "Deploying Operator Filter Registry"
cd "$BASE_DIR"

# Deploy main contracts through Scaffold-ETH
print_header "Deploying main contracts"
cd "$BASE_DIR"
yarn deploy
check_status "Deploying main contracts"

# Start the NextJS frontend
print_header "Starting NextJS frontend"
cd "$BASE_DIR"
run_service "frontend" "yarn start"

# Display useful information
print_header "QC TESTING ENVIRONMENT READY"
echo -e "${GREEN}Services running:${NC}"
echo -e "- Local blockchain: ${YELLOW}http://localhost:8545${NC}"
echo -e "  ${GREEN}✓ Blockchain network is active and ready${NC}"
echo -e "- Frontend: ${YELLOW}http://localhost:3000${NC}"

echo -e "\n${GREEN}QC Testing Tools:${NC}"
echo -e "- Visit ${YELLOW}http://localhost:3000${NC} to access the marketplace"
echo -e "- Frontend tests: ${YELLOW}yarn test:frontend${NC}"
echo -e "- Contract tests: ${YELLOW}yarn test:contracts${NC}"
echo -e "- E2E tests: ${YELLOW}yarn test:e2e${NC}"

echo -e "\n${YELLOW}Press Ctrl+C to stop blockchain services${NC}"
echo -e "${GREEN}Happy QC Testing!${NC}\n"

# Reduced frequency health check loop
while true; do
  # Check blockchain health every 5 minutes instead of constantly
  sleep 300
  
  # Only update status if something changed (handled by update_network_status function)
  check_blockchain_status > /dev/null
  
  # Refresh token data if new transactions are detected
  refresh_token_data
done