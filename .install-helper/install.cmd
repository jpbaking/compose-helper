@echo off
rem Github: https://github.com/jpbaking/compose-helper
rem Installs compose-helper.cmd into the current directory.
rem Run from inside your project directory (alongside docker-compose.yaml):
rem   curl -fsSL https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install.cmd -o "%TEMP%\dch-install.cmd" && "%TEMP%\dch-install.cmd"

setlocal EnableDelayedExpansion

set "BASE=https://raw.githubusercontent.com/jpbaking/compose-helper/main"
set "SCRIPT=compose-helper.cmd"
set "ENV_FILE=compose-helper.env"
set "ENV_EXAMPLE_URL=%BASE%/compose-helper.env.example"
set "TEMP_EXAMPLE=%TEMP%\dch-env-example-%RANDOM%.tmp"

echo ==^> Downloading %SCRIPT%...
curl -fsSL "%BASE%/%SCRIPT%" -o "%SCRIPT%"
if %errorlevel% neq 0 ( echo Error: download failed & exit /b 1 )
echo     OK

echo ==^> Checking %ENV_FILE%...
curl -fsSL "%ENV_EXAMPLE_URL%" -o "%TEMP_EXAMPLE%"
if %errorlevel% neq 0 ( echo Error: could not download example & goto :cleanup )

if not exist "%ENV_FILE%" (
    copy /y "%TEMP_EXAMPLE%" "%ENV_FILE%" >nul
    echo     Created %ENV_FILE%
    goto :cleanup
)

rem Check for new keys in the example not present in the existing env file.
rem Reads each KEY=value line from the example, strips leading # and spaces,
rem then checks whether that key appears (active or commented) in the env file.
set "FOUND_NEW="
for /f "usebackq tokens=1 delims==" %%K in ("%TEMP_EXAMPLE%") do call :check_key "%%K"

if defined FOUND_NEW (
    echo     %ENV_FILE% already exists -- not overwritten.
    echo     See %ENV_EXAMPLE_URL% to add the new keys listed above.
) else (
    echo     %ENV_FILE% is up to date -- not overwritten.
)

:cleanup
del /q "%TEMP_EXAMPLE%" >nul 2>&1
echo.
echo Done. Run: %SCRIPT% --help
endlocal
goto :eof

rem Subroutine: strips leading spaces and # from the token, then checks
rem whether the resulting key exists in the env file.
:check_key
set "K=%~1"
:strip_space
if "!K:~0,1!"==" " ( set "K=!K:~1!" & goto :strip_space )
:strip_hash
if "!K:~0,1!"=="#" ( set "K=!K:~1!" & goto :strip_hash )
if "!K!"=="" goto :eof
rem Skip tokens that don't look like variable names (e.g. pure comment lines)
echo !K! | findstr /r "^[A-Za-z_]" >nul 2>&1 || goto :eof
rem Key is new if it appears in neither active nor commented form in the env file
findstr /i /b /c:"!K!=" "%ENV_FILE%" >nul 2>&1 && goto :eof
findstr /i /b /c:"#!K!=" "%ENV_FILE%" >nul 2>&1 && goto :eof
echo       New key not in %ENV_FILE%: !K!
set "FOUND_NEW=1"
goto :eof
