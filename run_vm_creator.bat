@echo off
echo Running VM creation script with administrator privileges...
echo This script creates a Ubuntu VM with fully automated SSH configuration.
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0create_ubuntu_vm_clean.ps1"