@echo off
TITLE GradeNexus - Production Launcher
echo ==========================================================
echo               GradeNexus Academic Platform
echo       Intelligent CGPA & Grade Sheet Analytics
echo ==========================================================
echo.

echo [1/3] Applying backend migrations...
cd backend
python manage.py migrate --no-input
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Migration failed. Check database settings.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Starting Django API Backend on http://localhost:8000 ...
start "GradeNexus Backend" /B python manage.py runserver 0.0.0.0:8000

echo.
echo [3/3] Serving GradeNexus Web Release on http://localhost:5000 ...
cd ..\frontend\build\web
start "" http://localhost:5000
python -m http.server 5000

pause
