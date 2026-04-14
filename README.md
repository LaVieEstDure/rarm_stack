# `rarm_stack`
A ROS2 based software stack for manipulation and control research with the [openarm](https://openarm.dev/) hardware platform


# Goals
- A single dockerized with docker compose that can be set up without effort
- Isolate dependencies and minimize distro dependencies using [pixi](https://pixi.prefix.dev/) for managing ROS (via [robostack](https://robostack.github.io/)) and other packages
- Mujoco based hardware simulation for testing

# How to use
```
# Run the docker container
docker compose up -d

# Enter the container
docker compose exec rarm_core bash

# Inside container now
# Build ros packages
pixi run build
```
