@echo off
setlocal EnableExtensions
title Atualizador de Drivers do Windows

:: Verifica privilegios e eleva para Administrador quando necessario.
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Solicitando permissao de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "SCRIPT=%~dp0Atualizar-Drivers.ps1"
if not exist "%SCRIPT%" (
    echo ERRO: O arquivo Atualizar-Drivers.ps1 nao foi encontrado.
    pause
    exit /b 1
)

:MENU
cls
echo =============================================
echo       ATUALIZADOR DE DRIVERS DO WINDOWS
echo =============================================
echo.
echo 1 - Verificar drivers disponiveis
echo 2 - Atualizar drivers com ponto de restauracao
echo 3 - Atualizar drivers e reiniciar o computador
echo 4 - Abrir PowerShell nesta pasta
echo 5 - Abrir pasta do projeto e logs
echo 0 - Sair
echo.
choice /C 123450 /N /M "Escolha uma opcao: "

if errorlevel 6 exit /b 0
if errorlevel 5 (
    start "" explorer.exe "%~dp0"
    goto MENU
)
if errorlevel 4 (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -Command "Set-Location -LiteralPath \"%~dp0\""
    pause
    goto MENU
)
if errorlevel 3 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Atualizar -CriarPontoRestauracao -ReiniciarSeNecessario
    pause
    goto MENU
)
if errorlevel 2 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Atualizar -CriarPontoRestauracao
    pause
    goto MENU
)
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -WhatIf
    pause
    goto MENU
)

goto MENU
