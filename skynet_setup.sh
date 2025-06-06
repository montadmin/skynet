#!/bin/bash
# Skynet AI VM Installer Script
# Tested on Ubuntu 22.04 LTS

set -e

## === CONFIG === ##
AI_USER="aiadmin"
AI_PASS="Sftpuser"
SFTP_USER="sftpuser"
HOST_IP="192.168.3.222"

## === System Setup === ##
echo "[1/10] Updating system..."
apt update && apt upgrade -y
apt install -y sudo curl wget git unzip python3 python3-pip ffmpeg tmux build-essential \
  nginx openssh-server jq ufw net-tools htop

## === Fix containerd conflict if present === ##
echo "[Fix] Removing conflicting containerd versions..."
apt remove -y containerd || true
apt remove -y containerd.io || true
apt autoremove -y && apt autoclean

## === Docker Install (official script) === ##
echo "[1b] Installing Docker..."
curl -fsSL https://get.docker.com | sh

## === User Setup === ##
echo "[2/10] Creating users..."
useradd -m -s /bin/bash "$AI_USER"
echo "$AI_USER:$AI_PASS" | chpasswd
usermod -aG sudo,docker "$AI_USER"

useradd -m -s /bin/bash "$SFTP_USER"
echo "$SFTP_USER:$AI_PASS" | chpasswd
mkdir -p /home/$SFTP_USER/uploads /home/$SFTP_USER/transcripts
chown -R $SFTP_USER:$SFTP_USER /home/$SFTP_USER

## === Whisper Install === ##
echo "[3/10] Installing Whisper (faster-whisper)..."
pip3 install faster-whisper yt-dlp

## === LocalAI === ##
echo "[4/10] Deploying LocalAI..."
su - $AI_USER -c "git clone https://github.com/go-skynet/LocalAI && cd LocalAI && make docker"

## === Stable Diffusion (InvokeAI) === ##
echo "[5/10] Installing InvokeAI..."
su - $AI_USER -c "pip3 install invokeai"

## === Admin Panel === ##
echo "[6/10] Setting up FastAPI admin panel..."
su - $AI_USER -c "mkdir -p ~/admin && cd ~/admin && python3 -m venv venv && source venv/bin/activate && pip install fastapi uvicorn"

## === Portainer === ##
echo "[7/10] Installing Portainer..."
docker volume create portainer_data
docker run -d -p 9000:9000 -p 8000:8000 --name=portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce

## === yt-dlp + transcript handler === ##
echo "[8/10] Setting up YouTube download and transcript..."
cat <<EOF > /usr/local/bin/link2transcript
#!/bin/bash
URL="$1"
FILENAME=$(yt-dlp --get-title "$URL" | sed 's/[^a-zA-Z0-9]/_/g')
yt-dlp -f bestaudio --extract-audio --audio-format mp3 -o "/home/$SFTP_USER/uploads/\$FILENAME.%(ext)s" "$URL"
faster-whisper "/home/$SFTP_USER/uploads/\$FILENAME.mp3" > "/home/$SFTP_USER/transcripts/\$FILENAME.txt"
EOF
chmod +x /usr/local/bin/link2transcript

## === SFTP Config === ##
echo "[9/10] Configuring SFTP jail..."
cat <<EOL >> /etc/ssh/sshd_config
Match User $SFTP_USER
  ChrootDirectory /home/$SFTP_USER
  ForceCommand internal-sftp
  AllowTcpForwarding no
  X11Forwarding no
EOL
systemctl restart sshd

## === Firewall === ##
echo "[10/10] Enabling firewall..."
ufw allow OpenSSH
ufw allow 7860/tcp  # LocalAI Web UI
ufw allow 9000/tcp  # Portainer
ufw enable

## === Done === ##
echo "✅ Skynet AI Stack Installed. Access on:"
echo "- SSH: ssh $AI_USER@$HOST_IP"
echo "- SFTP: sftp $SFTP_USER@$HOST_IP (pass: $AI_PASS)"
echo "- LocalAI WebUI: http://$HOST_IP:7860"
echo "- Portainer: http://$HOST_IP:9000"
echo "- Use 'link2transcript <url>' to transcribe a YouTube/Vimeo video"
