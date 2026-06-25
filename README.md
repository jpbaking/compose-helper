# compose-helper

Scripts that wrap `docker compose` with consistent project naming, env file handling, and shorthand commands for common workflows. Copy the right one for your platform into any docker-compose project and it works.

| Platform | File |
|----------|------|
| Linux / macOS | `compose-helper.sh` (bash) |
| Windows CMD | `compose-helper.cmd` |
| Windows PowerShell | `compose-helper.ps1` |
| Any (Python 3) | `compose-helper.py` |

All four are feature-equivalent.

> **⚠️ Intended for development use only ⚠️**
> ---
> Do not use in production or CI/CD pipelines without careful review — `down` removes volumes, env files are sourced and exported into the process, and there is no access control or dry-run mode.

## Setup

### Linux / macOS

1. Copy `compose-helper.sh` into your project directory alongside `docker-compose.yaml`.
2. Make it executable: `chmod +x compose-helper.sh`
3. Optionally copy `compose-helper.env.example` to `compose-helper.env` and adjust values.

```
my-project/
├── compose-helper.sh       # this script
├── compose-helper.env      # optional — configures the script itself
├── docker-compose.yaml
└── .env                    # optional — passed to docker compose as --env-file
```

The script can also be called through a symlink — it always resolves to its real location, so the working directory is always the project folder regardless of where you call it from.

### Windows CMD

1. Copy `compose-helper.cmd` into your project directory alongside `docker-compose.yaml`.
2. Optionally copy `compose-helper.env.example` to `compose-helper.env` and adjust values.

```
my-project/
├── compose-helper.cmd      # this script
├── compose-helper.env      # optional — configures the script itself
├── docker-compose.yaml
└── .env                    # optional — passed to docker compose as --env-file
```

> **Note:** CMD does not resolve symlinks. Place the script directly in the project directory.

### Windows PowerShell

1. Copy `compose-helper.ps1` into your project directory alongside `docker-compose.yaml`.
2. Optionally copy `compose-helper.env.example` to `compose-helper.env` and adjust values.
3. If blocked by execution policy, allow local scripts once:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

```
my-project/
├── compose-helper.ps1      # this script
├── compose-helper.env      # optional — configures the script itself
├── docker-compose.yaml
└── .env                    # optional — passed to docker compose as --env-file
```

Run it as `.\compose-helper.ps1 <command>`.

> **Note:** PowerShell does not automatically resolve symlinks via `$PSScriptRoot`. Place the script directly in the project directory.

### Any platform (Python 3)

Requires Python 3.6+ on the PATH (`python3` on Linux/macOS, `python` or `py` on Windows).

1. Copy `compose-helper.py` into your project directory alongside `docker-compose.yaml`.
2. Optionally copy `compose-helper.env.example` to `compose-helper.env` and adjust values.
3. On Linux/macOS, make it executable: `chmod +x compose-helper.py`

```
my-project/
├── compose-helper.py       # this script
├── compose-helper.env      # optional — configures the script itself
├── docker-compose.yaml
└── .env                    # optional — passed to docker compose as --env-file
```

Run it as `./compose-helper.py <command>` (Linux/macOS) or `python compose-helper.py <command>` (Windows).

The Python version resolves symlinks via `os.path.realpath`, so it can safely be called through a symlink on all platforms.

## Commands

| Command   | What it does |
|-----------|--------------|
| `up`      | Rebuild → start detached → follow logs |
| `rebuild` | Rebuild → start detached |
| `build`   | Rebuild only (no start) |
| `pull`    | Pull images |
| `start`   | Start detached (no pull/build) |
| `restart` | Stop → start detached (no pull/build) |
| `stop`    | Stop with timeout, remove orphan containers |
| `down`    | Stop with timeout, remove orphans and **named volumes** |
| `logs`    | Follow logs from the last N lines |
| *(other)* | Passed directly to `docker compose` with project name and env file applied |

> **`down` removes volumes.** Use it when you want a clean slate. Use `stop` when you want to preserve data.

## Configuration

Script behaviour is controlled by environment variables. Set them in `compose-helper.env` (alongside the script), or export them in your shell before calling the script. The env file takes precedence over the calling shell.

| Variable            | Default        | Description |
|---------------------|----------------|-------------|
| `DCH_PROJECT_NAME`  | *(dir name)*   | Override the docker compose project name |
| `DCH_STOP_TIMEOUT`  | `30`           | Seconds to wait for graceful shutdown before killing containers |
| `DCH_LOGS_TAIL`     | `10`           | Lines of existing log output shown before following live output |

See `compose-helper.env.example` for a ready-to-copy template.

## Env file discovery

The script looks for a `docker compose` env file (`--env-file`) in the following order:

1. `.env` in the project root
2. `.config/.env` — for projects that keep config out of the root

Whichever is found first is passed to every `docker compose` invocation. If neither exists, no `--env-file` flag is added.

This env file is for **container variable substitution** (values referenced inside `docker-compose.yaml`). It is separate from `compose-helper.env`, which configures the script itself.

## Project naming

By default the project name is the directory name (`-p <dirname>`). This prevents docker compose from deriving the name from the caller's working directory, which can silently create duplicate projects when the script is called from different locations or via symlink.

Set `DCH_PROJECT_NAME` in `compose-helper.env` to override it:

```
DCH_PROJECT_NAME=my-custom-name
```

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

All scripts prefer the v2 plugin (`docker compose`) and fall back to the standalone v1 binary (`docker-compose`) if the plugin is not available.

## License

[0BSD](LICENSE) — do whatever you want with it.
