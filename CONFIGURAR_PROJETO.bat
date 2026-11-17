@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo  PhysGame Gas Lab - configuracao Flutter
echo ==========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERRO: Flutter nao foi encontrado no PATH.
  echo Abra o terminal onde o comando "flutter doctor" funciona e execute este arquivo novamente.
  pause
  exit /b 1
)

echo [1/3] Gerando arquivos de plataforma...
flutter create . --project-name physgame_gas_lab
if errorlevel 1 goto :error

echo.
echo [2/3] Baixando dependencias...
flutter pub get
if errorlevel 1 goto :error

echo.
echo [3/3] Verificando dispositivos...
flutter devices

echo.
echo Projeto pronto.
echo Para executar:
echo   flutter run
echo.
pause
exit /b 0

:error
echo.
echo Ocorreu um erro durante a configuracao.
pause
exit /b 1
