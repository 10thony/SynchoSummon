# Thin, pin-able wrapper around Oracle Database Free.
# Prefer volume-mounted init/seed scripts over baking SQL into the image
# so you can iterate without rebuilding.
#
# Tags: https://hub.docker.com/r/gvenzl/oracle-free/tags
# slim-faststart trades image size for faster cold starts (good for local/dev).
FROM gvenzl/oracle-free:23-slim-faststart

LABEL org.opencontainers.image.title="SyncEngine Oracle Free"
LABEL org.opencontainers.image.description="Local Oracle Database Free for SyncEngine development and prod simulation"
