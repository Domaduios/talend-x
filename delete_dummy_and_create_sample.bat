@echo off
echo ========================================
echo Deleting Dummy Data and Creating Sample
echo ========================================
echo.

echo Step 1: Deleting dummy data...
node delete_dummy_data.js
echo.

echo Step 2: Creating sample data...
node create_sample_data.js
echo.

echo Done!
pause


















