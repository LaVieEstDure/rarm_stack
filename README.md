# `rarm_stack`
A ROS2 based software stack for manipulation and control research with the [openarm](https://openarm.dev/) hardware platform


# Goals
- A single dockerized with docker compose that can be set up without effort
- Isolate dependencies and minimize distro dependencies using [pixi](https://pixi.prefix.dev/) for managing ROS (via [robostack](https://robostack.github.io/)) and other packages
- Mujoco based hardware simulation for testing

# Choose an environment

The default Pixi environment contains the ROS packages for simulation and visualization. It works on Linux x86-64 and macOS Apple Silicon. The `hardware` environment adds OpenArm CAN, its Python binding, and the OpenArm hardware interface; it is available only on Linux x86-64.

On a simulation machine:

```bash
pixi install
pixi run build
```

On a Linux hardware machine:

```bash
pixi install --environment hardware
pixi run --environment hardware build-hardware
```

Run other commands in the chosen environment with `pixi run` or `pixi run --environment hardware`. The simulation build skips `openarm`, `openarm_can`, and `openarm_hardware`; the hardware build includes them. The workspace overlay is sourced automatically after the first build.

The Docker Compose image uses the same choice. The default build uses the simulation environment. For a Linux hardware image, set `PIXI_ENVIRONMENT=hardware` when building and starting it:

```bash
docker compose up -d --build
docker compose exec rarm_core bash
pixi run build

# On the hardware machine instead:
PIXI_ENVIRONMENT=hardware docker compose up -d --build
docker compose exec rarm_core bash
pixi run --environment hardware build-hardware
```
