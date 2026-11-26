@echo off
chcp 65001 >nul
echo ========================================
echo نشر قواعد Firestore تلقائياً
echo ========================================
echo.

echo جاري تثبيت المكتبات المطلوبة...
call npm install google-auth-library --silent

echo.
echo جاري نشر القواعد...
node publish_rules_final.js

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo تم النشر بنجاح!
    echo ========================================
    echo.
    echo انتظر 10-30 ثانية ثم جرّب التطبيق
) else (
    echo.
    echo ========================================
    echo فشل النشر التلقائي
    echo ========================================
    echo.
    echo يرجى النشر يدوياً من:
    echo https://console.firebase.google.com/project/talendx-12808/firestore/rules
)

echo.
pause






















