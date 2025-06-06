#!/bin/bash
# Universal AI Stack Installer for Debian-based systems
# Supports Debian 10+/Ubuntu 18.04+ and derivatives
# Features: Auto-detection, Multi-architecture support, Error handling

set -euo pipefail
trap 'echo "Error in line $LINENO. Exit code $?" >&2' ERR

# ===== Configuration =====
readonly AI_USER="aiadmin"
readonly SFTP_USER="aitransfer"
readonly LOG_FILE="/var/log/ai_stack_install.log"
readonly SUPPORTED_ARCHES=("x86_64" "arm64" "amd64")

# ===== Environment Checks =====
check_distro() {
    if ! command -v lsb_release >/dev/null; then
        apt-get update && apt-get install -y lsb-release
    fi

    local distro=$(lsb_release -is)
    local version=$(lsb_release -rs)
    local codename=$(lsb_release -cs)

    [[ "$distro" =~ ^(Debian|Ubuntu|Pop|Linuxmint|Kali)$ ]] || {
        echo "Unsupported distribution: $distro" >&2
        return 1
    }

    case "$distro" in
        Debian) [[ "$version" =~ ^(10|11|12)$ ]] || return 1 ;;
        Ubuntu) [[ "$version" =~ ^(18.04|20.04|22.04|23.04)$ ]] || return 1 ;;
    esac

    echo "Detected: $distro $version ($codename)"
}

check_architecture() {
    local arch=$(uname -m)
    [[ " ${SUPPORTED_ARCHES[*]} " =~ " ${arch} " ]] || {
        echo "Unsupported architecture: $arch" >&2
        return 1
    }
    echo "Architecture: $arch"
}

# ===== Main Installation =====
install_dependencies() {
    echo "[1/8] Installing system dependencies..."
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        sudo curl wget git unzip python3 python3-pip python3-venv \
        ffmpeg tmux build-essential nginx openssh-server jq \
        ufw net-tools htop fail2ban libssl-dev python3-dev \
        portaudio19-dev libffi-dev libjpeg-dev zlib1g-dev
}

setup_docker() {
    echo "[2/8] Installing Docker..."
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker "$AI_USER"
    fi

    if ! docker run --rm hello-world &>/dev/null; then
        echo "Docker test failed!" >&2
        return 1
    fi
}

setup_python_tools() {
    echo "[3/8] Setting up Python environment..."
    local py_pkgs=(
        torch torchaudio torchvision --extra-index-url https://download.pytorch.org/whl/cpu
        faster-whisper yt-dlp invokeai
        fastapi uvicorn python-multipart
        transformers sentencepiece
    )

    sudo -u "$AI_USER" python3 -m pip install --user "${py_pkgs[@]}"
}

install_ai_services() {
    echo "[4/8] Installing AI services..."

    # LocalAI
    if [[ ! -d "/home/$AI_USER/LocalAI" ]]; then
        sudo -u "$AI_USER" git clone https://github.com/go-skynet/LocalAI.git "/home/$AI_USER/LocalAI"
        pushd "/home/$AI_USER/LocalAI" >/dev/null
        sudo -u "$AI_USER" make build
        popd >/dev/null
    fi

    # Text Generation WebUI (Ollama alternative)
    if [[ ! -d "/home/$AI_USER/text-generation-webui" ]]; then
        sudo -u "$AI_USER" git clone https://github.com/oobabooga/text-generation-webui "/home/$AI_USER/text-generation-webui"
        pushd "/home/$AI_USER/text-generation-webui" >/dev/null
        sudo -u "$AI_USER" pip install -r requirements.txt
        popd >/dev/null
    fi
}

setup_management() {
    echo "[5/8] Setting up management tools..."

    # Portainer
    if ! docker ps -a --format '{{.Names}}' | grep -q 'portainer'; then
        docker volume create portainer_data >/dev/null
        docker run -d -p 9000:9000 -p 8000:8000 --name=portainer \
            --restart=always -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data portainer/portainer-ce:latest >/dev/null
    fi

    # Systemd services
    cat > /etc/systemd/system/ai_stack.service <<EOF
[Unit]
Description=AI Stack Services
After=network.target docker.service

[Service]
User=$AI_USER
WorkingDirectory=/home/$AI_USER
ExecStart=/bin/bash -c 'cd /home/$AI_USER/LocalAI && ./local-ai'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ai_stack
}

configure_security() {
    echo "[6/8] Configuring security..."

    # Firewall
    ufw allow OpenSSH
    ufw allow 7860/tcp  # LocalAI
    ufw allow 9000/tcp  # Portainer
    ufw allow 5000/tcp  # Text Generation WebUI
    ufw --force enable

    # Fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban

    # SSH hardening
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
}

setup_utilities() {
    echo "[7/8] Setting up utilities..."

    # Transcription service
    cat > /usr/local/bin/transcribe <<'EOF'
#!/bin/bash
# Universal transcription script
# Supports: YouTube, local files

set -e

INPUT="$1"
OUTPUT_DIR="${2:-$HOME/transcripts}"
MODEL="${3:-small}"

mkdir -p "$OUTPUT_DIR"

if [[ "$INPUT" =~ ^https?:// ]]; then
    # YouTube/downloadable content
    filename=$(yt-dlp --get-title "$INPUT" | tr -cd 'A-Za-z0-9 _-')
    yt-dlp -f bestaudio --extract-audio --audio-format wav \
        -o "/tmp/${filename}.%(ext)s" "$INPUT"
    INPUT="/tmp/${filename}.wav"
fi

faster-whisper "$INPUT" --model "$MODEL" --output_dir "$OUTPUT_DIR" \
    --device auto --compute_type auto

echo "Transcript saved to: $OUTPUT_DIR"
EOF

    chmod +x /usr/local/bin/transcribe
    chown "$AI_USER":"$AI_USER" /usr/local/bin/transcribe
}

finalize() {
    echo "[8/8] Finalizing installation..."

    # Create credentials file
    local pw=$(openssl rand -base64 12)
    echo "$AI_USER:$pw" | chpasswd
    echo "Generated credentials:" | tee -a "$LOG_FILE"
    echo "AI Admin: $AI_USER / $pw" | tee -a "$LOG_FILE"
    echo "Portainer: http://$(hostname -I | awk '{print $1}'):9000" | tee -a "$LOG_FILE"

    # Print completion message
    cat <<EOF

=== AI Stack Installation Complete ===

Access Information:
- SSH: ssh $AI_USER@$(hostname -I | awk '{print $1}')
- Portainer: http://$(hostname -I | awk '{print $1}'):9000
- LocalAI: http://$(hostname -I | awk '{print $1}'):7860
- Text Generation: http://$(hostname -I | awk '{print $1}'):5000

Recommended next steps:
1. Set up SSH keys for $AI_USER
2. Configure HTTPS reverse proxy
3. Set up backups for /home/$AI_USER
4. Monitor system resources (htop)

Installation log: $LOG_FILE
EOF
}

# ===== Main Execution =====
main() {
    # Initial checks
    check_distro
    check_architecture
    [[ $EUID -eq 0 ]] || { echo "Run as root!" >&2; exit 1; }

    # Create AI user if not exists
    if ! id "$AI_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$AI_USER"
        echo "Created user: $AI_USER"
    fi

    # Start installation
    exec > >(tee "$LOG_FILE") 2>&1
    echo "AI Stack Installation started at $(date)"

    install_dependencies
    setup_docker
    setup_python_tools
    install_ai_services
    setup_management
    configure_security
    setup_utilities
    finalize
}

main "$@"
