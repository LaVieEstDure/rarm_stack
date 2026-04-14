# syntax=docker/dockerfile:1

# ── Stage 1: install pixi environment ────────────────────────────────────────
# Use the versioned pixi image instead of curl-installing an unversioned binary.
FROM ghcr.io/prefix-dev/pixi:0.67.0 AS install

WORKDIR /app/ros_ws

# Copy only the dependency manifests first for better layer caching.
# Source code is not needed to install the conda/ROS environment.
COPY ./pixi.toml ./pixi.lock ./

COPY ./deps/ ./deps/

# Install all conda/ROS packages. The rattler cache mount avoids re-downloading
# packages on rebuilds (sharing=private prevents cross-build contamination).
RUN --mount=type=cache,target=/root/.cache/rattler/cache,sharing=private \
    pixi install

# Bake the environment activation into a standalone entrypoint script.
# pixi shell-hook emits bash export statements + runs all activate.d scripts,
# including the RoboStack one that sources ros2 setup.sh and sets ROS_DISTRO,
# AMENT_PREFIX_PATH, etc.
RUN printf '#!/bin/bash\n# Named volumes for colcon output are created root-owned by Docker; fix on\n# first container start (no-op once they are already writable).\n[ -w /app/ros_ws/log ] || sudo chown -R "$(id -u):$(id -g)" /app/ros_ws/build /app/ros_ws/install /app/ros_ws/log\n%s\nexec "$@"\n' \
        "$(pixi shell-hook --shell bash)" \
    > /entrypoint.sh \
    && chmod +x /entrypoint.sh


# ── Stage 2: dev container ───────────────────────────────────────────────────
FROM ubuntu:24.04

ARG USERNAME=rarm
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ENV DEBIAN_FRONTEND=noninteractive

# Minimal host-level tools only. The full C/C++ toolchain (gcc, g++, cmake,
# make, ninja, pkg-config) comes from conda via the pixi env, so build-essential
# is not needed here.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    sudo \
    vim \
    software-properties-common \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libegl-mesa0 \
    libglu1-mesa \
    && add-apt-repository -y ppa:openarm/main \
    && apt-get update && apt-get install -y --no-install-recommends \
    libopenarm-can-dev \
    openarm-can-utils \
    && rm -rf /var/lib/apt/lists/*

# Recreate non-root user. Ubuntu 24.04 ships a default `ubuntu` user at
# UID 1000, so remove it first to free up that UID/GID slot.
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Copy the pixi binary so the user can run pixi commands interactively.
COPY --from=install /usr/local/bin/pixi /usr/local/bin/pixi

# Copy the pre-installed pixi environment and manifests. The ~1.5 GB env is
# baked in here so container startup requires no network or solver activity.
COPY --from=install --chown=$USER_UID:$USER_GID /app /app

# Copy the generated environment activation entrypoint.
COPY --from=install /entrypoint.sh /entrypoint.sh

USER $USERNAME

# uv: Python dependency manager. Installs to ~/.local/bin/uv.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# pixi binary is at /usr/local/bin/pixi (system PATH). Only uv needs to be
# added via the user's local bin.
ENV PATH=/home/$USERNAME/.local/bin:$PATH
ENV SHELL=/bin/bash

WORKDIR /app/

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
