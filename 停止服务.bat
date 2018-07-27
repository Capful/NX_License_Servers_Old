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

"%~dp0Windows\sh.exe" "%~dp0uninstall.sh"

goto:all_done

:debug

"%~dp0Windows\sh.exe" -x "%~dp0uninstall.sh" 2>"%~dp0uninstall.log"

goto:all_done

:no_admin

echo.
echo No administrator rights detected!
echo.
echo To install or remove services, run it as Administrator,
echo right-clicking on this script and selecting Run As Administrator
echo.

:all_done

echo.
echo NX许可服务已经卸载完成! 请手工删除本目录
echo.
pause