@echo off
title OCULIS DR Screening Pipeline API
echo =======================================================================
echo          OCULIS - AI Diabetic Retinopathy Screening API
echo =======================================================================
echo.

cd /d "%~dp0"

echo [1/2] Checking Python environment...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not found in your PATH.
    echo Please install Python 3.9+ from python.org and check "Add to PATH".
    pause
    exit /b 1
)

echo [2/2] Launching FastAPI Backend on http://localhost:8000 ...
echo - API Docs (Swagger):  http://localhost:8000/docs
echo - Mock Test Endpoint: http://localhost:8000/api/mock
echo - Screening Endpoint: POST http://localhost:8000/api/screen
echo.
echo Press Ctrl+C to stop the server.
echo.

python -m uvicorn app:app --host 0.0.0.0 --port 8000 --reload
pause
