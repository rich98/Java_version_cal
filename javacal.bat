@echo off
cls
:start
cls
echo Enter your java version number (Prior to version 10) this number is found in the output file e.g. 8.0.3020.8
set /p "version=Enter the version number (or quit to exit): "
if /i "%version%"=="quit" (
	echo you chose to quit.
	exit /b
)
for /f "tokens=1-4 delims=." %%a in ("%version%") do (
	set "major=%%a"
	set "minor=%%b"
	set "patch=%%c"
	set "build=%%d"
)
if "%patch:~-1%"=="0" (
	set "patch=%patch:~0,-1%"
)
echo 1.%major%.%minor%.%patch%
pause
goto start



