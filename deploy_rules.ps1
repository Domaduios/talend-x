Write-Host "========================================" -ForegroundColor Cyan
Write-Host "نشر قواعد Firestore تلقائياً" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    node deploy_firestore_rules.js
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "تم النشر بنجاح!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "⏱️  انتظر 10-30 ثانية ثم جرّب التطبيق مرة أخرى." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "فشل النشر التلقائي" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "يرجى نشر القواعد يدوياً من:" -ForegroundColor Yellow
        Write-Host "https://console.firebase.google.com/project/talendx-12808/firestore/rules" -ForegroundColor Cyan
    }
} catch {
    Write-Host ""
    Write-Host "❌ خطأ: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "يرجى نشر القواعد يدوياً من:" -ForegroundColor Yellow
    Write-Host "https://console.firebase.google.com/project/talendx-12808/firestore/rules" -ForegroundColor Cyan
}

Write-Host ""
Read-Host "اضغط Enter للخروج"






















