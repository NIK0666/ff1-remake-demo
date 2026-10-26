@echo off
setlocal
cd /d "%~dp0"
set "GODOT_EXE="
for %%G in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v*-stable_win64.exe") do if exist "%%~fG" set "GODOT_EXE=%%~fG"
if defined GODOT_EXE goto launch
for /f "delims=" %%G in ('where godot 2^>nul') do set "GODOT_EXE=%%G"
if defined GODOT_EXE goto launch
echo Open project.godot in Godot 4.7 and press F5.
pause
exit /b
:launch
"%GODOT_EXE%" --headless --editor --path "%~dp0." --import --quit --log-file "%~dp0docs\import.log" >nul 2>nul
start "Cornelia" "%GODOT_EXE%" --path "%~dp0."
