# compose-helper

A single bash script that wraps `docker compose` with consistent project naming, env file discovery, and shorthand commands for common workflows. Copy it into any docker-compose project and it works.

## Setup

1. Copy `compose-helper` into your project directory alongside `docker-compose.yaml`.
2. Make it executable: `chmod +x compose-helper`
3. Optionally copy `compose-helper.env.example` to `compose-helper.env` and adjust values.

```
my-project/
├── compose-helper          # this script
├── compose-helper.env      # optional — configures the script itself
├── docker-compose.yaml
└── .env                    # optional — passed to docker compose as --env-file
```

The script can also be called through a symlink — it always resolves to its real location, so the working directory is always the project folder regardless of where you call it from.

## Commands

| Command   | What it does |
|-----------|--------------|
| `up`      | Pull images → rebuild → start detached → follow logs |
| `rebuild` | Pull images → rebuild → start detached |
| `build`   | Pull images → rebuild only (no start) |
| `start`   | Start detached, no pull or build |
| `restart` | Stop → start detached, no pull or build |
| `stop`    | Stop with timeout, remove orphan containers |
| `down`    | Stop with timeout, remove orphans and **named volumes** |
| `logs`    | Follow logs from the last N lines |
| *(other)* | Passed directly to `docker compose` with project name and env file applied |

> **`down` removes volumes.** Use it when you want a clean slate. Use `stop` when you want to preserve data.

## Configuration

Script behaviour is controlled by two environment variables. Set them in `compose-helper.env` (alongside the script), or export them in your shell before calling the script. The env file takes precedence over the calling shell.

| Variable           | Default | Description |
|--------------------|---------|-------------|
| `DCH_STOP_TIMEOUT` | `30`    | Seconds to wait for graceful shutdown before killing containers |
| `DCH_LOGS_TAIL`    | `10`    | Lines of existing log output shown before following live output |

See `compose-helper.env.example` for a ready-to-copy template.

## Env file discovery

The script looks for a `docker compose` env file (`--env-file`) in the following order:

1. `.env` in the project root
2. `.config/.env` — for projects that keep config out of the root

Whichever is found first is passed to every `docker compose` invocation. If neither exists, no `--env-file` flag is added.

This env file is for **container variable substitution** (values referenced inside `docker-compose.yaml`). It is separate from `compose-helper.env`, which configures the script itself.

## Project naming

The project name is always set to the directory name (`-p <dirname>`). This prevents docker compose from deriving the name from the caller's working directory, which can silently create duplicate projects when the script is called from different locations or via symlink.

## The `--profile build` convention (optional)

The `build`, `rebuild`, and `up` commands use `--profile build` when running `docker compose build`. This supports a pattern where services that exist solely to produce a local image are placed under the `build` profile in `docker-compose.yaml`:

```yaml
services:
  my-app-builder:
    profiles: [build]
    build: ./my-app
    image: my-app:local

  my-app:
    image: my-app:local
    # ... no build: block; uses the image produced above
```

Running `compose-helper build` builds the `build`-profile services and tags the images. Running `compose-helper start` then starts the regular services using those images.

If you don't use this pattern, the `--profile build` flag is harmless — it simply targets no services during the build step.

## docker compose v1 vs v2

The script prefers the v2 plugin (`docker compose`) and falls back to the standalone v1 binary (`docker-compose`) if the plugin is not available.

## License

[0BSD](LICENSE) — do whatever you want with it.
