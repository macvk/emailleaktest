@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Email IP leak test client for bash.ws.
rem Project: https://github.com/macvk/emailleaktest
rem SPDX-License-Identifier: MIT

set "api_domain=bash.ws"
set "leak_id="
set "random_suffix=%RANDOM%-%RANDOM%"
set "id_file=%TEMP%\emailleaktest-%random_suffix%-id.tmp"
set "result_file=%TEMP%\emailleaktest-%random_suffix%-result.tmp"
set "smtp_script=%TEMP%\emailleaktest-%random_suffix%-smtp.ps1"

where curl.exe >nul 2>&1

if errorlevel 1 (
    echo Please install curl.>&2
    exit /b 1
)

call :request_id

if errorlevel 1 (
    echo Unable to obtain a test ID from %api_domain%.>&2
    call :cleanup
    exit /b 1
)

call :request_result

if errorlevel 1 (
    echo Unable to initialize the email leak test.>&2
    call :cleanup
    exit /b 1
)

> "%smtp_script%" echo $ErrorActionPreference = 'Stop'
>> "%smtp_script%" echo $to = '%leak_id%@%api_domain%'
>> "%smtp_script%" echo while ($true)
>> "%smtp_script%" echo ^{
>> "%smtp_script%" echo     $sender = Read-Host 'Sender email'
>> "%smtp_script%" echo     try
>> "%smtp_script%" echo     ^{
>> "%smtp_script%" echo         $address = [Net.Mail.MailAddress]$sender
>> "%smtp_script%" echo         break
>> "%smtp_script%" echo     ^}
>> "%smtp_script%" echo     catch
>> "%smtp_script%" echo     ^{
>> "%smtp_script%" echo         Write-Host 'Warning. Wrong email address'
>> "%smtp_script%" echo     ^}
>> "%smtp_script%" echo ^}
>> "%smtp_script%" echo $smtpHost = 'smtp.' + $address.Host
>> "%smtp_script%" echo $inputHost = Read-Host "SMTP server [$smtpHost]"
>> "%smtp_script%" echo if ($inputHost)
>> "%smtp_script%" echo ^{
>> "%smtp_script%" echo     $smtpHost = $inputHost
>> "%smtp_script%" echo ^}
>> "%smtp_script%" echo $smtpPort = 587
>> "%smtp_script%" echo $inputPort = Read-Host 'SMTP port [587]'
>> "%smtp_script%" echo if ($inputPort)
>> "%smtp_script%" echo ^{
>> "%smtp_script%" echo     $parsedPort = 0
>> "%smtp_script%" echo     if (-not [int]::TryParse($inputPort, [ref]$parsedPort) -or $parsedPort -lt 1 -or $parsedPort -gt 65535)
>> "%smtp_script%" echo     ^{
>> "%smtp_script%" echo         Write-Host 'Error. Invalid SMTP port.'
>> "%smtp_script%" echo         exit 1
>> "%smtp_script%" echo     ^}
>> "%smtp_script%" echo     $smtpPort = $parsedPort
>> "%smtp_script%" echo ^}
>> "%smtp_script%" echo $smtpUsername = Read-Host "SMTP username [$sender]"
>> "%smtp_script%" echo if (-not $smtpUsername)
>> "%smtp_script%" echo ^{
>> "%smtp_script%" echo     $smtpUsername = $sender
>> "%smtp_script%" echo ^}
>> "%smtp_script%" echo $password = Read-Host 'SMTP password' -AsSecureString
>> "%smtp_script%" echo $message = $null
>> "%smtp_script%" echo $smtp = $null
>> "%smtp_script%" echo try
>> "%smtp_script%" echo ^{
>> "%smtp_script%" echo     $message = New-Object Net.Mail.MailMessage
>> "%smtp_script%" echo     $message.From = $sender
>> "%smtp_script%" echo     [void]$message.To.Add($to)
>> "%smtp_script%" echo     $message.Subject = 'Test'
>> "%smtp_script%" echo     $message.Body = ''
>> "%smtp_script%" echo     $smtp = New-Object Net.Mail.SmtpClient($smtpHost, $smtpPort)
>> "%smtp_script%" echo     $smtp.EnableSsl = $true
>> "%smtp_script%" echo     $smtp.Credentials = New-Object Net.NetworkCredential($smtpUsername, $password)
>> "%smtp_script%" echo     $smtp.Send($message)
>> "%smtp_script%" echo ^}
>> "%smtp_script%" echo catch
>> "%smtp_script%" echo ^{
>> "%smtp_script%" echo     Write-Host 'Error. Email was not sent. Check the sender, SMTP settings, and password.'
>> "%smtp_script%" echo     exit 1
>> "%smtp_script%" echo ^}
>> "%smtp_script%" echo finally
>> "%smtp_script%" echo ^{
>> "%smtp_script%" echo     if ($null -ne $message) { $message.Dispose() }
>> "%smtp_script%" echo     if ($null -ne $smtp) { $smtp.Dispose() }
>> "%smtp_script%" echo ^}
>> "%smtp_script%" echo exit 0

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%smtp_script%"

if errorlevel 1 (
    call :cleanup
    exit /b 1
)

del /q "%smtp_script%" >nul 2>&1
<nul set /p "=Checking."

:poll
call :request_result

if errorlevel 1 (
    echo(
    echo Unable to retrieve the email leak test result.>&2
    call :cleanup
    exit /b 1
)

for /f "usebackq tokens=1-5 delims=|" %%A in ("%result_file%") do (
    if "%%E" == "done" if "%%A" == "1" goto complete
)

<nul set /p "=."
timeout /t 1 /nobreak >nul
goto poll

:complete
echo done.
echo(
echo Your IP:
for /f "usebackq tokens=1-7 delims=|" %%A in ("%result_file%") do (
    if "%%E" == "ip" call :print_address "%%A" "%%F" "%%G" "%%C" "%%D"
)

set /a ips=0
for /f "usebackq tokens=1-5 delims=|" %%A in ("%result_file%") do (
    if "%%E" == "mail" set /a ips+=1
)

echo(
if "%ips%" == "0" (
    echo No IPs found in mail header
) else if "%ips%" == "1" (
    echo Mail header has got 1 IP:
) else (
    echo Mail header has got %ips% IPs:
)

if not "%ips%" == "0" (
    for /f "usebackq tokens=1-7 delims=|" %%A in ("%result_file%") do (
        if "%%E" == "mail" call :print_address "%%A" "%%F" "%%G" "%%C" "%%D"
    )
)

echo(
echo Conclusion:
for /f "usebackq tokens=1-5 delims=|" %%A in ("%result_file%") do (
    if "%%E" == "conclusion" if not "%%A" == "" echo %%A
)

call :cleanup
exit /b 0

:request_id
curl.exe --fail --silent --show-error --max-time 30 "https://%api_domain%/id" --output "%id_file%"

if errorlevel 1 exit /b 1

findstr /r /c:"[^A-Za-z0-9]" "%id_file%" >nul

if not errorlevel 1 exit /b 1
set /p "leak_id="<"%id_file%"
del /q "%id_file%" >nul 2>&1
if not defined leak_id exit /b 1
if "%leak_id:~15,1%" == "" exit /b 1
if not "%leak_id:~16,1%" == "" exit /b 1
exit /b 0

:request_result
curl.exe --fail --silent --show-error --max-time 30 "https://%api_domain%/email-leak-test/test/%leak_id%?txt=2" --output "%result_file%"

if errorlevel 1 exit /b 1

findstr /b /c:"ERROR:" "%result_file%" >nul
if not errorlevel 1 exit /b 1
exit /b 0

:print_address
if "%~1" == "" exit /b 0
setlocal EnableDelayedExpansion
set "address_location="

for %%A in ("%~2" "%~3" "%~4" "%~5") do (
    if not "%%~A" == "" (
        if defined address_location (set "address_location=!address_location!, %%~A") else (set "address_location=%%~A")
    )
)

if not defined address_location (
    echo %~1
) else (
    echo %~1 [!address_location!]
)
endlocal
exit /b 0

:cleanup
del /q "%id_file%" "%result_file%" "%smtp_script%" >nul 2>&1
exit /b 0
