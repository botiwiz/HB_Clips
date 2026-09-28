@echo off
setlocal

echo Building HB_Clips (Windows release)...
call flutter build windows --release
if errorlevel 1 (
  echo Build failed - see errors above.
  exit /b 1
)

set "DEST=%~dp0dist\HB_Clips"
if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%"

xcopy /e /i /y "%~dp0build\windows\x64\runner\Release\*" "%DEST%\" >nul

echo.
echo Done. The portable app is in:
echo   %DEST%
echo Run %DEST%\hb_clips.exe directly, or copy/zip that whole folder anywhere.

endlocal
