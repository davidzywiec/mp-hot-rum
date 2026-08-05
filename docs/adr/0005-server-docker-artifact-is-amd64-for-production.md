# Server Docker Artifact Is AMD64 for Production

The server Docker artifact is intentionally `linux/amd64` for production deployment on the Amazon server. The exported Godot server binary and Dockerfile currently target the x86_64 server build, so `docker-compose.yml` pins `platform: linux/amd64` to keep the deployment path aligned with that artifact.

This may force emulation on ARM local development machines, but production parity is the priority for the canonical Compose file. If local ARM Docker support becomes important, it should be added through a separate override or export path rather than weakening the production deployment constraint.
