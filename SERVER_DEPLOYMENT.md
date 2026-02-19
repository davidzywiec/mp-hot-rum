# AWS Server Deployment Runbook

This runbook covers:
- SSH login to your EC2 instance
- Updating and redeploying the Godot dedicated server
- Day-to-day server operations

## Prerequisites

- EC2 instance is running and reachable
- Security Group allows:
  - SSH: TCP 22 from your IP
  - Game traffic: UDP 7000 from players
- You have your AWS key file:
  - `Godot Server Key Pair.pem`

## SSH Login (Mac/Linux)

1. Open terminal and go to the directory with your key file.
2. Set strict file permissions on the key:

```bash
chmod 400 "Godot Server Key Pair.pem"
```

3. Connect to your server:

```bash
ssh -i "Godot Server Key Pair.pem" ubuntu@3.19.123.12
```

Notes:
- `ubuntu` is the correct default user for Ubuntu AMIs.
- If SSH fails, verify the instance was launched with this same key pair.

## One-Time Docker Setup on EC2

If Docker was installed but `docker` commands fail with `permission denied` on `/var/run/docker.sock`, run:

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu
```

Then either:
- log out and SSH back in, or
- run `newgrp docker` in the same shell.

Verify:

```bash
docker ps
```

## Server File Location on EC2

Use this directory on the instance:

```bash
/home/ubuntu/Server Export
```

Expected server files:
- `MP Hot Rum.x86_64`
- `MP Hot Rum.pck`
- `Dockerfile`
- `docker-compose.yml`

## Update and Redeploy Server (Each Release)

### 1) Build/export latest server locally

From Godot export pipeline, regenerate:
- `Server Export/MP Hot Rum.x86_64`
- `Server Export/MP Hot Rum.pck`

### 2) Upload new server files to EC2

Run from your local machine:

```bash
scp -i "Godot Server Key Pair.pem" "/Users/zywiec/Documents/GameDev/mp-hot-rum/Server Export/MP Hot Rum.x86_64" ubuntu@3.19.123.12:/home/ubuntu/Server\ Export/
scp -i "Godot Server Key Pair.pem" "/Users/zywiec/Documents/GameDev/mp-hot-rum/Server Export/MP Hot Rum.pck" ubuntu@3.19.123.12:/home/ubuntu/Server\ Export/
```

### 3) SSH to EC2 and redeploy container

```bash
ssh -i "Godot Server Key Pair.pem" ubuntu@3.19.123.12
cd "/home/ubuntu/Server Export"
docker compose up -d --build --force-recreate
docker compose logs -f --tail=100
```

If you only want to restart without rebuilding image:

```bash
docker compose restart
```

## Daily Operations

From EC2 server shell:

Check running containers:

```bash
cd "/home/ubuntu/Server Export"
docker compose ps
```

View live logs:

```bash
cd "/home/ubuntu/Server Export"
docker compose logs -f
```

Stop server:

```bash
cd "/home/ubuntu/Server Export"
docker compose down
```

Start server:

```bash
cd "/home/ubuntu/Server Export"
docker compose up -d
```

## Optional Cleanup

If you see:

`the attribute version is obsolete`

Remove this line from `docker-compose.yml`:

```yaml
version: "3.9"
```

This warning is harmless, but removing the line keeps output clean.
