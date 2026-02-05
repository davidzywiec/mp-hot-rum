FROM debian:bookworm-slim

WORKDIR /app

# Desktop export still links against X11/font libs even when headless.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libfontconfig1 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxrandr2 \
    libxi6 \
    libxinerama1 \
    libxcursor1 \
    libgl1 \
  && rm -rf /var/lib/apt/lists/*

COPY ["MP Hot Rum.x86_64", "/app/server"]
COPY ["MP Hot Rum.pck", "/app/server.pck"]
RUN chmod +x /app/server

EXPOSE 7000/udp
ENTRYPOINT ["/app/server", "--headless", "--audio-driver", "Dummy", "--server", "--main-pack", "/app/server.pck"]
