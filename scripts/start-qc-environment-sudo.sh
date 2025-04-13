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
LOG_DIR="$SCRIPT_DIR/logs"
REGULAR_USER=$(whoami)

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
  
  # Create log directory with appropriate permissions if it doesn't exist
  mkdir -p "$LOG_DIR"
  chmod -R 777 "$LOG_DIR"
  
  # Clean log file
  touch "$LOG_DIR/$service_name.log"
  chmod 666 "$LOG_DIR/$service_name.log"
  echo "" > "$LOG_DIR/$service_name.log"
  
  # Print the exact command being run (for debugging)
  echo "Executing command: $command" >> "$LOG_DIR/$service_name.log"
  
  # Start the service and redirect output to log file
  eval "$command" >> "$LOG_DIR/$service_name.log" 2>&1 &
  local pid=$!
  
  # Make PID file writable
  touch "$SCRIPT_DIR/.pid.$service_name"
  chmod 666 "$SCRIPT_DIR/.pid.$service_name"
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

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"
chmod -R 777 "$LOG_DIR"

print_header "STARTING OPENSEA QC MARKETPLACE TESTING ENVIRONMENT"

# Start Docker containers with sudo
print_header "Starting Docker services"
if [ -f "$BASE_DIR/docker/docker-compose.yml" ]; then
  cd "$BASE_DIR/docker"
  docker-compose up -d
  check_status "Docker services"
  cd "$BASE_DIR"
else
  echo -e "${RED}Docker compose file not found. Skipping...${NC}"
fi

# The rest of the script runs without sudo as the regular user

# Exit sudo and run the rest of the commands as the regular user
# We'll create a temporary script to run the remaining commands
TMP_SCRIPT="/tmp/opensea-qc-continue.sh"

cat > "$TMP_SCRIPT" << EOF
#!/bin/bash

# Copy the necessary functions and variables
BASE_DIR="$BASE_DIR"
SCRIPT_DIR="$SCRIPT_DIR"
LOG_DIR="$LOG_DIR"

# Define color coding
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

# Function to print section headers
print_header() {
  echo -e "\\n\${BLUE}==== \$1 ====\${NC}\\n"
}

# Function to check if a command succeeded
check_status() {
  if [ \$? -eq 0 ]; then
    echo -e "\${GREEN}✓ \$1 succeeded\${NC}"
  else
    echo -e "\${RED}✗ \$1 failed\${NC}"
    if [ "\$2" = "exit" ]; then
      exit 1
    fi
  fi
}

# Function to run commands in background with log and add to monitoring
run_service() {
  local service_name=\$1
  local command=\$2
  local critical=\$3
  
  echo -e "\${YELLOW}Starting \$service_name...\${NC}"
  
  # Clean log file
  echo "" > "\$LOG_DIR/\$service_name.log"
  
  # Print the exact command being run (for debugging)
  echo "Executing command: \$command" >> "\$LOG_DIR/\$service_name.log"
  
  # Start the service and redirect output to log file
  eval "\$command" >> "\$LOG_DIR/\$service_name.log" 2>&1 &
  local pid=\$!
  
  echo \$pid > "\$SCRIPT_DIR/.pid.\$service_name"
  
  sleep 5
  if kill -0 \$pid 2>/dev/null; then
    echo -e "\${GREEN}✓ \$service_name started successfully (PID: \$pid)\${NC}"
  else
    echo -e "\${RED}✗ \$service_name failed to start. Check \$LOG_DIR/\$service_name.log\${NC}"
    echo -e "\${YELLOW}Last 10 lines of log:\${NC}"
    tail -n 10 "\$LOG_DIR/\$service_name.log"
    if [ "\$critical" = "critical" ]; then
      echo -e "\${RED}Critical service failed. Exiting...\${NC}"
      exit 1
    fi
  fi
}

# Start local blockchain (without sudo)
print_header "Starting local blockchain"
cd "\$BASE_DIR/packages/hardhat"
# Use npx hardhat directly instead of yarn chain
run_service "blockchain" "npx hardhat node --network hardhat --no-deploy" "critical"

# Wait for blockchain to be ready
echo "Waiting for blockchain to be ready..."
sleep 10

# Deploy Seaport protocol
print_header "Building Seaport protocol"
cd "\$BASE_DIR/components/seaport"
yarn build
check_status "Building Seaport"
cd "\$BASE_DIR"

# Deploy ERC721 contracts
print_header "Deploying ERC721 contracts"
cd "\$BASE_DIR/components/erc721"
yarn deploy
check_status "Deploying ERC721 contracts"
cd "\$BASE_DIR"

# Deploy ERC1155 contracts
print_header "Deploying ERC1155 contracts"
cd "\$BASE_DIR/components/erc1155"
yarn deploy
check_status "Deploying ERC1155 contracts"
cd "\$BASE_DIR"

# Deploy Operator Filter Registry
print_header "Deploying Operator Filter Registry"
cd "\$BASE_DIR/components/operator-filter"
yarn deploy
check_status "Deploying Operator Filter Registry"
cd "\$BASE_DIR"

# Deploy main contracts through Scaffold-ETH
print_header "Deploying main contracts"
cd "\$BASE_DIR"
yarn deploy
check_status "Deploying main contracts"

# Start the NextJS frontend
print_header "Starting NextJS frontend"
cd "\$BASE_DIR"
run_service "frontend" "yarn start"

# Display useful information
print_header "QC TESTING ENVIRONMENT READY"
echo -e "\${GREEN}Services running:\${NC}"
echo -e "- Local blockchain: \${YELLOW}http://localhost:8545\${NC}"
echo -e "- Frontend: \${YELLOW}http://localhost:3000\${NC}"
echo -e "- MongoDB: \${YELLOW}mongodb://localhost:27017\${NC}"
echo -e "- PostgreSQL: \${YELLOW}postgresql://opensea:yourpassword@localhost:5432/opensea_db\${NC}"
echo -e "- Redis: \${YELLOW}localhost:6379\${NC}"
echo -e "- Elasticsearch: \${YELLOW}http://localhost:9200\${NC}"
echo -e "- IPFS: \${YELLOW}http://localhost:5001\${NC}"

echo -e "\\n\${GREEN}QC Testing Tools:\${NC}"
echo -e "- Visit \${YELLOW}http://localhost:3000\${NC} to access the marketplace"
echo -e "- Frontend tests: \${YELLOW}yarn test:frontend\${NC}"
echo -e "- Contract tests: \${YELLOW}yarn test:contracts\${NC}"
echo -e "- E2E tests: \${YELLOW}yarn test:e2e\${NC}"

echo -e "\\n\${YELLOW}To stop all services:\${NC} \$SCRIPT_DIR/stop-qc-environment.sh"
echo -e "\${YELLOW}To view logs:\${NC} tail -f \$LOG_DIR/[service].log"

echo -e "\\n\${GREEN}Happy QC Testing!\${NC}"
EOF

# Make the continuation script executable
chmod +x "$TMP_SCRIPT"

# Run the continuation script as the regular user
echo -e "${YELLOW}Running blockchain and other services as regular user...${NC}"
# First find the actual username of the sudo user
ACTUAL_USER=$(logname || echo "$SUDO_USER" || echo "tmone")
echo "Detected user: $ACTUAL_USER"
# We need to make sure the script sources the user's profile to get the correct PATH with Node.js
su - $ACTUAL_USER -c "source ~/.profile || source ~/.bash_profile || source ~/.bashrc; export PATH=\$HOME/.nvm/versions/node/*/bin:\$PATH; $TMP_SCRIPT"

# Clean up temp script
rm -f "$TMP_SCRIPT"