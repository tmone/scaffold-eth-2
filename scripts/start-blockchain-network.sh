#!/bin/bash

# Enhanced blockchain startup script with better verification and logging

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
LOGS_DIR="$SCRIPT_DIR/logs"
NETWORK_CONFIG_PATH="$BASE_DIR/packages/nextjs/public/network-status.json"
BLOCKCHAIN_LOG="${LOGS_DIR}/blockchain.log"
MAX_RETRIES=10
RPC_URL="http://localhost:8545"

# Array to store PIDs of background processes
declare -a PIDS=()

# Flag to track if network status has been updated
NETWORK_STATUS_UPDATED=0

# Track the last seen transaction count for event detection
LAST_TX_COUNT=0

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Clear previous log
> "$BLOCKCHAIN_LOG"

echo "====================================="
echo "OpenSea QC Blockchain Network Startup"
echo "====================================="
echo "Starting at $(date)"
echo "Logs will be written to $BLOCKCHAIN_LOG"
echo 

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
  
  # Update network status to indicate shutdown
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

# Function to check if blockchain is already running
check_blockchain() {
    if lsof -i:8545 >/dev/null 2>&1; then
        echo "Port 8545 is already in use. Another blockchain instance might be running."
        echo "Use 'lsof -i:8545' to identify the process and 'kill <PID>' to stop it."
        return 0
    else
        return 1
    fi
}

# Function to verify blockchain connectivity
verify_blockchain() {
    echo "Verifying blockchain connection..."
    local retry_count=0
    local connected=false

    while [ $retry_count -lt $MAX_RETRIES ] && [ $connected = false ]; do
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            $RPC_URL | grep -q "result"; then
            connected=true
            echo "Blockchain connection verified successfully."
            return 0
        else
            retry_count=$((retry_count+1))
            echo "Attempt $retry_count/$MAX_RETRIES: Blockchain not responsive yet. Waiting 2 seconds..."
            sleep 2
        fi
    done

    echo "ERROR: Failed to verify blockchain connection after $MAX_RETRIES attempts."
    return 1
}

# Check for existing blockchain process
if check_blockchain; then
    echo "Do you want to kill the existing process and start a fresh blockchain? (y/n)"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Stopping existing blockchain process..."
        RUNNING_PID=$(lsof -t -i:8545)
        if [ -n "$RUNNING_PID" ]; then
            kill $RUNNING_PID
            sleep 2
            echo "Process stopped."
        fi
    else
        echo "Exiting. The existing blockchain process will continue running."
        exit 0
    fi
fi

echo "Starting Hardhat blockchain network..."
echo "$(date): Starting blockchain network" >> "$BLOCKCHAIN_LOG"

# Run Hardhat directly with its embedded node script instead of using npx
cd "$BASE_DIR/packages/hardhat" && \
  node ./node_modules/hardhat/internal/cli/cli.js node --network hardhat >> "$BLOCKCHAIN_LOG" 2>&1 &

BLOCKCHAIN_PID=$!

# Save PID for later
echo $BLOCKCHAIN_PID > "${LOGS_DIR}/blockchain.pid"
echo "Blockchain process started with PID: $BLOCKCHAIN_PID"
echo "Giving blockchain time to initialize (5 seconds)..."
sleep 5

# Verify blockchain is running
if ! verify_blockchain; then
    echo "ERROR: Blockchain verification failed. Check logs at: $BLOCKCHAIN_LOG"
    echo "You can manually check the connection with:"
    echo "curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://localhost:8545"
    echo "Process might still be starting up. Wait a bit longer and try again."
    exit 1
fi

echo 
echo "====================================="
echo "Blockchain network is running successfully!"
echo "- Endpoint: $RPC_URL"
echo "- Process ID: $BLOCKCHAIN_PID"
echo "- Logs: $BLOCKCHAIN_LOG"
echo "====================================="
echo
echo "To stop the blockchain network, run:"
echo "kill $BLOCKCHAIN_PID"
echo
echo "Debug the connection at: http://localhost:3000/debug/blockchain"
echo "====================================="

# Reduced frequency health check loop
while true; do
  # Check blockchain health every 5 minutes instead of constantly
  sleep 300
  
  # Only update status if something changed (handled by update_network_status function)
  verify_blockchain > /dev/null
  
  # Refresh token data if new transactions are detected
  refresh_token_data
done