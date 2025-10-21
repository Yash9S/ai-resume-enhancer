# Docker Desktop Auto-Start Configuration

## Method 1: Docker Desktop Settings
1. Open Docker Desktop
2. Go to Settings (gear icon)
3. General tab → Check "Start Docker Desktop when you sign in to Windows"
4. Resources → Advanced → Set memory to at least 4GB
5. Apply & Restart

## Method 2: Windows Startup Script
Create a Windows scheduled task to auto-start:

1. Open Task Scheduler
2. Create Basic Task
3. Name: "Start Docker Desktop"
4. Trigger: "When I log on"
5. Action: "Start a program"
6. Program: "C:\Program Files\Docker\Docker\Docker Desktop.exe"

## Method 3: PowerShell Auto-Start (Add to Windows Startup)
```powershell
# Create this file: %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\start-docker.ps1
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep 30
Set-Location "c:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"
docker-compose up database -d
```

## Quick Status Check Commands
```powershell
# Check Docker status
docker --version

# Check PostgreSQL container
docker ps | findstr database

# Start PostgreSQL manually
docker-compose up database -d

# Check PostgreSQL connection
docker exec -it ai_resume_parser-database-1 pg_isready -U ai_resume_parser
```