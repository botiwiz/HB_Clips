@echo off
setlocal

echo Building HB_Clips (Windows release)...
rem --no-tree-shake-icons: release builds subset the Material Icons font
rem down to only the codepoints Flutter's static analysis can prove are
rem referenced, dropping every other glyph entirely - button containers
rem still render at their normal size, just empty, since the icon itself
rem no longer exists in the shipped font. Full icon set is a few hundred
rem KB; worth keeping over debugging which specific icon dropped out next.
call flutter build windows --release --no-tree-shake-icons
if errorlevel 1 (
  echo Build failed - see errors above.
  exit /b 1
)

set "DEST=%~dp0dist\HB_Clips"
if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%"

xcopy /e /i /y "%~dp0build\windows\x64\runner\Release\*" "%DEST%\" >nul

powershell -NoProfile -Command "$s = (New-Object -COM WScript.Shell).CreateShortcut('%~dp0hb_clips - Shortcut.lnk'); $s.TargetPath = '%DEST%\hb_clips.exe'; $s.WorkingDirectory = '%DEST%'; $s.Save()"

echo.
echo Done. The portable app is in:
echo   %DEST%
echo A shortcut is ready at %~dp0hb_clips - Shortcut.lnk
echo Run %DEST%\hb_clips.exe directly, or copy/zip that whole folder anywhere.

endlocal
