FROM debian:bookworm-slim

# Keep the base image generic and small; add only tools needed for repo work.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends bash ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]

