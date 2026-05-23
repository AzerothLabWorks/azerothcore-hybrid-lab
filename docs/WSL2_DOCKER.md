# WSL2 Docker Notes

This project assumes Ubuntu under WSL2 with Docker Engine installed inside Ubuntu.

Minimal dependency setup:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release git

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo service docker start
sudo usermod -aG docker "$USER"
newgrp docker
docker ps
```

To start Docker automatically when Ubuntu opens:

```bash
grep -qxF 'sudo service docker start > /dev/null 2>&1' ~/.bashrc || \
  echo 'sudo service docker start > /dev/null 2>&1' >> ~/.bashrc
```

Your Windows WoW client should connect to the WSL2 IP:

```bash
hostname -I | awk '{print $1}'
```

Then set `realmlist.wtf` on Windows to:

```text
set realmlist YOUR_WSL2_IP
```
