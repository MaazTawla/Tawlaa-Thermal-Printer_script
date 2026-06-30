@echo off
title Thermal Printer Service Installer
color 0A

echo ============================================================
echo Installing Thermal Printer Service...
echo ============================================================

set /p BRANCH_ID=Enter Branch ID (numbers only): 

if "%BRANCH_ID%"=="" (
    echo No Branch ID entered. Aborting installation.
    pause
    exit /b
)

set /p RECEIPT_SIZE=Enter receipt size in mm (default 80): 

if "%RECEIPT_SIZE%"=="" set "RECEIPT_SIZE=80"

echo %RECEIPT_SIZE%| findstr /r "^[0-9][0-9]*$" >nul
if %ERRORLEVEL% NEQ 0 (
    echo Invalid receipt size "%RECEIPT_SIZE%". Numbers only. Aborting installation.
    pause
    exit /b
)

set "BASE_DIR=%~dp0"
set "NODE_PATH=%BASE_DIR%node-v16\node.exe"
set "SCRIPT_PATH=%BASE_DIR%Tawlaweb-app\thermal-printer.js"
set "WORK_DIR=%BASE_DIR%Tawlaweb-app"
set "TEMP_XML=%TEMP%\thermal_task.xml"

echo Updating CHANNEL in thermal-printer.js to branch ID %BRANCH_ID%...
powershell -Command "(Get-Content '%SCRIPT_PATH%') -replace 'const CHANNEL = \"orders-[0-9]+\";', 'const CHANNEL = \"orders-%BRANCH_ID%\";' | Set-Content '%SCRIPT_PATH%'"

if %ERRORLEVEL% NEQ 0 (
    echo Failed to update CHANNEL. Aborting.
    pause
    exit /b
)

echo Updating RECEIPT_WIDTH_MM in thermal-printer.js to %RECEIPT_SIZE% mm...
powershell -Command "(Get-Content '%SCRIPT_PATH%') -replace 'const RECEIPT_WIDTH_MM = [0-9]+;', 'const RECEIPT_WIDTH_MM = %RECEIPT_SIZE%;' | Set-Content '%SCRIPT_PATH%'"

if %ERRORLEVEL% NEQ 0 (
    echo Failed to update RECEIPT_WIDTH_MM. Aborting.
    pause
    exit /b
)

for /f "delims=" %%a in ('whoami') do set "CURRENT_USER=%%a"

echo Preparing task XML...
powershell -Command ^
    "$node = '%NODE_PATH:\=\\%'; $script = '%SCRIPT_PATH:\=\\%'; $work = '%WORK_DIR:\=\\%'; $user = '%CURRENT_USER%'; $branch = '%BRANCH_ID%';" ^
    "(Get-Content '%BASE_DIR:\=\\%task-template.xml')" ^
    " -replace '__NODE_PATH__', $node" ^
    " -replace '__SCRIPT_PATH__', $script" ^
    " -replace '__WORK_DIR__', $work" ^
    " -replace '__CURRENT_USER__', $user" ^
    " | Out-File '%TEMP_XML%' -Encoding Unicode"

echo Removing any existing task...
schtasks /delete /tn "Thermal Printer" /f >nul 2>&1

echo Creating Windows Task...
schtasks /create /tn "Thermal Printer" /xml "%TEMP_XML%" /f

if %ERRORLEVEL% EQU 0 (
    echo Installation complete.
    echo Branch ID set to: %BRANCH_ID%
    echo Receipt size set to: %RECEIPT_SIZE% mm
) else (
    echo Failed to create the task. Check permissions or XML syntax.
)

pause