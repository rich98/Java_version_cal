@echo off
setlocal enabledelayedexpansion
:begin
cls
color 0F
set /p BMN="Please enter the BMN number as a numerical number only e.g. 1234: "

echo Set Data classification Valid entries:O, OS, S, SUKEO, OCCAR-R, C1, C2, C3, C4
set /p govclass="Please set the classification of Data? "

if /i "%govclass%"=="o" (
    set clss="OFFICIAL"
) else if /i "%govclass%"=="os" (
    set clss="OFFICIAL SENSITIVE"
) else if /i "%govclass%"=="s" (
    set clss="SECRET"
) else if /i "%govclass%"=="sukeo" (
    set clss="SUKEO"
) else if /i "%govclass%"=="occar-r" (
    set clss="OCCAR-RESCRICTED"
) else if /i "%govclass%"=="c1" (
    set clss="C1:OPEN DESIGNED TO BE SHARED PUBLICLY"
) else if /i "%govclass%"=="c2" (
    set clss="C2:GROUP LIMITED DISTRIBUTION"
) else if /i "%govclass%"=="c3" (
    set clss="C3:GROUP CONFIDENTIAL- SENSITIVE INFORMATION"
) else if /i "%govclass%"=="c4" (
    set clss="C4:GROUP SECRET- EXTREMELY SENSITIVE INFORMATION"
) else (
    echo Not a valid answer. Please try again.
    timeout /t 2 >nul
    cls
    goto begin
)
if /i "%govclass%"=="s" (
    set clss="SECRET"
    color 4F
)

if /i "%govclass%"=="sukeo" (
    set clss="SUKEO"
    color 4F
)
set "search_file1=*java.exe"
set "search_file2=*javaw.exe"

rem Get the current date and time
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"

set "datestamp=%YYYY%%MM%%DD%-%HH%%Min%"
set "results_file=BMN%BMN%-%computername%-%datestamp%-%govclass%.txt"
echo ***** Data classification set to %clss% *****
echo ***** Data classification set to %clss% ***** >> %results_file%

rem Get list of local drives
for /f %%d in ('wmic logicaldisk where "drivetype=3" get caption ^| find ":"') do (
    echo Searching in %%d\
    call :search "%%d\" %search_file1%
    call :search "%%d\" %search_file2%
)

echo ***** Data classification set to %clss% *****
echo Hostname: %computername% >> %results_file%
echo BMN Number: BMN%BMN% >> %results_file%
echo User selected classification: %clss% >> %results_file%
@echo off
REM check if JAVA_HOME is defined and test
if not defined JAVA_HOME (
  echo JAVA_HOME is not set >> %results_file%
  goto end
)
REM run java -version using JAVA_HOME
rem echo Running java -version
rem "%JAVA_HOME%\bin\java.exe" -version

echo "Script message ***** Running java env check *****"
echo ***** java env check *****

@echo off
REM check if JAVA_HOME is defined
if not defined JAVA_HOME (
  echo JAVA_HOME is not set
  goto end
)

REM run java -version using JAVA_HOME
echo Running java -version
"%JAVA_HOME%\bin\java.exe" -version >> %results_file%

:end
echo Search complete. Results saved to %results_file%

set /p rerun="Do you want to rerun the script? (yes/no): "
if /i "%rerun%"=="yes" goto begin
 
:search
for /r %1 %%f in (%2) do (
    echo Found: %%f >> %results_file%
    echo Found: %%f
    
    rem Display only "Name" and "Version" properties using WMIC
    set "filepath=%%f"
    for /f "tokens=1,* delims==" %%p in ('wmic datafile where "name='!filepath:\=\\!'" get /format:list ^| find "="') do (
        if "%%p"=="Manufacturer" (
            echo File Property: %%q >> %results_file%
            echo File Property: %%q
            echo %%q | findstr /C:"Oracle Corporation" >nul && (
                echo WARNING: Oracle Java found: %%f >> %results_file%
                echo WARNING: Oracle Java found: %%f
            )
            echo %%q | findstr /C:"Sun Microsystems" >nul && (
                echo WARNING: Sun Java found: %%f >> %results_file%
                echo WARNING: Sun Java found: %%f
            )
        )

if "%%p"=="Version" (
    echo Original Version: %%q
    rem Extract major, minor, and patch versions
    for /f "tokens=1-3 delims=." %%v in ("%%q") do (
        set "major=%%v"
        set "minor=%%w"
        set "patch=%%x"
    )
    echo Major: !major!, Minor: !minor!, Patch: !patch!
    rem Format according to Java versioning schema
    if !major! LSS 9 (
        set "java_version=1.!major!.!minor!_!patch!"
    ) else (
        set "java_version=!major!.!minor!.!patch!"
    )
    echo Java Version: !java_version! >> %results_file%
    echo Java Version: !java_version!
)

    )
)
exit /b






