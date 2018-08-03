; 该脚本使用 HM VNISEdit 脚本编辑器向导产生

; 安装程序初始定义常量
!define PRODUCT_NAME "NX License Servers"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "Capful"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

SetCompressor lzma

; ------ MUI 现代界面定义 (1.67 版本以上兼容) ------
!include "MUI.nsh"
!include "WinMessages.nsh"

; MUI 预定义常量
!define MUI_ABORTWARNING
!define MUI_ICON "Icon\Install.ico"
!define MUI_UNICON "Icon\Uninstall.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "Icon\WizardImage3.bmp"

;修改标题
!define MUI_WELCOMEPAGE_TITLE "\r\n   NX License Servers 装向导"
;修改欢迎页面上的描述文字
!define MUI_WELCOMEPAGE_TEXT  "\r\n    NX License Servers 是UG NX通用的许可证文件。\r\n\r\n    支持NX6-NX12版本，一键安装许可证文件，默认安\r\n    装在D盘根目录。\r\n\r\n　　$_CLICK"
; 欢迎页面
!insertmacro MUI_PAGE_WELCOME

; 更新日志
!define MUI_PAGE_HEADER_TEXT "NX Customized V${PRODUCT_VERSION} 更新日志"
!define MUI_PAGE_HEADER_SUBTEXT " "
!define MUI_LICENSEPAGE_TEXT_TOP "要更新日志的其余部分请滑动滚轮往下翻页。"
!define MUI_LICENSEPAGE_TEXT_BOTTOM "点击 下一步(N) > 继续安装。"
!define MUI_LICENSEPAGE_BUTTON "下一步(&N) >"
!insertmacro MUI_PAGE_LICENSE "changelog.txt"


; 安装目录选择页面
;!insertmacro MUI_PAGE_DIRECTORY

; 安装过程页面
!insertmacro MUI_PAGE_INSTFILES

; 安装完成页面
!insertmacro MUI_PAGE_FINISH
;!define MUI_FINISHPAGE_RUN "$INSTDIR\MAKER.exe"

; 安装卸载过程页面
!insertmacro MUI_UNPAGE_INSTFILES

; 安装界面包含的语言设置
!insertmacro MUI_LANGUAGE "SimpChinese"

; 安装预释放文件
!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS
; ------ MUI 现代界面定义结束 ------

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "NX_License_Servers_v${PRODUCT_VERSION}.exe"
InstallDir "D:\NX_License_Servers"
ShowInstDetails show
ShowUnInstDetails show
BrandingText "   Capful Build"

Section "MainSection" SEC01
  SetOutPath "$INSTDIR"
  File "install_or_update.sh"
  File "uninstall.sh"
  File "安装服务.bat"
  File "停止服务.bat"
  SetOutPath "$INSTDIR\Icon"
  File "Icon\*.*"
  SetOutPath "$INSTDIR\Windows"
  File "Windows\*.*"
  SetOutPath "$INSTDIR\Vendors"
  File /r "Vendors\*.*"
  Call anzhuang
  #文件夹自定义图标
  StrCpy $0 "$INSTDIR"
  StrCpy $1 "$INSTDIR\icon\logo.ico"
  SetOutPath "$0"
  WriteINIStr "$0\desktop.ini" ".ShellClassInfo" "IconResource" '"$1",0'
  nsExec::Exec 'attrib +s +h "$0\desktop.ini"'
  nsExec::Exec 'attrib +s "$0"'
  System::Call 'Shell32::SHChangeNotify(i 0x8000000, i 0, i 0, i 0)'
SectionEnd



Section -Post
  WriteUninstaller "$INSTDIR\卸载.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\卸载.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\icon\logo.ico"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd

Function anzhuang
  Push $R1
  #安装许可证服务
  nsExec::Exec "$INSTDIR\安装服务.bat"
  # 获取计算机名
  ReadRegStr $R1 HKLM "SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" "ComputerName"
  # 修改许可证环境变量
  WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "SPLM_LICENSE_SERVER" "27800@$R1"
  # 刷新环境变量
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment"  /TIMEOUT=5000
  Exch $R1
FunctionEnd

Function .onInit
  ;关闭进程
  Push $R0
  CheckProc:
  Push "ugraf.exe"
  ProcessWork::existsprocess
  Pop $R0
  IntCmp $R0 0 Done
  MessageBox MB_OKCANCEL|MB_ICONSTOP "安装程序检测到 UG 正在运行。$\r$\n$\r$\n点击 “确定” 强制关闭UG，请确认保存UG文档。$\r$\n点击 “取消” 退出许可证安装程序。" IDCANCEL Exit
  Push "ugraf.exe"
  Processwork::KillProcess
  Sleep 1000
  Goto CheckProc
  Exit:
  Abort
  Done:
  Pop $R0
FunctionEnd

/******************************
 *  以下是安装程序的卸载部分  *
 ******************************/

Section Uninstall
  Delete "$INSTDIR\*.*"
  RMDir /r "$INSTDIR"
SectionEnd

#-- 根据 NSIS 脚本编辑规则，所有 Function 区段必须放置在 Section 区段之后编写，以避免安装程序出现未可预知的问题。--#

Function un.onInit
  ;关闭进程
  Push $R0
  CheckProc:
  Push "ugraf.exe"
  ProcessWork::existsprocess
  Pop $R0
  IntCmp $R0 0 Done
  MessageBox MB_OKCANCEL|MB_ICONSTOP "卸载程序检测到 UG 正在运行。$\r$\n$\r$\n点击 “确定” 强制关闭UG，请确认保存UG文档。$\r$\n点击 “取消” 退出卸载程序。" IDCANCEL Exit
  Push "ugraf.exe"
  Processwork::KillProcess
  Sleep 1000
  Goto CheckProc
  Exit:
  Abort
  Done:
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "您确实要完全移除 $(^Name) ，及其所有的组件？" IDYES +2
  Abort
  Call un.xiezai
FunctionEnd

Function un.xiezai
  Push $R1
  #安装许可证服务
  nsExec::Exec "$INSTDIR\停止服务.bat"
  # 获取计算机名
  ReadRegStr $R1 HKLM "SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" "ComputerName"
  # 修改许可证环境变量
  WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "SPLM_LICENSE_SERVER" "28000@$R1"
  # 刷新环境变量
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
  Exch $R1
FunctionEnd



