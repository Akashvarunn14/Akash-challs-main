#!/bin/bash
# ===========================================
# L3m0n CTF VM Setup Script
# Run this on your new GCP VM
# ===========================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; }

# ===========================================
# CONFIGURATION - EDIT THESE VALUES
# ===========================================
VM_IP=""  # Will be auto-detected if empty
CTFD_IP="34.47.146.119"  # Your CTFd website IP
CERT_DIR="$HOME/.docker/certs"
REPO_URL="https://github.com/PraneeshRV/Akash-challs.git"

# ===========================================
# Phase 1: System Setup
# ===========================================
phase1_setup() {
    log "Phase 1: System Setup"
    
    # Update system
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl git ufw openssl
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        warn "Docker installed. You may need to log out and back in for group changes."
    else
        log "Docker already installed"
    fi
    
    log "Phase 1 Complete!"
}

# ===========================================
# Phase 2: Docker TLS Setup
# ===========================================
phase2_tls() {
    log "Phase 2: Docker TLS Configuration"
    
    # Auto-detect VM IP if not set
    if [ -z "$VM_IP" ]; then
        VM_IP=$(curl -s ifconfig.me)
        log "Auto-detected VM IP: $VM_IP"
    fi
    
    mkdir -p "$CERT_DIR"
    cd "$CERT_DIR"
    
    # Check if certs already exist
    if [ -f "ca.pem" ] && [ -f "server-cert.pem" ] && [ -f "cert.pem" ]; then
        warn "Certificates already exist in $CERT_DIR"
        read -p "Do you want to regenerate them? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping certificate generation"
            return
        fi
    fi
    
    log "Generating CA certificate..."
    openssl genrsa -aes256 -passout pass:docker-ca-pass -out ca-key.pem 4096
    openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem \
        -passin pass:docker-ca-pass \
        -subj "/C=IN/ST=State/L=City/O=L3m0nCTF/CN=Docker CA"
    
    log "Generating server certificate..."
    openssl genrsa -out server-key.pem 4096
    openssl req -subj "/CN=$VM_IP" -sha256 -new -key server-key.pem -out server.csr
    
    echo "subjectAltName = IP:$VM_IP,IP:127.0.0.1" > extfile.cnf
    echo "extendedKeyUsage = serverAuth" >> extfile.cnf
    
    openssl x509 -req -days 365 -sha256 -in server.csr \
        -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
        -out server-cert.pem -extfile extfile.cnf \
        -passin pass:docker-ca-pass
    
    log "Generating client certificate..."
    openssl genrsa -out key.pem 4096
    openssl req -subj '/CN=client' -new -key key.pem -out client.csr
    
    echo "extendedKeyUsage = clientAuth" > extfile-client.cnf
    
    openssl x509 -req -days 365 -sha256 -in client.csr \
        -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
        -out cert.pem -extfile extfile-client.cnf \
        -passin pass:docker-ca-pass
    
    # Cleanup
    rm -f *.csr *.cnf *.srl
    
    # Set permissions
    chmod 0400 ca-key.pem key.pem server-key.pem
    chmod 0444 ca.pem cert.pem server-cert.pem
    
    log "Certificates generated in $CERT_DIR"
    ls -la "$CERT_DIR"
    
    log "Phase 2 Complete!"
}

# ===========================================
# Phase 3: Configure Docker Daemon
# ===========================================
phase3_daemon() {
    log "Phase 3: Configure Docker Daemon with TLS"
    
    # Create daemon.json
    sudo tee /etc/docker/daemon.json << EOF
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2376"],
  "tls": true,
  "tlscacert": "$CERT_DIR/ca.pem",
  "tlscert": "$CERT_DIR/server-cert.pem",
  "tlskey": "$CERT_DIR/server-key.pem",
  "tlsverify": true
}
EOF
    
    # Fix systemd conflict
    sudo mkdir -p /etc/systemd/system/docker.service.d
    sudo tee /etc/systemd/system/docker.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF
    
    # Restart Docker
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    # Test connection
    sleep 2
    if docker --tlsverify \
        --tlscacert="$CERT_DIR/ca.pem" \
        --tlscert="$CERT_DIR/cert.pem" \
        --tlskey="$CERT_DIR/key.pem" \
        -H=tcp://127.0.0.1:2376 version > /dev/null 2>&1; then
        log "Docker TLS connection successful!"
    else
        error "Docker TLS connection failed. Check the configuration."
        exit 1
    fi
    
    log "Phase 3 Complete!"
}

# ===========================================
# Phase 4: Firewall Configuration
# ===========================================
phase4_firewall() {
    log "Phase 4: Firewall Configuration"
    
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # SSH
    sudo ufw allow 22/tcp
    
    # HTTP/HTTPS for challenges
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Challenge ports (5000-6000 range)
    sudo ufw allow 5000:6000/tcp
    
    # Block unencrypted Docker API
    sudo ufw deny 2375/tcp
    
    # Allow Docker TLS only from CTFd
    sudo ufw allow from $CTFD_IP to any port 2376 proto tcp
    
    # Enable firewall
    sudo ufw --force enable
    
    log "UFW Status:"
    sudo ufw status
    
    warn "IMPORTANT: You must also add a GCP Firewall rule:"
    warn "  Name: allow-docker-tls-from-ctfd"
    warn "  Source IP: $CTFD_IP/32"
    warn "  Protocol: tcp:2376"
    
    log "Phase 4 Complete!"
}

# ===========================================
# Phase 5: Clone and Build Challenges
# ===========================================
phase5_build() {
    log "Phase 5: Clone and Build Challenge Images"
    
    cd ~
    
    if [ -d "Akash-challs" ]; then
        log "Repository exists, pulling latest..."
        cd Akash-challs
        git pull
    else
        log "Cloning repository..."
        git clone $REPO_URL
        cd Akash-challs
    fi
    
    # Build images with clean names
    log "Building l3mon-agent45..."
    cd ~/Akash-challs/agent45
    docker build -t l3mon-agent45:latest .
    
    log "Building l3mon-arbitrage..."
    cd ~/Akash-challs/arbitrage_ctf
    docker build -t l3mon-arbitrage:latest .
    
    log "Building l3mon-command-injection..."
    cd ~/Akash-challs/l3mon_web_command_injection
    docker build -t l3mon-command-injection:latest .
    
    log "Building l3mon-web-cve..."
    cd ~/Akash-challs/l3mon_web_cve
    docker build -t l3mon-web-cve:latest .
    
    log "Building l3mon-web-jwt..."
    cd ~/Akash-challs/l3mon_web_jwt
    docker build -t l3mon-web-jwt:latest .
    
    log "Building l3mon-format-pie..."
    cd ~/Akash-challs/format_pie
    docker build -t l3mon-format-pie:latest .
    
    log "Building l3mon-twisted-ret..."
    cd ~/Akash-challs/twisted_ret
    docker build -t l3mon-twisted-ret:latest .
    
    log "Building l3mon-arbitrage-hard..."
    cd ~/Akash-challs/arbitrage_ctf_hard
    docker build -t l3mon-arbitrage-hard:latest .
    
    log "Building l3mon-ssrf..."
    cd ~/Akash-challs/ssrf
    docker build -t l3mon-ssrf:latest .
    
    log "Building l3mon-web-forensics..."
    cd ~/Akash-challs/web_forensics1
    docker build -t l3mon-web-forensics:latest .
    
    log "All images built:"
    docker images | grep l3mon
    
    log "Phase 5 Complete!"
}

# ===========================================
# Phase 6: Display CTFd Configuration
# ===========================================
phase6_output() {
    log "Phase 6: CTFd Configuration Info"
    
    echo ""
    echo "=============================================="
    echo "  UPLOAD THESE CERTIFICATES TO CTFd"
    echo "=============================================="
    echo ""
    echo "CA Certificate (ca.pem):"
    echo "------------------------"
    cat "$CERT_DIR/ca.pem"
    echo ""
    echo "Client Certificate (cert.pem):"
    echo "-------------------------------"
    cat "$CERT_DIR/cert.pem"
    echo ""
    echo "Client Key (key.pem):"
    echo "---------------------"
    cat "$CERT_DIR/key.pem"
    echo ""
    echo "=============================================="
    echo "  CTFd DOCKER SERVER SETTINGS"
    echo "=============================================="
    echo "Server Name:      L3m0n Challenge Server"
    echo "Docker Hostname:  $VM_IP:2376"
    echo "TLS Security:     ENABLED"
    echo ""
    
    log "Setup Complete!"
}

# ===========================================
# Main Menu
# ===========================================
main() {
    echo ""
    echo "=============================================="
    echo "  L3m0n CTF VM Setup Script"
    echo "=============================================="
    echo ""
    echo "1) Run ALL phases (full setup)"
    echo "2) Phase 1: System Setup"
    echo "3) Phase 2: Generate TLS Certificates"
    echo "4) Phase 3: Configure Docker Daemon"
    echo "5) Phase 4: Configure Firewall"
    echo "6) Phase 5: Build Challenge Images"
    echo "7) Phase 6: Show CTFd Configuration"
    echo "8) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) phase1_setup && phase2_tls && phase3_daemon && phase4_firewall && phase5_build && phase6_output ;;
        2) phase1_setup ;;
        3) phase2_tls ;;
        4) phase3_daemon ;;
        5) phase4_firewall ;;
        6) phase5_build ;;
        7) phase6_output ;;
        8) exit 0 ;;
        *) error "Invalid option" && main ;;
    esac
}

# Run main
main
