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
      
      # Check if contracts are deployed by trying to get block number
      # This is a basic check - if block number is very low, contracts might not be deployed
      local block_response=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545)
      local block_number=$(echo $block_response | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
      if [ ! -z "$block_number" ]; then
        echo -e "${YELLOW}Current block number: $block_number${NC}"
        # Convert hex block number to decimal for comparison
        local dec_block=$(printf "%d" $block_number)
        if [ "$dec_block" -lt 5 ]; then
          echo -e "${YELLOW}Warning: Blockchain is at a very low block number.${NC}"
          echo -e "${YELLOW}NFT contracts might not be deployed yet.${NC}"
          echo -e "${YELLOW}Consider running deployment scripts in components/erc721 and components/erc1155 directories.${NC}"
          echo -e "${CYAN}Command to deploy contracts: cd /path/to/component && yarn deploy${NC}"
        fi
      fi
      
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
    echo -e "${RED}NFT functionality will not work without a running blockchain network.${NC}"
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

# Function to deploy NFT contracts
deploy_nft_contracts() {
  print_header "Deploying NFT Contracts"
  
  # Check if blockchain is running first
  echo -e "${YELLOW}Checking if blockchain network is running...${NC}"
  local response=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545)
  
  # If blockchain not running, try to start it
  if [ $? -ne 0 ] || ! echo "$response" | grep -q "result"; then
    echo -e "${YELLOW}Blockchain network not detected. Attempting to start it...${NC}"
    echo -e "${YELLOW}Running blockchain startup script...${NC}"
    
    # Try to start the blockchain network
    "$SCRIPT_DIR/start-blockchain.sh" &
    local blockchain_pid=$!
    sleep 15
    
    # Check if blockchain started successfully
    response=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545)
    if [ $? -ne 0 ] || ! echo "$response" | grep -q "result"; then
      echo -e "${RED}✗ Failed to start blockchain network. Check if hardhat is installed properly.${NC}"
      echo -e "${YELLOW}Installing hardhat globally...${NC}"
      npm install --global hardhat
      echo -e "${YELLOW}Starting blockchain manually with npx...${NC}"
      cd "$BASE_DIR/packages/hardhat"
      npx hardhat node --hostname 127.0.0.1 --port 8545 >> "$LOG_DIR/blockchain.log" 2>&1 &
      blockchain_pid=$!
      sleep 15
      
      # Check again if blockchain started
      response=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545)
      if [ $? -ne 0 ] || ! echo "$response" | grep -q "result"; then
        echo -e "${RED}✗ Failed to start blockchain network after multiple attempts.${NC}"
        echo -e "${YELLOW}Continuing without blockchain. NFT functions will not work properly.${NC}"
        cd "$BASE_DIR"
        return 1
      fi
    fi
    echo -e "${GREEN}✓ Blockchain network started successfully${NC}"
  else
    echo -e "${GREEN}✓ Blockchain network is already running${NC}"
  fi
  
  echo -e "${YELLOW}Deploying ERC721 contracts...${NC}"
  
  # Deploy ERC721 contracts
  cd "$BASE_DIR/components/erc721"
  echo "Installing contract dependencies..."
  npm install >> "$LOG_DIR/erc721_deploy.log" 2>&1
  if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to install ERC721 dependencies. Check $LOG_DIR/erc721_deploy.log${NC}"
    echo -e "${YELLOW}NFT creation functionality might not work properly.${NC}"
  else
    echo "Compiling and deploying ERC721 contracts..."
    npx hardhat run scripts/deploy.js --network localhost >> "$LOG_DIR/erc721_deploy.log" 2>&1
    if [ $? -ne 0 ]; then
      echo -e "${RED}✗ Failed to deploy ERC721 contracts. Check $LOG_DIR/erc721_deploy.log${NC}"
      echo -e "${YELLOW}Last 10 lines of log:${NC}"
      tail -n 10 "$LOG_DIR/erc721_deploy.log"
    else
      echo -e "${GREEN}✓ ERC721 contracts deployed successfully${NC}"
    fi
  fi
  
  # Deploy ERC1155 contracts
  echo -e "${YELLOW}Deploying ERC1155 contracts...${NC}"
  cd "$BASE_DIR/components/erc1155"
  echo "Installing contract dependencies..."
  npm install >> "$LOG_DIR/erc1155_deploy.log" 2>&1
  if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to install ERC1155 dependencies. Check $LOG_DIR/erc1155_deploy.log${NC}"
    echo -e "${YELLOW}NFT creation functionality might not work properly.${NC}"
  else
    echo "Compiling and deploying ERC1155 contracts..."
    npx hardhat run scripts/deploy.js --network localhost >> "$LOG_DIR/erc1155_deploy.log" 2>&1
    if [ $? -ne 0 ]; then
      echo -e "${RED}✗ Failed to deploy ERC1155 contracts. Check $LOG_DIR/erc1155_deploy.log${NC}"
      echo -e "${YELLOW}Last 10 lines of log:${NC}"
      tail -n 10 "$LOG_DIR/erc1155_deploy.log"
    else
      echo -e "${GREEN}✓ ERC1155 contracts deployed successfully${NC}"
    fi
  fi
  
  echo -e "${YELLOW}Note: Contract addresses have been saved to deployment logs.${NC}"
  echo -e "${YELLOW}If your frontend cannot connect to them, check $LOG_DIR/erc721_deploy.log and $LOG_DIR/erc1155_deploy.log for addresses.${NC}"
  
  # Return to base directory
  cd "$BASE_DIR"
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

# Now try starting the NextJS dev server with npm and showing logs in real-time
echo "Starting NextJS development server with real-time log output..."
cd "$BASE_DIR/packages/nextjs"
run_service_with_logs "frontend" "NEXT_PUBLIC_LOG_USER_ACTIONS=true npm run dev" "critical"

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