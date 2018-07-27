@echo off
cd /d "%~dp0"
cacls.exe "%SystemDrive%\System Volume Information" >nul 2>nul
if %errorlevel%==0 goto Admin
if exist "%temp%\getadmin.vbs" del /f /q "%temp%\getadmin.vbs"
echo Set RequestUAC = CreateObject^("Shell.Application"^)>"%temp%\getadmin.vbs"
echo RequestUAC.ShellExecute "%~s0","","","runas",1 >>"%temp%\getadmin.vbs"
echo WScript.Quit >>"%temp%\getadmin.vbs"
"%temp%\getadmin.vbs" /f
if exist "%temp%\getadmin.vbs" del /f /q "%temp%\getadmin.vbs"
exit

:Admin
set OSARCH=%PROCESSOR_ARCHITECTURE%
set "_THIS_SCRIPT=%~0"
set "PATH=%~dp0Windows;%Windir%"

if exist "%~dp0debug" goto:debug

"%~dp0Windows\sh.exe" "%~dp0install_or_update.sh"

goto:all_done

:debug

"%~dp0Windows\sh.exe" -x "%~dp0install_or_update.sh" 2>"%~dp0\install_or_update.log"

goto:all_done


:all_done

echo.
echo NX许可服务已经安装完成! 
echo.
pause