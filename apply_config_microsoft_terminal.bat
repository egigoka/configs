REM linking this config to real config

FOR /f "tokens=* delims=" %%A in ('dir %LOCALAPPDATA% /s /b ^| C:\Windows\System32\findstr.exe \Microsoft.WindowsTerminal ^| C:\Windows\System32\findstr.exe /e settings.json') do @set "LINK=%%A"

echo %LINK%

FOR /f "tokens=* delims=" %%A in ('cd') do @set "TARGETDIR=%%A"

echo %TARGETDIR%

del %LINK%

mklink %LINK% %TARGETDIR%\microsoft_terminal_settings.json

REM registering fonts, not tested, syntax is okay, I guess

for /F "usebackq delims=" %%F in (`dir "SourceCodePro github.com powerline fonts\*.otf" /b`) do (
	fontreg\FontReg32.exe "%TARGETDIR%\SourceCodePro github.com powerline fonts\%%F"
)

for /F "usebackq delims=" %%F in (`dir "SourceCodePro github.com powerline fonts\*.otf" /b`) do (
	fontreg\FontReg64.exe "%TARGETDIR%\SourceCodePro github.com powerline fonts\%%F"
)