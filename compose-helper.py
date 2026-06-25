#!/usr/bin/env python3
# Author: jpbaking (https://github.com/jpbaking)
#
# Thin wrapper around docker compose (cross-platform Python port).
# Must live alongside docker-compose.yaml. Mirrors compose-helper (bash).
#
# WARNING: Intended for local development use only. Do not use in production
# or CI/CD pipelines without careful review -- 'down' removes volumes, env
# files are loaded into the process, and there is no dry-run mode.

import os
import sys
import shutil
import subprocess

# os.path.realpath resolves symlinks, so the working directory is always the
# script's real location regardless of where the caller is or how it's invoked.
SCRIPT_PATH = os.path.realpath(__file__)
SCRIPT_DIR  = os.path.dirname(SCRIPT_PATH)
SCRIPT_NAME = os.path.splitext(os.path.basename(SCRIPT_PATH))[0]

os.chdir(SCRIPT_DIR)

# Prefer v2 plugin ("docker compose") over standalone v1 binary.
def find_dc():
    result = subprocess.run(
        ["docker", "compose", "version"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if result.returncode == 0:
        return ["docker", "compose"]
    if shutil.which("docker-compose"):
        return ["docker-compose"]
    print("Error: neither 'docker compose' nor 'docker-compose' found", file=sys.stderr)
    sys.exit(1)

DC = find_dc()

# Find compose file.
if os.path.isfile("docker-compose.yaml"):
    COMPOSE_FILE = "docker-compose.yaml"
elif os.path.isfile("docker-compose.yml"):
    COMPOSE_FILE = "docker-compose.yml"
else:
    print(f"Error: no docker-compose.yaml or docker-compose.yml found in {SCRIPT_DIR}", file=sys.stderr)
    sys.exit(1)

# Load (script_name).env -- configures DCH itself; overrides caller environment.
# Blank lines and lines beginning with # are skipped.
config_file = os.path.join(SCRIPT_DIR, f"{SCRIPT_NAME}.env")
if os.path.isfile(config_file):
    with open(config_file) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, val = line.partition("=")
                os.environ[key.strip()] = val.strip()

PROJECT_NAME = os.environ.get("DCH_PROJECT_NAME") or os.path.basename(SCRIPT_DIR)
STOP_TIMEOUT = os.environ.get("DCH_STOP_TIMEOUT", "30")
LOGS_TAIL    = os.environ.get("DCH_LOGS_TAIL", "10")

# Base args applied to every docker compose invocation.
DC_OPTS = ["-p", PROJECT_NAME, "-f", COMPOSE_FILE]

# .env is passed to docker compose for container variable substitution.
if os.path.isfile(".env"):
    DC_OPTS += ["--env-file", ".env"]
elif os.path.isfile(os.path.join(".config", ".env")):
    DC_OPTS += ["--env-file", os.path.join(".config", ".env")]


def run_dc(*args):
    result = subprocess.run(DC + DC_OPTS + list(args))
    if result.returncode != 0:
        sys.exit(result.returncode)


def usage():
    print(f"""\
Usage: {SCRIPT_NAME} <command> [args]

Commands:
  up       Rebuild, start detached, then follow logs
  rebuild  Rebuild, start detached
  build    Rebuild only (no start)
  pull     Pull images
  start    Start detached (no pull/build)
  restart  Stop then start detached (no pull/build)
  stop     Stop with {STOP_TIMEOUT}s timeout, remove orphans
  down     Stop with {STOP_TIMEOUT}s timeout, remove orphans and volumes
  logs     Follow logs from last {LOGS_TAIL} lines
  <other>  Pass arguments directly to docker compose

Environment (set in {SCRIPT_NAME}.env):
  DCH_PROJECT_NAME  Override project name (default: directory name)
  DCH_STOP_TIMEOUT  Shutdown timeout in seconds (default: 30)
  DCH_LOGS_TAIL     Log tail line count (default: 10)

Project: {PROJECT_NAME}  Compose: {COMPOSE_FILE}
""")


cli_args = sys.argv[1:]
command  = cli_args[0] if cli_args else ""

if command in ("", "--help", "-h"):
    usage()
elif command == "up":
    run_dc("--profile", "build", "build", "--pull")
    run_dc("up", "-d")
    run_dc("logs", "-f", f"--tail={LOGS_TAIL}")
elif command == "start":
    run_dc("up", "-d")
elif command == "pull":
    run_dc("pull")
elif command == "build":
    run_dc("--profile", "build", "build", "--pull")
elif command == "rebuild":
    run_dc("--profile", "build", "build", "--pull")
    run_dc("up", "-d")
elif command == "restart":
    run_dc("down", "-t", STOP_TIMEOUT, "--remove-orphans")
    run_dc("up", "-d")
elif command == "stop":
    run_dc("down", "-t", STOP_TIMEOUT, "--remove-orphans")
elif command == "down":
    run_dc("down", "-t", STOP_TIMEOUT, "--remove-orphans", "-v")
elif command == "logs":
    run_dc("logs", "-f", f"--tail={LOGS_TAIL}")
else:
    run_dc(*cli_args)
