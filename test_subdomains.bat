@echo off
echo Testing subdomain resolution...
echo.

echo Testing basic localhost:
ping -n 1 localhost > nul
if %errorlevel%==0 (
    echo ✓ localhost resolves correctly
) else (
    echo ✗ localhost resolution failed
)

echo.
echo Testing subdomain resolution:
ping -n 1 acme.localhost > nul
if %errorlevel%==0 (
    echo ✓ acme.localhost resolves correctly
) else (
    echo ✗ acme.localhost does not resolve - needs hosts file update
)

echo.
echo Testing lvh.me alternative:
ping -n 1 acme.lvh.me > nul
if %errorlevel%==0 (
    echo ✓ acme.lvh.me resolves correctly
) else (
    echo ✗ acme.lvh.me resolution failed
)

echo.
echo === SOLUTION ===
echo If acme.localhost failed, you have two options:
echo.
echo Option 1: Add to hosts file (C:\Windows\System32\drivers\etc\hosts):
echo    127.0.0.1    acme.localhost
echo    127.0.0.1    all.localhost
echo.
echo Option 2: Use lvh.me instead:
echo    http://acme.lvh.me:3000
echo    http://all.lvh.me:3000/admin
echo.
pause