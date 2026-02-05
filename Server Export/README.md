# Server Export

This folder contains a Linux export plus a Docker setup to run a dedicated server
in headless mode. Follow the steps below to build and run the server locally.

## Prerequisites

- Docker Desktop installed and running.
- A Linux export in this folder:
  - `MP Hot Rum.x86_64`
  - `MP Hot Rum.pck`

## Step 1: Build the Docker image

From this folder:

```bash
docker build -t hotrum-server .
```

## Step 2: Run the server (foreground)

```bash
docker run --rm -p 7000:7000/udp hotrum-server
```

The server will start and log to the terminal. Leave it running while clients connect.

## Step 3 (optional): Run with Docker Compose

```bash
docker compose up --build
```

Detached (run in background):

```bash
docker compose up -d --build
```

View logs:

```bash
docker compose logs -f
```

Stop:

```bash
docker compose down
```

## Troubleshooting

- **Port already in use**: Stop the existing container or use a different host port.
- **Missing export files**: Re-export the Linux build into this folder.

## Notes

- The server listens on UDP port `7000`.
- If you rename the export files, update the `Dockerfile` COPY lines.
