; �ýű�ʹ�� HM VNISEdit �ű��༭���򵼲���

; ��װ�����ʼ���峣��
!define PRODUCT_NAME "NX License Servers"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "Capful"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

SetCompressor lzma

; ------ MUI �ִ����涨�� (1.67 �汾���ϼ���) ------
!include "MUI.nsh"
!include "WinMessages.nsh"

; MUI Ԥ���峣��
!define MUI_ABORTWARNING
!define MUI_ICON "Icon\Install.ico"
!define MUI_UNICON "Icon\Uninstall.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "Icon\WizardImage3.bmp"

;�޸ı���
!define MUI_WELCOMEPAGE_TITLE "\r\n   NX License Servers װ��"
;�޸Ļ�ӭҳ���ϵ���������
!define MUI_WELCOMEPAGE_TEXT  "\r\n    NX License Servers ��UG NXͨ�õ����֤�ļ���\r\n\r\n    ֧��NX6-NX12�汾��һ����װ���֤�ļ���Ĭ�ϰ�\r\n    װ��D�̸�Ŀ¼��\r\n\r\n����$_CLICK"
; ��ӭҳ��
!insertmacro MUI_PAGE_WELCOME

; ������־
!define MUI_PAGE_HEADER_TEXT "NX Customized V${PRODUCT_VERSION} ������־"
!define MUI_PAGE_HEADER_SUBTEXT " "
!define MUI_LICENSEPAGE_TEXT_TOP "Ҫ������־�����ಿ���뻬���������·�ҳ��"
!define MUI_LICENSEPAGE_TEXT_BOTTOM "��� ��һ��(N) > ������װ��"
!define MUI_LICENSEPAGE_BUTTON "��һ��(&N) >"
!insertmacro MUI_PAGE_LICENSE "changelog.txt"


; ��װĿ¼ѡ��ҳ��
;!insertmacro MUI_PAGE_DIRECTORY

; ��װ����ҳ��
!insertmacro MUI_PAGE_INSTFILES

; ��װ���ҳ��
!insertmacro MUI_PAGE_FINISH
;!define MUI_FINISHPAGE_RUN "$INSTDIR\MAKER.exe"

; ��װж�ع���ҳ��
!insertmacro MUI_UNPAGE_INSTFILES

; ��װ�����������������
!insertmacro MUI_LANGUAGE "SimpChinese"

; ��װԤ�ͷ��ļ�
!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS
; ------ MUI �ִ����涨����� ------

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
  File "��װ����.bat"
  File "ֹͣ����.bat"
  SetOutPath "$INSTDIR\Icon"
  File "Icon\*.*"
  SetOutPath "$INSTDIR\Windows"
  File "Windows\*.*"
  SetOutPath "$INSTDIR\Vendors"
  File /r "Vendors\*.*"
  Call anzhuang
  #�ļ����Զ���ͼ��
  StrCpy $0 "$INSTDIR"
  StrCpy $1 "$INSTDIR\icon\logo.ico"
  SetOutPath "$0"
  WriteINIStr "$0\desktop.ini" ".ShellClassInfo" "IconResource" '"$1",0'
  nsExec::Exec 'attrib +s +h "$0\desktop.ini"'
  nsExec::Exec 'attrib +s "$0"'
  System::Call 'Shell32::SHChangeNotify(i 0x8000000, i 0, i 0, i 0)'
SectionEnd



Section -Post
  WriteUninstaller "$INSTDIR\ж��.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\ж��.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\icon\logo.ico"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd

Function anzhuang
  Push $R1
  #��װ���֤����
  nsExec::Exec "$INSTDIR\��װ����.bat"
  # ��ȡ�������
  ReadRegStr $R1 HKLM "SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" "ComputerName"
  # �޸����֤��������
  WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "SPLM_LICENSE_SERVER" "27800@$R1"
  # ˢ�»�������
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment"  /TIMEOUT=5000
  Exch $R1
FunctionEnd

Function .onInit
  ;�رս���
  Push $R0
  CheckProc:
  Push "ugraf.exe"
  ProcessWork::existsprocess
  Pop $R0
  IntCmp $R0 0 Done
  MessageBox MB_OKCANCEL|MB_ICONSTOP "��װ�����⵽ UG �������С�$\r$\n$\r$\n��� ��ȷ���� ǿ�ƹر�UG����ȷ�ϱ���UG�ĵ���$\r$\n��� ��ȡ���� �˳����֤��װ����" IDCANCEL Exit
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
 *  �����ǰ�װ�����ж�ز���  *
 ******************************/

Section Uninstall
  Delete "$INSTDIR\*.*"
  RMDir /r "$INSTDIR"
SectionEnd

#-- ���� NSIS �ű��༭�������� Function ���α�������� Section ����֮���д���Ա��ⰲװ�������δ��Ԥ֪�����⡣--#

Function un.onInit
  ;�رս���
  Push $R0
  CheckProc:
  Push "ugraf.exe"
  ProcessWork::existsprocess
  Pop $R0
  IntCmp $R0 0 Done
  MessageBox MB_OKCANCEL|MB_ICONSTOP "ж�س����⵽ UG �������С�$\r$\n$\r$\n��� ��ȷ���� ǿ�ƹر�UG����ȷ�ϱ���UG�ĵ���$\r$\n��� ��ȡ���� �˳�ж�س���" IDCANCEL Exit
  Push "ugraf.exe"
  Processwork::KillProcess
  Sleep 1000
  Goto CheckProc
  Exit:
  Abort
  Done:
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "��ȷʵҪ��ȫ�Ƴ� $(^Name) ���������е������" IDYES +2
  Abort
  Call un.xiezai
FunctionEnd

Function un.xiezai
  Push $R1
  #��װ���֤����
  nsExec::Exec "$INSTDIR\ֹͣ����.bat"
  # ��ȡ�������
  ReadRegStr $R1 HKLM "SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" "ComputerName"
  # �޸����֤��������
  WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "SPLM_LICENSE_SERVER" "28000@$R1"
  # ˢ�»�������
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
  Exch $R1
FunctionEnd



