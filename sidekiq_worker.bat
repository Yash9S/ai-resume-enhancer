@echo off
title Sidekiq Worker - AI Resume Parser
echo ========================================
echo Starting Sidekiq Worker
echo ========================================
echo.
echo Press Ctrl+C to stop the worker
echo.

cd /d "C:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"
ruby start_sidekiq.rb

echo.
echo Worker stopped.
pause