@echo off

rem Any questions: tutumbul@gmail.com
rem https://bash.ws/emailleak

for /F "tokens=*" %%g IN ('powershell -command "& { Get-Random -Minimum 1000000 -Maximum 9999999 }"') do (set /a leak_id=%%g)

rem echo %leak_id%

powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://bash.ws/email-leak-test/test/%leak_id%?txt', '%leak_id%.txt') }"

echo $to = "%leak_id%@bash.ws" > r.ps1
echo while ($true) >> r.ps1
echo ^{ >> r.ps1
echo $username = Read-Host 'What is your email?' >> r.ps1
echo if ($username.indexOf("@") -ne -1) >> r.ps1
echo ^{ >> r.ps1
echo break; >> r.ps1
echo ^} >> r.ps1
echo ^echo "Warning. Wrong email address"; >> r.ps1
echo ^} >> r.ps1
echo if ($username.indexOf("@gmail.com")) >> r.ps1
echo ^{ >> r.ps1
echo ^echo "Warning. Please enable less secure apps to get the script working, https://myaccount.google.com/lesssecureapps"; >> r.ps1
echo ^} >> r.ps1
echo $smtpdomain = $username.Substring($username.indexOf("@")+1); >> r.ps1
echo $smtpdomain = "smtp.$smtpdomain"; >> r.ps1
echo $inputsmtp = Read-Host "What is your outgoing smtp server [leave empty to use $smtpdomain]?" >> r.ps1
echo if ($inputsmtp -ne "") >> r.ps1
echo ^{ >> r.ps1
echo $smtp = $inputsmtp; >> r.ps1
echo ^} >> r.ps1
echo $password = Read-Host 'What is your password?' -AsSecureString >> r.ps1
echo $pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)) >> r.ps1
echo $message = new-object Net.Mail.MailMessage; >> r.ps1
echo $message.From = $username; >> r.ps1
echo $message.To.Add($to);; >> r.ps1
echo $message.Subject = ""; >> r.ps1
echo $message.Body = ""; >> r.ps1
echo ^echo "$smtp"; >> r.ps1
echo $smtp = new-object Net.Mail.SmtpClient($smtpdomain, "587"); >> r.ps1
echo $smtp.EnableSSL = $true; >> r.ps1
echo $smtp.Credentials = New-Object System.Net.NetworkCredential($username, $pw); >> r.ps1
echo $result = 1; >> r.ps1
echo try >> r.ps1
echo ^{ >> r.ps1
echo $smtp.send($message); >> r.ps1
echo ^} >> r.ps1
echo catch >> r.ps1
echo ^{ >> r.ps1
echo ^echo "Error. Email was not sent, please check username and password. Try again..." >> r.ps1
echo $result = 0; >> r.ps1
echo ^} >> r.ps1
echo exit $result; >> r.ps1

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './r.ps1'"


if "%errorlevel%" == "0" (
   del /q %leak_id%.txt
   del /q r.ps1
   exit
)


echo|set /p="Checking."

:loop

powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://bash.ws/email-leak-test/test/%leak_id%?txt', '%leak_id%.txt') }"

echo|set /p="."

for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
    if "%%5" == "done" (
        if "%%1" == "1" (
            goto :stop
        ) 
    )
)
    
goto loop

:stop

echo done.

echo Your IP:
for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
    if "%%5" == "ip" (
        if [%%1] neq [] (
            if [%%3] neq [] (
                if [%%4] neq [] (
                    echo %%1 [%%3, %%4]
                ) else (
                    echo %%1 [%%3]
                )
            ) else (
                echo %%1
            )
        ) 
    )
)

set /a ips=0

for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
    if "%%5" == "mail" (
        set /a ips=ips+1
    )
)

if "%ips%" == "0" (
    echo No IPs found in mail header
) else (
    echo Your email header has %ips% IPs:
    for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
        if "%%5" == "mail" (
            if [%%1] neq [] (
                if [%%3] neq [] (
                    if [%%4] neq [] (
                        echo %%1 [%%3, %%4]
                    ) else (
                        echo %%1 [%%3]
                    )
                ) else (
                    echo %%1
                )
            ) 
        )
    )
)

echo Conclusion:
for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
    if "%%5" == "conclusion" (
        if [%%1] neq [] (
            echo %%1
        ) 
    )
)


del /q %leak_id%.txt
del /q r.ps1
