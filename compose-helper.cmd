@echo off
setlocal EnableDelayedExpansion

rem Author: jpbaking (https://github.com/jpbaking)
rem
rem Thin wrapper around docker compose for Windows CMD.
rem Must live alongside docker-compose.yaml. Mirrors compose-helper (bash).
rem
rem WARNING: Intended for local development use only. Do not use in production
rem or CI/CD pipelines without careful review -- 'down' removes volumes, env
rem files are loaded into the process, and there is no dry-run mode.
rem
rem NOTE: CMD does not resolve symlinks. Place the script directly in the
rem project directory; calling via .lnk shortcut will not work as expected.

rem %~dp0 is the drive+path of this batch file with a trailing backslash.
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "SCRIPT_NAME=%~n0"

cd /d "%SCRIPT_DIR%"

rem Prefer v2 plugin ("docker compose") over standalone v1 binary.
docker compose version >nul 2>&1
if %errorlevel% equ 0 (
    set "DC=docker compose"
    goto :dc_found
)
where docker-compose >nul 2>&1
if %errorlevel% equ 0 (
    set "DC=docker-compose"
    goto :dc_found
)
echo Error: neither 'docker compose' nor 'docker-compose' found >&2
exit /b 1
:dc_found

if exist "docker-compose.yaml" (
    set "COMPOSE_FILE=docker-compose.yaml"
) else if exist "docker-compose.yml" (
    set "COMPOSE_FILE=docker-compose.yml"
) else (
    echo Error: no docker-compose.yaml or docker-compose.yml found in %SCRIPT_DIR% >&2
    exit /b 1
)

rem Load (script_name).env -- configures DCH itself; overrides caller environment.
rem Lines starting with # are skipped. Empty lines are skipped automatically.
if exist "%SCRIPT_NAME%.env" (
    for /f "usebackq eol=# tokens=*" %%a in ("%SCRIPT_NAME%.env") do (
        set "%%a"
    )
)

rem DCH_PROJECT_NAME overrides the directory-derived project name.
if defined DCH_PROJECT_NAME (
    set "PROJECT_NAME=%DCH_PROJECT_NAME%"
) else (
    for %%a in ("%SCRIPT_DIR%") do set "PROJECT_NAME=%%~na"
)

if not defined DCH_STOP_TIMEOUT set "DCH_STOP_TIMEOUT=30"
if not defined DCH_LOGS_TAIL set "DCH_LOGS_TAIL=10"

rem .env is passed to docker compose for container variable substitution.
set "DC_ENVFILE="
if exist ".env" (
    set "DC_ENVFILE=--env-file .env"
) else if exist ".config\.env" (
    set "DC_ENVFILE=--env-file .config\.env"
)

goto :main

rem -------------------------------------------------------------------------
rem Subroutine: call :run_dc <args...>
rem Expands to: %DC% -p <project> -f <compose_file> [--env-file <file>] <args>
rem -------------------------------------------------------------------------
:run_dc
%DC% -p "%PROJECT_NAME%" -f "%COMPOSE_FILE%" %DC_ENVFILE% %*
exit /b %errorlevel%

:usage
echo Usage: %SCRIPT_NAME% ^<command^> [args]
echo.
echo Commands:
echo   up       Pull images, rebuild, start detached, then follow logs
echo   rebuild  Pull images, rebuild, start detached
echo   build    Pull images and rebuild only (no start)
echo   start    Start detached (no pull/build)
echo   restart  Stop then start detached (no pull/build)
echo   stop     Stop with %DCH_STOP_TIMEOUT%s timeout, remove orphans
echo   down     Stop with %DCH_STOP_TIMEOUT%s timeout, remove orphans and volumes
echo   logs     Follow logs from last %DCH_LOGS_TAIL% lines
echo   ^<other^>  Pass arguments directly to docker compose
echo.
echo Environment (set in %SCRIPT_NAME%.env):
echo   DCH_PROJECT_NAME  Override project name (default: directory name)
echo   DCH_STOP_TIMEOUT  Shutdown timeout in seconds (default: 30)
echo   DCH_LOGS_TAIL     Log tail line count (default: 10)
echo.
echo Project: %PROJECT_NAME%  Compose: %COMPOSE_FILE%
exit /b 0

rem -------------------------------------------------------------------------
:main
rem -------------------------------------------------------------------------

if "%~1"=="" goto :usage
if /i "%~1"=="--help" goto :usage

if /i "%~1"=="up"       goto :cmd_up
if /i "%~1"=="start"    goto :cmd_start
if /i "%~1"=="build"    goto :cmd_build
if /i "%~1"=="rebuild"  goto :cmd_rebuild
if /i "%~1"=="restart"  goto :cmd_restart
if /i "%~1"=="stop"     goto :cmd_stop
if /i "%~1"=="down"     goto :cmd_down
if /i "%~1"=="logs"     goto :cmd_logs
goto :cmd_passthrough

:cmd_up
call :run_dc pull
call :run_dc build --profile build --pull
call :run_dc up -d
call :run_dc logs -f --tail=%DCH_LOGS_TAIL%
goto :eof

:cmd_start
call :run_dc up -d
goto :eof

:cmd_build
call :run_dc pull
call :run_dc build --profile build --pull
goto :eof

:cmd_rebuild
call :run_dc pull
call :run_dc build --profile build --pull
call :run_dc up -d
goto :eof

:cmd_restart
call :run_dc down -t %DCH_STOP_TIMEOUT% --remove-orphans
call :run_dc up -d
goto :eof

:cmd_stop
call :run_dc down -t %DCH_STOP_TIMEOUT% --remove-orphans
goto :eof

:cmd_down
call :run_dc down -t %DCH_STOP_TIMEOUT% --remove-orphans -v
goto :eof

:cmd_logs
call :run_dc logs -f --tail=%DCH_LOGS_TAIL%
goto :eof

:cmd_passthrough
call :run_dc %*
goto :eof
