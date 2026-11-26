@echo off
echo ========================================
echo نشر قواعد Firestore تلقائياً
echo ========================================
echo.

node deploy_firestore_rules.js

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo فشل النشر التلقائي
    echo ========================================
    echo.
    echo يرجى نشر القواعد يدوياً من:
    echo https://console.firebase.google.com/project/talendx-12808/firestore/rules
    echo.
    pause
) else (
    echo.
    echo ========================================
    echo تم النشر بنجاح!
    echo ========================================
    echo.
    pause
)






















