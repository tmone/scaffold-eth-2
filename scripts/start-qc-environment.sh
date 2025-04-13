#!/bin/bash
# filepath: /home/tmone/opensea-qc/scripts/start-qc-environment.sh

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

# Function to handle script exit and cleanup
cleanup() {
  echo -e "\n${YELLOW}Shutting down OpenSea QC environment...${NC}"
  
  # Kill all background processes
  for pid in "${PIDS[@]}"; do
    if ps -p $pid > /dev/null; then
      echo -e "Stopping process ${YELLOW}$pid${NC}..."
      kill $pid 2>/dev/null
      # Also kill any child processes
      pkill -P $pid 2>/dev/null
    fi
  done
  
  # Stop docker containers if they exist
  if [ -f "$BASE_DIR/docker/docker-compose.yml" ]; then
    echo -e "Stopping Docker services..."
    cd "$BASE_DIR/docker"
    docker-compose down -v 2>/dev/null
    cd "$BASE_DIR"
  fi
  
  # Update network status to indicate shutdown
  echo '{
    "isRunning": false,
    "networkType": "local",
    "message": "Mạng blockchain local đã tắt. Các tính năng NFT sẽ không hoạt động.",
    "severity": "error"
  }' > "$NETWORK_CONFIG_PATH"
  
  echo -e "${GREEN}✓ All services stopped${NC}"
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
  
  # Stop Docker containers if they exist
  if [ -f "$BASE_DIR/docker/docker-compose.yml" ]; then
    echo -e "Stopping existing Docker services..."
    cd "$BASE_DIR/docker"
    docker-compose down -v 2>/dev/null
    cd "$BASE_DIR"
  fi
  
  echo -e "${GREEN}✓ Environment cleared${NC}"
}

# Function to run commands in background with log and add to monitoring
run_service() {
  local service_name=$1
  local command=$2
  local critical=$3
  
  echo -e "${YELLOW}Starting $service_name...${NC}"
  
  # Clean log file
  echo "" > "$LOG_DIR/$service_name.log"
  
  # Print the exact command being run (for debugging)
  echo "Executing command: $command" >> "$LOG_DIR/$service_name.log"
  
  # Start the service and redirect output to log file
  eval "$command" >> "$LOG_DIR/$service_name.log" 2>&1 &
  local pid=$!
  PIDS+=($pid)
  echo $pid > "$SCRIPT_DIR/.pid.$service_name"
  
  # Give the process a moment to start
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
    # Try to get network status with curl
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8545 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' | grep -q "200"; then
      echo -e "${GREEN}✓ Blockchain network is running and responding${NC}"
      status_code=1
      break
    else
      echo -e "${YELLOW}Waiting for blockchain... (Attempt $((retries+1))/${max_retries})${NC}"
      retries=$((retries+1))
      sleep $timeout
    fi
  done
  
  # Create network status config for frontend
  if [ $status_code -eq 1 ]; then
    # Network is running
    echo '{
      "isRunning": true,
      "networkType": "local",
      "message": "Đang sử dụng mạng blockchain local (Hardhat)",
      "severity": "info"
    }' > "$NETWORK_CONFIG_PATH"
  else
    # Network is not running
    echo '{
      "isRunning": false,
      "networkType": "local",
      "message": "Mạng blockchain local không sẵn sàng. Một số tính năng có thể không hoạt động.",
      "severity": "warning"
    }' > "$NETWORK_CONFIG_PATH"
    echo -e "${RED}✗ Blockchain network is not responding${NC}"
  fi
  
  return $status_code
}

# Function to check Docker permissions and suggest solutions
check_docker_permissions() {
  # Check if docker socket exists and is accessible
  if [ ! -S /var/run/docker.sock ]; then
    echo -e "${RED}Docker socket not found. Is Docker installed?${NC}"
    return 1
  fi
  
  # Try to run a simple docker command
  if ! docker info &>/dev/null; then
    echo -e "${RED}Cannot connect to Docker daemon. Permission denied.${NC}"
    echo -e "${YELLOW}Try one of the following solutions:${NC}"
    echo -e "1. Run this script with sudo: ${GREEN}sudo $0${NC}"
    echo -e "2. Add your user to the docker group: ${GREEN}sudo usermod -aG docker $USER${NC} (requires logout/login)"
    echo -e "3. Use the sudo version of this script: ${GREEN}./scripts/start-qc-environment-sudo.sh${NC}"
    
    # Ask if user wants to continue without Docker
    read -p "Continue without Docker services? (y/n): " continue_choice
    if [[ $continue_choice != "y" && $continue_choice != "Y" ]]; then
      exit 1
    fi
    return 1
  fi
  
  return 0
}

# Function to check if Yarn is installed
check_yarn_installed() {
  if ! command -v yarn &> /dev/null; then
    echo -e "${RED}Error: Yarn is not installed or not available in your PATH${NC}"
    echo -e "${YELLOW}Please install Yarn using one of the following methods:${NC}"
    echo -e "1. Using NPM: ${GREEN}npm install -g yarn${NC}"
    echo -e "2. Using your package manager:"
    echo -e "   - Debian/Ubuntu: ${GREEN}sudo apt install yarn${NC}"
    echo -e "   - Fedora/RHEL: ${GREEN}sudo dnf install yarn${NC}"
    echo -e "   - Arch Linux: ${GREEN}sudo pacman -S yarn${NC}"
    echo -e "3. Or follow the official installation guide: ${CYAN}https://yarnpkg.com/getting-started/install${NC}"
    echo -e "\n${YELLOW}After installing Yarn, please run this script again.${NC}"
    return 1
  fi
  return 0
}

# Function to monitor logs with real-time updates
monitor_logs() {
  local selected_service="all"
  local running=true
  
  # Clear screen and show monitoring interface
  clear
  
  while $running; do
    # Display header and status
    echo -e "${BLUE}================ OPENSEA QC MONITORING =================${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit | [b]lockchain | [f]rontend | [a]ll logs${NC}"
    echo -e "${GREEN}Active Services:${NC}"
    
    # Check each service status
    for service in "blockchain" "frontend"; do
      if [ -f "$SCRIPT_DIR/.pid.$service" ]; then
        local pid=$(cat "$SCRIPT_DIR/.pid.$service")
        if ps -p $pid > /dev/null; then
          echo -e "  ${GREEN}✓${NC} $service (PID: $pid) - ${CYAN}Running${NC}"
        else
          echo -e "  ${RED}✗${NC} $service (PID: $pid) - ${RED}Stopped${NC}"
        fi
      else
        echo -e "  ${RED}✗${NC} $service - ${RED}Not started${NC}"
      fi
    done
    
    echo -e "${BLUE}====================== LOG OUTPUT ======================${NC}\n"
    
    # Show logs based on selected service
    if [ "$selected_service" == "blockchain" ]; then
      echo -e "${YELLOW}[Blockchain Log]${NC}"
      tail -n 20 "$LOG_DIR/blockchain.log" 2>/dev/null
    elif [ "$selected_service" == "frontend" ]; then
      echo -e "${YELLOW}[Frontend Log]${NC}"
      tail -n 20 "$LOG_DIR/frontend.log" 2>/dev/null
    else
      echo -e "${YELLOW}[Blockchain Log]${NC}"
      tail -n 10 "$LOG_DIR/blockchain.log" 2>/dev/null
      echo -e "\n${YELLOW}[Frontend Log]${NC}"
      tail -n 10 "$LOG_DIR/frontend.log" 2>/dev/null
    fi
    
    # Wait for key press with timeout
    echo -e "\n${BLUE}=====================================================${NC}"
    read -t 5 -n 1 key
    
    if [[ $key = "b" ]]; then
      selected_service="blockchain"
    elif [[ $key = "f" ]]; then
      selected_service="frontend"
    elif [[ $key = "a" ]]; then
      selected_service="all"
    fi
    
    # Clear screen for next update
    clear
  done
}

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

print_header "STARTING OPENSEA QC MARKETPLACE TESTING ENVIRONMENT"

# First clean up any existing processes
print_header "Cleaning up existing environment"
stop_existing_processes

# Start Docker containers
print_header "Starting Docker services"
if [ -f "$BASE_DIR/docker/docker-compose.yml" ]; then
  check_docker_permissions
  if [ $? -eq 0 ]; then
    cd "$BASE_DIR/docker"
    docker-compose up -d
    check_status "Docker services"
    cd "$BASE_DIR"
  else
    echo -e "${YELLOW}⚠️ You don't have permission to use Docker.${NC}"
    echo -e "${YELLOW}Running only Docker services with sudo...${NC}"
    cd "$BASE_DIR/docker"
    sudo docker-compose up -d
    check_status "Docker services with sudo"
    cd "$BASE_DIR"
  fi
else
  echo -e "${RED}Docker compose file not found. Skipping...${NC}"
fi

# Start local blockchain
print_header "Starting local blockchain"

# Check if Yarn is installed before proceeding
check_yarn_installed
if [ $? -ne 0 ]; then
  echo -e "${RED}✗ blockchain failed to start. Check $LOG_DIR/blockchain.log${NC}"
  echo -e "${RED}Critical service failed. Exiting...${NC}"
  exit 1
fi

cd "$BASE_DIR"
# Use the full workspace path to run the chain command
run_service "blockchain" "yarn workspace @se-2/hardhat chain" "critical"

# Wait for blockchain to be ready
echo "Waiting for blockchain to be ready..."
sleep 10

# Check if blockchain is running and create config for frontend
check_blockchain_status
BLOCKCHAIN_READY=$?

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
if [ $BLOCKCHAIN_READY -eq 1 ]; then
  echo -e "  ${GREEN}✓ Blockchain network is active and ready${NC}"
else
  echo -e "  ${RED}✗ Blockchain network is not responding - check logs${NC}"
fi
echo -e "- Frontend: ${YELLOW}http://localhost:3000${NC}"
echo -e "- MongoDB: ${YELLOW}mongodb://localhost:27017${NC}"
echo -e "- PostgreSQL: ${YELLOW}postgresql://opensea:yourpassword@localhost:5432/opensea_db${NC}"
echo -e "- Redis: ${YELLOW}localhost:6379${NC}"
echo -e "- Elasticsearch: ${YELLOW}http://localhost:9200${NC}"
echo -e "- IPFS: ${YELLOW}http://localhost:5001${NC}"

echo -e "\n${GREEN}QC Testing Tools:${NC}"
echo -e "- Visit ${YELLOW}http://localhost:3000${NC} to access the marketplace"
echo -e "- Frontend tests: ${YELLOW}yarn test:frontend${NC}"
echo -e "- Contract tests: ${YELLOW}yarn test:contracts${NC}"
echo -e "- E2E tests: ${YELLOW}yarn test:e2e${NC}"

echo -e "\n${YELLOW}Press Ctrl+C to stop all services${NC}"
echo -e "${YELLOW}Starting monitoring interface...${NC}"
echo -e "${GREEN}Happy QC Testing!${NC}\n"

# Enter monitoring mode - script will stay in foreground
sleep 3
monitor_logs