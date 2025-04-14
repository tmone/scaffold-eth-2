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
MAX_RETRIES=15  # Increased retries
RPC_URL="http://localhost:8545"

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
}

# Function to handle script exit and cleanup
cleanup() {
  echo -e "\n${YELLOW}Shutting down blockchain services...${NC}"
  
  # Kill any process using port 8545
  local port_pid=$(lsof -t -i:8545 2>/dev/null)
  if [ ! -z "$port_pid" ]; then
    echo -e "Killing process using port 8545 (PID: $port_pid)..."
    kill -9 $port_pid 2>/dev/null
  fi
  
  # Update network status to indicate shutdown
  update_network_status false "Local blockchain network is stopped. NFT features will not work." "error"
  
  echo -e "${GREEN}✓ Blockchain services stopped${NC}"
  exit 0
}

# Register the cleanup function to be called on exit
trap cleanup SIGINT SIGTERM EXIT

# Function to check if blockchain is already running
check_blockchain() {
    if lsof -i:8545 >/dev/null 2>&1; then
        echo "Port 8545 is already in use. Another blockchain instance might be running."
        return 0
    else
        return 1
    fi
}

# Function to verify blockchain connectivity
verify_blockchain() {
    echo "Verifying blockchain connection..."
    local retry_count=0

    while [ $retry_count -lt $MAX_RETRIES ]; do
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            $RPC_URL | grep -q "result"; then
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

# Go to Hardhat package directory
cd "$BASE_DIR/packages/hardhat"

# Install hardhat globally if needed
if ! command -v npx &> /dev/null; then
    echo "npx command not found. Installing npx..."
    npm install -g npx
fi

# Make sure hardhat is installed
#echo "Installing hardhat locally and globally..."
#yarn add hardhat --dev 
#yarn global add hardhat
npm run compile

# Start hardhat node directly using npx
echo "Starting hardhat node with npx..."
npm run chain >> "$BLOCKCHAIN_LOG" 2>&1 &

BLOCKCHAIN_PID=$!
echo $BLOCKCHAIN_PID > "${LOGS_DIR}/blockchain.pid"
echo "Blockchain process started with PID: $BLOCKCHAIN_PID"
echo "Giving blockchain time to initialize (10 seconds)..."
sleep 10

# Verify blockchain is running
if ! verify_blockchain; then
    echo "First attempt failed. Trying alternative method..."
    kill $BLOCKCHAIN_PID 2>/dev/null
    sleep 2
    
    # Try alternative approach with direct node command
    echo "Installing hardhat CLI globally..."
    npm install -g hardhat
    
    # Start hardhat with global installation
    echo "Starting hardhat node with global installation..."
    npm run chain >> "$BLOCKCHAIN_LOG" 2>&1 &
    
    BLOCKCHAIN_PID=$!
    echo $BLOCKCHAIN_PID > "${LOGS_DIR}/blockchain.pid"
    echo "Blockchain process started with PID: $BLOCKCHAIN_PID"
    echo "Giving blockchain time to initialize (10 seconds)..."
    sleep 10
    
    # Verify blockchain is running again
    if ! verify_blockchain; then
        echo "ERROR: Blockchain verification failed. Check logs at: $BLOCKCHAIN_LOG"
        echo "Last 20 lines of logs:"
        tail -n 20 "$BLOCKCHAIN_LOG"
        echo
        echo "You can manually check the connection with:"
        echo "curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://localhost:8545"
        exit 1
    fi
fi

# If we get here, the blockchain is running successfully
update_network_status true "Using local Hardhat blockchain network" "info"

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
echo "====================================="

# Keep the script running and perform health checks
while true; do
  sleep 30
  
  # Verify blockchain is still running
  if ! curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       $RPC_URL | grep -q "result"; then
       
    echo "$(date): Blockchain connection lost, attempting restart..." >> "$BLOCKCHAIN_LOG"
    update_network_status false "Blockchain connection lost. Attempting to restart..." "warning"
    
    # Try to restart blockchain
    cd "$BASE_DIR/packages/hardhat"
    npm run chain >> "$BLOCKCHAIN_LOG" 2>&1 &
    
    BLOCKCHAIN_PID=$!
    echo $BLOCKCHAIN_PID > "${LOGS_DIR}/blockchain.pid"
    
    sleep 10
    if ! verify_blockchain; then
      update_network_status false "Failed to restart blockchain network. NFT features will not work." "error"
      echo "$(date): Failed to restart blockchain network" >> "$BLOCKCHAIN_LOG"
      exit 1
    else
      update_network_status true "Blockchain network restarted successfully" "success"
      echo "$(date): Blockchain network restarted successfully" >> "$BLOCKCHAIN_LOG"
    fi
  fi
done