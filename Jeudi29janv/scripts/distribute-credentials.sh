#!/bin/bash
#===============================================================================
# HACKATHON HDS - CREDENTIAL DISTRIBUTION SCRIPT
# This script packages credentials for each team for distribution
#===============================================================================

set -e

KEYS_DIR="./keys"
DIST_DIR="./distribution"
DOCS_DIR="./docs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Hackathon HDS - Credential Packaging  ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if keys directory exists
if [ ! -d "$KEYS_DIR" ]; then
    echo -e "${RED}ERROR: Keys directory not found. Run 'make prod' first.${NC}"
    exit 1
fi

# Create distribution directory
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Get list of teams (directories that have ssh_private_key.pem but not upload-portal or admin)
TEAMS=$(find "$KEYS_DIR" -name "ssh_private_key.pem" -exec dirname {} \; | xargs -n1 basename | grep -v -E "^(upload-portal|admin|evaluators)$" || true)

echo -e "${YELLOW}Found teams:${NC}"
for team in $TEAMS; do
    echo "  - $team"
done
echo ""

# Package each team
for team in $TEAMS; do
    echo -e "${YELLOW}Packaging credentials for: $team${NC}"
    
    TEAM_DIST="$DIST_DIR/$team"
    mkdir -p "$TEAM_DIST"
    
    # Copy team-specific files
    cp "$KEYS_DIR/$team/ssh_private_key.pem" "$TEAM_DIST/"
    cp "$KEYS_DIR/$team/api_credentials.env" "$TEAM_DIST/"
    cp "$KEYS_DIR/$team/credentials.md" "$TEAM_DIST/"
    
    # Extract connection info from credentials.md using portable grep/sed
    # Look for lines like "- Bastion (public): 51.159.145.167"
    BASTION_IP=$(grep "Bastion (public):" "$KEYS_DIR/$team/credentials.md" | sed 's/.*: //' | tr -d '[:space:]')
    GPU_IP=$(grep "GPU (private):" "$KEYS_DIR/$team/credentials.md" | sed 's/.*: //' | tr -d '[:space:]')
    
    echo "  Bastion IP: $BASTION_IP"
    echo "  GPU IP: $GPU_IP"
    
    if [ -z "$BASTION_IP" ] || [ -z "$GPU_IP" ]; then
        echo -e "${RED}  WARNING: Could not extract IPs for $team${NC}"
    fi
    
    # Create standalone connect-gpu.sh script with hardcoded IPs
    cat > "$TEAM_DIST/connect-gpu.sh" << EOFSCRIPT
#!/bin/bash
# Connect to GPU for team $team
# This script can be run from any directory

SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
KEY="\$SCRIPT_DIR/ssh_private_key.pem"

chmod 600 "\$KEY" 2>/dev/null

BASTION_IP="${BASTION_IP}"
GPU_IP="${GPU_IP}"

if [ -z "\$BASTION_IP" ] || [ -z "\$GPU_IP" ]; then
    echo "ERROR: IP addresses not configured in this script."
    echo "Please use the manual connection method from credentials.md"
    exit 1
fi

echo "Connecting to GPU \$GPU_IP via bastion \$BASTION_IP..."
ssh -i "\$KEY" -o StrictHostKeyChecking=accept-new \\
    -o ProxyCommand="ssh -i \$KEY -o StrictHostKeyChecking=accept-new -W %h:%p root@\$BASTION_IP" \\
    root@\$GPU_IP
EOFSCRIPT
    chmod +x "$TEAM_DIST/connect-gpu.sh"
    
    # Create standalone connect-bastion.sh script with hardcoded IP
    cat > "$TEAM_DIST/connect-bastion.sh" << EOFSCRIPT
#!/bin/bash
# Connect to Bastion for team $team
# This script can be run from any directory

SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
KEY="\$SCRIPT_DIR/ssh_private_key.pem"

chmod 600 "\$KEY" 2>/dev/null

BASTION_IP="${BASTION_IP}"

if [ -z "\$BASTION_IP" ]; then
    echo "ERROR: Bastion IP not configured in this script."
    echo "Please use the manual connection method from credentials.md"
    exit 1
fi

echo "Connecting to bastion \$BASTION_IP..."
ssh -i "\$KEY" -o StrictHostKeyChecking=accept-new root@\$BASTION_IP
EOFSCRIPT
    chmod +x "$TEAM_DIST/connect-bastion.sh"
    
    # Copy and adapt onboarding documentation
    if [ -f "$DOCS_DIR/TEAM_ONBOARDING.md" ]; then
        cp "$DOCS_DIR/TEAM_ONBOARDING.md" "$TEAM_DIST/README.md"
    fi
    
    # Create zip for distribution
    (cd "$DIST_DIR" && zip -r "${team}-credentials.zip" "$team")
    
    echo -e "${GREEN}  ✓ Created: $DIST_DIR/${team}-credentials.zip${NC}"
done

# Package evaluators if exists
if [ -d "$KEYS_DIR/evaluators" ]; then
    echo -e "${YELLOW}Packaging credentials for: evaluators${NC}"
    
    EVAL_DIST="$DIST_DIR/evaluators"
    mkdir -p "$EVAL_DIST"
    
    cp "$KEYS_DIR/evaluators/api_credentials.env" "$EVAL_DIST/"
    
    # Copy evaluator documentation
    if [ -f "$DOCS_DIR/EVALUATOR_GUIDE.md" ]; then
        cp "$DOCS_DIR/EVALUATOR_GUIDE.md" "$EVAL_DIST/README.md"
    fi
    
    # Copy encryption keys for livrables and zone2
    [ -f "$KEYS_DIR/livrables_encryption_key.txt" ] && cp "$KEYS_DIR/livrables_encryption_key.txt" "$EVAL_DIST/"
    [ -f "$KEYS_DIR/zone2_encryption_key.txt" ] && cp "$KEYS_DIR/zone2_encryption_key.txt" "$EVAL_DIST/"
    
    (cd "$DIST_DIR" && zip -r "evaluators-credentials.zip" "evaluators")
    
    echo -e "${GREEN}  ✓ Created: $DIST_DIR/evaluators-credentials.zip${NC}"
fi

# Package data providers
PROVIDERS=$(find "$KEYS_DIR" -name "portal_credentials.txt" -exec dirname {} \; | xargs -n1 basename 2>/dev/null || true)

for provider in $PROVIDERS; do
    if [ -n "$provider" ] && [ "$provider" != "upload-portal" ]; then
        echo -e "${YELLOW}Packaging credentials for data provider: $provider${NC}"
        
        PROV_DIST="$DIST_DIR/$provider"
        mkdir -p "$PROV_DIST"
        
        [ -f "$KEYS_DIR/$provider/api_credentials.env" ] && cp "$KEYS_DIR/$provider/api_credentials.env" "$PROV_DIST/"
        [ -f "$KEYS_DIR/$provider/portal_credentials.txt" ] && cp "$KEYS_DIR/$provider/portal_credentials.txt" "$PROV_DIST/"
        
        # Copy data provider documentation
        if [ -f "$DOCS_DIR/DATA_PROVIDERS.md" ]; then
            cp "$DOCS_DIR/DATA_PROVIDERS.md" "$PROV_DIST/README.md"
        fi
        
        # Copy zone1 encryption key
        [ -f "$KEYS_DIR/zone1_encryption_key.txt" ] && cp "$KEYS_DIR/zone1_encryption_key.txt" "$PROV_DIST/"
        
        (cd "$DIST_DIR" && zip -r "${provider}-credentials.zip" "$provider")
        
        echo -e "${GREEN}  ✓ Created: $DIST_DIR/${provider}-credentials.zip${NC}"
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Distribution packages created!        ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Files ready for distribution:"
ls -la "$DIST_DIR"/*.zip 2>/dev/null || echo "No zip files created"
echo ""
echo -e "${YELLOW}IMPORTANT: Send each team ONLY their own credentials package!${NC}"
echo -e "${YELLOW}           Use secure channels (encrypted email, secure file transfer)${NC}"
