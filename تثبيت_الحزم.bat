@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================
echo تثبيت الحزم المطلوبة
echo ========================================
echo.
echo المجلد الحالي: %CD%
echo.
flutter pub get
echo.
pause






















