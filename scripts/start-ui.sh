#!/bin/bash

# Text formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# Enhanced function to run services with real-time log output
run_service_with_logs() {
  local service_name=$1
  local command=$2
  local critical=$3
  
  echo -e "${YELLOW}Starting $service_name...${NC}"
  
  # Clean log file
  mkdir -p "$LOG_DIR"
  echo "" > "$LOG_DIR/$service_name.log"
  
  # Print the exact command being run (for debugging)
  echo "Executing command: $command" >> "$LOG_DIR/$service_name.log"
  
  # Create named pipe for real-time logs
  local log_pipe="/tmp/${service_name}_pipe"
  rm -f "$log_pipe"
  mkfifo "$log_pipe"
  
  # Start a background process to display logs with user action highlighting
  tee -a "$LOG_DIR/$service_name.log" < "$log_pipe" | grep --line-buffered -E 'user|action|click|submit|form|wallet|connect|mint|create|buy|list|offer|cancel|approve' | sed -u "s/.*user.*/\${MAGENTA}[USER ACTION]\\0\${NC}/g; s/.*wallet.*/\${CYAN}[WALLET]\\0\${NC}/g; s/.*action.*/\${YELLOW}[ACTION]\\0\${NC}/g" &
  local display_pid=$!
  PIDS+=($display_pid)
  
  # Start the service and redirect output to the pipe
  eval "$command" > "$log_pipe" 2>&1 &
  local pid=$!
  PIDS+=($pid)
  echo $pid > "$SCRIPT_DIR/.pid.$service_name"
  
  # Sleep a bit to let the service start
  sleep 5
  if kill -0 $pid 2>/dev/null; then
    echo -e "${GREEN}✓ $service_name started successfully (PID: $pid)${NC}"
    echo -e "${CYAN}📊 User interactions will be highlighted in the console below 📊${NC}"
  else
    echo -e "${RED}✗ $service_name failed to start. Check $LOG_DIR/$service_name.log${NC}"
    echo -e "${YELLOW}Last 10 lines of log:${NC}"
    tail -n 10 "$LOG_DIR/$service_name.log"
    if [ "$critical" = "critical" ]; then
      echo -e "${RED}Critical service failed. Exiting...${NC}"
      exit 1
    fi
  fi
  
  # Clean up named pipe (in background to allow script to continue)
  ( sleep 5; rm -f "$log_pipe" ) &
}

# Function to check if blockchain is accessible
check_blockchain_status() {
  local status_code=0
  local timeout=15  # Increased from 10 to 15 seconds
  local retries=0
  local max_retries=5  # Increased from 3 to 5 retries
  local NETWORK_CONFIG_PATH="$BASE_DIR/packages/nextjs/public/network-status.json"
  
  echo -e "${YELLOW}Checking blockchain network status...${NC}"
  
  # Make sure the network status file exists and is writable
  mkdir -p "$(dirname "$NETWORK_CONFIG_PATH")"
  
  # First, check if blockchain is running by checking its PID file
  if [ -f "$SCRIPT_DIR/logs/blockchain.pid" ]; then
    local blockchain_pid=$(cat "$SCRIPT_DIR/logs/blockchain.pid")
    if ps -p $blockchain_pid > /dev/null; then
      echo -e "${GREEN}✓ Blockchain process found (PID: $blockchain_pid)${NC}"
    else
      echo -e "${YELLOW}Warning: Blockchain PID file exists but process is not running.${NC}"
      echo -e "${YELLOW}Starting the blockchain network now...${NC}"
      
      # Try to start the blockchain automatically
      "$SCRIPT_DIR/start-blockchain-network.sh" > "$LOG_DIR/blockchain_restart.log" 2>&1 &
      echo -e "${YELLOW}Blockchain network starting in background. Check $LOG_DIR/blockchain_restart.log for details.${NC}"
      echo -e "${YELLOW}Waiting 10 seconds for blockchain to initialize...${NC}"
      sleep 10
    fi
  else
    echo -e "${YELLOW}Warning: No blockchain PID file found. Blockchain might not be running.${NC}"
  fi

  # Try to get network status with curl with improved error handling and diagnostics
  echo -e "${YELLOW}Testing RPC connection to http://localhost:8545...${NC}"
  while [ $retries -lt $max_retries ]; do
    echo -e "${YELLOW}Connection attempt $((retries+1))/${max_retries} with $timeout second timeout...${NC}"
    
    # Try to get network status with curl with proper error handling
    local response=$(curl -s -m $timeout -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545)
    local curl_status=$?
    
    if [ $curl_status -eq 28 ]; then
      echo -e "${RED}Connection timed out after $timeout seconds${NC}"
    elif [ $curl_status -ne 0 ]; then
      echo -e "${RED}Connection error (curl status: $curl_status)${NC}"
    fi
    
    # Check if response contains result field (valid JSON-RPC response)
    if [ $curl_status -eq 0 ] && echo "$response" | grep -q "result"; then
      echo -e "${GREEN}✓ Blockchain network is accessible${NC}"
      
      # Update network status file to indicate blockchain is running
      local timestamp=$(date +%s)
      echo '{
        "isRunning": true,
        "networkType": "local",
        "message": "Using local Hardhat blockchain network",
        "severity": "info",
        "timestamp": "'$timestamp'",
        "apiEndpoint": "http://localhost:3000/api",
        "lastRefresh": "'$timestamp'",
        "timeoutMs": 30000,
        "retries": 5
      }' > "$NETWORK_CONFIG_PATH"
      
      echo -e "${GREEN}✓ Updated network status file to indicate blockchain is running${NC}"
      
      # Check if contracts are deployed by trying to get block number
      local block_response=$(curl -s -m $timeout -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545)
      local block_number=$(echo $block_response | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
      if [ ! -z "$block_number" ]; then
        echo -e "${YELLOW}Current block number: $block_number${NC}"
        # Convert hex block number to decimal for comparison
        local dec_block=$(printf "%d" $block_number 2>/dev/null || echo "0")
        if [ "$dec_block" -lt 5 ]; then
          echo -e "${YELLOW}Warning: Blockchain is at a very low block number.${NC}"
          echo -e "${YELLOW}NFT contracts might not be deployed yet.${NC}"
        fi
      fi
      
      status_code=1
      break
    else
      echo -e "${YELLOW}Waiting for blockchain... (Attempt $((retries+1))/${max_retries})${NC}"
      # Print the response for debugging
      if [ ! -z "$response" ]; then
        echo -e "${YELLOW}Response: $response${NC}"
      fi
      retries=$((retries+1))
      sleep $timeout
    fi
  done
  
  if [ $status_code -ne 1 ]; then
    echo -e "${RED}ERROR: Cannot connect to blockchain network after $max_retries attempts.${NC}"
    echo -e "${YELLOW}Please ensure you've started the blockchain network using:${NC}"
    echo -e "${CYAN}./scripts/start-blockchain-network.sh${NC}"
    echo -e "${RED}NFT functionality will not work without a running blockchain network.${NC}"
    echo -e "${YELLOW}Common troubleshooting steps:${NC}"
    echo -e "  ${YELLOW}1. Make sure port 8545 is not being used by another process${NC}"
    echo -e "  ${YELLOW}2. Check if there are any errors in $LOG_DIR/blockchain.log${NC}"
    echo -e "  ${YELLOW}3. Try restarting the blockchain with ./scripts/start-blockchain-network.sh${NC}"
    
    # Update network status file to indicate blockchain is not running
    local timestamp=$(date +%s)
    echo '{
      "isRunning": false,
      "networkType": "local",
      "message": "Local blockchain network is not running. NFT features will not work.",
      "severity": "error",
      "timestamp": "'$timestamp'",
      "apiEndpoint": "http://localhost:3000/api",
      "lastRefresh": "'$timestamp'",
      "timeoutMs": 30000,
      "retries": 5
    }' > "$NETWORK_CONFIG_PATH"
    
    echo -e "${YELLOW}Updated network status file to indicate blockchain is not running${NC}"
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

# Function to check Node.js version
check_node_version() {
  print_header "Checking Node.js version"
  
  # Get required Node.js version from package.json
  local required_version=$(grep '"node":' "$BASE_DIR/package.json" | grep -o '">=.*"' | tr -d '"')
  
  if [ -z "$required_version" ]; then
    # Default minimum version if not specified - changed to support current version
    required_version=">=18.0.0"
  fi
  
  echo -e "Required Node.js version: ${YELLOW}$required_version${NC}"
  
  # Get current Node.js version
  local current_version=$(node -v 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Node.js is not installed or not in PATH${NC}"
    echo -e "${YELLOW}Please install Node.js $required_version${NC}"
    return 1
  fi
  
  echo -e "Current Node.js version: ${YELLOW}$current_version${NC}"
  
  # Extract minimum version without >=
  local min_version=$(echo $required_version | sed 's/>=//g')
  
  # Compare versions (simplified check - just major version)
  local current_major=$(echo $current_version | cut -d. -f1 | tr -d 'v')
  local required_major=$(echo $min_version | cut -d. -f1)
  
  if [ "$current_major" -lt "$required_major" ]; then
    echo -e "${RED}Error: Node.js version $current_version is not compatible with this project${NC}"
    echo -e "${YELLOW}Please update Node.js to version $required_version or higher${NC}"
    echo -e "${CYAN}Tip: You can use nvm to manage multiple Node.js versions:${NC}"
    echo -e "${CYAN}  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash${NC}"
    echo -e "${CYAN}  nvm install $required_major${NC}"
    echo -e "${CYAN}  nvm use $required_major${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ Node.js version check passed${NC}"
  return 0
}

# Function to deploy NFT contracts - Now moved to start-blockchain-network.sh
deploy_nft_contracts() {
  print_header "Contract Deployment Moved"
  echo -e "${YELLOW}Note: NFT contract deployment has been moved to start-blockchain-network.sh${NC}"
  echo -e "${YELLOW}Contracts are now deployed when the blockchain starts, not when the UI restarts${NC}"
  echo -e "${YELLOW}This ensures contract addresses remain stable across UI restarts${NC}"
  
  # Check if contracts appear to be deployed by looking for addresses.json
  local addresses_file="$BASE_DIR/packages/nextjs/contracts/addresses.json"
  if [ ! -f "$addresses_file" ]; then
    echo -e "${RED}Warning: Contract addresses file not found. Contracts may not be deployed.${NC}"
    echo -e "${YELLOW}To deploy contracts, please restart the blockchain with:${NC}"
    echo -e "${CYAN}./scripts/start-blockchain-network.sh${NC}"
  else
    echo -e "${GREEN}Found contract addresses file. Contracts appear to be deployed.${NC}"
    if command -v jq &> /dev/null; then
      echo -e "${YELLOW}Current contract addresses:${NC}"
      jq '.local' "$addresses_file"
    else
      echo -e "${YELLOW}Contract addresses file exists at: $addresses_file${NC}"
    fi
  fi
}

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

print_header "STARTING OPENSEA QC UI"

# Clean up existing processes
print_header "Cleaning up existing UI processes"
stop_existing_processes

# Temporarily skip Node.js version check
#if ! check_node_version; then
#  echo -e "${RED}Exiting due to Node.js version incompatibility${NC}"
#  exit 1
#fi
echo -e "${YELLOW}WARNING: Skipping Node.js version check. This might cause issues.${NC}"

# Check if blockchain is accessible (just warning, not critical)
check_blockchain_status

# Deploy contracts before starting the UI
deploy_nft_contracts

# Start the NextJS frontend
print_header "Starting NextJS frontend with user action logging"
# Navigate to the project root first
cd "$BASE_DIR"
echo "Installing dependencies for all packages..."

# Try installing dependencies with npm instead of yarn
echo "Attempting to install dependencies with npm..."
npm install >> "$LOG_DIR/frontend.log" 2>&1
if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to install dependencies with npm. Check $LOG_DIR/frontend.log${NC}"
  echo -e "${YELLOW}Last 10 lines of log:${NC}"
  tail -n 10 "$LOG_DIR/frontend.log"
  echo -e "${RED}Critical service failed. Exiting...${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Dependencies installed successfully${NC}"

# Set environment variables for blockchain connection
echo "Setting up environment variables for blockchain connection..."
# Increase polling intervals to reduce timeout errors
export NEXT_PUBLIC_NETWORK_POLLING_INTERVAL=60000
export NEXT_PUBLIC_RPC_POLLING_INTERVAL=60000
# Increase network request timeout from default 8 seconds to 30 seconds
export NEXT_PUBLIC_NETWORK_TIMEOUT=30000
export NEXT_PUBLIC_RPC_TIMEOUT=30000
# Add retry options to prevent timeouts
export NEXT_PUBLIC_NETWORK_RETRIES=5
export NEXT_PUBLIC_RPC_RETRIES=5
# Use a longer backoff time between retries
export NEXT_PUBLIC_RETRY_BACKOFF=2000
# Use fallback provider on timeout
export NEXT_PUBLIC_USE_FALLBACK_PROVIDER=true
# Use burner wallet for local development
export NEXT_PUBLIC_USE_BURNER_WALLET=true
export NEXT_PUBLIC_LOCAL_RPC_URL=http://localhost:8545
# Disable ENS resolution on local network to prevent ENS resolver errors
export NEXT_PUBLIC_DISABLE_ENS=true
# Use browser localStorage instead of filesystem for NFT listings data
export NEXT_PUBLIC_USE_LOCAL_STORAGE=true
# Ensure proper connection options
export NEXT_PUBLIC_ENABLE_NETWORK_RETRY=true

# API environment variables to fix 500 errors
echo "Setting up API environment variables for NFT creation..."
export NEXT_PUBLIC_API_BASE_URL=http://localhost:3000
export NEXT_PUBLIC_IPFS_GATEWAY=https://ipfs.io/ipfs/
export NEXT_PUBLIC_ENABLE_MOCK_IPFS=true
export NEXT_PUBLIC_API_TIMEOUT=30000
# Enable detailed API error logging
export NEXT_PUBLIC_DEBUG_API=true

# Enhanced environment variables for better file watching and hot reloading
echo "Setting up improved file watching and hot reloading..."
export CHOKIDAR_USEPOLLING=true
export FAST_REFRESH=true 
export WATCHPACK_POLLING=true

# Now try starting the NextJS dev server with npm and showing logs in real-time
echo "Starting NextJS development server with enhanced file watching and hot reloading..."
cd "$BASE_DIR/packages/nextjs"
run_service_with_logs "frontend" "NEXT_PUBLIC_LOG_USER_ACTIONS=true NEXT_PUBLIC_USE_LOCAL_STORAGE=true npm run dev:watch" "critical"

# Display useful information
print_header "UI READY WITH USER ACTION LOGGING"
echo -e "${GREEN}Services running:${NC}"
echo -e "- Frontend: ${YELLOW}http://localhost:3000${NC}"

echo -e "\n${CYAN}📊 User action logging is enabled:${NC}"
echo -e "- ${MAGENTA}[USER ACTION]${NC}: Clicks, form submissions, and interactions"
echo -e "- ${YELLOW}[ACTION]${NC}: Application state changes and events"
echo -e "- ${CYAN}[WALLET]${NC}: Wallet connections and transactions\n"

echo -e "\n${GREEN}QC Testing Tools:${NC}"
echo -e "- Visit ${YELLOW}http://localhost:3000${NC} to access the marketplace"
echo -e "- Frontend tests: ${YELLOW}yarn test:frontend${NC}"
echo -e "- Contract tests: ${YELLOW}yarn test:contracts${NC}"
echo -e "- E2E tests: ${YELLOW}yarn test:e2e${NC}"

echo -e "\n${YELLOW}Press Ctrl+C to stop UI${NC}"
echo -e "${GREEN}Happy QC Testing!${NC}\n"

# Keep the script running to manage the UI process and display logs
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