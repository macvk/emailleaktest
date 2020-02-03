# Email IP Leak Test
Your IP can be exposed during email sending. The test analyzes mail headers and shows IP leaks.

## How to install & use
Please choose the operating system you use, see below. [Windows](#windows) or [Linux](#linux)

### Windows
If your operating system is Windows, then you can use [batch file](#windows---batch-file) to run the test.

#### Windows - Batch file

1. Download emailleaktest.bat

```
powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/macvk/emailleaktest/master/emailleaktest.bat', 'emailleaktest.bat') }"
```

2. Run emailleaktest.bat
```
emailleaktest.bat
```

### Linux
If your operating system is Linux, then you can use [bash shell script](#linux---bash-shell-script) to run the test.

#### Linux - Bash shell script

1. Download emailleaktest.sh
```
wget https://raw.githubusercontent.com/macvk/emailleaktest/master/emailleaktest.sh
```

```
chmod +x emailleaktest.sh
```

2. Run emailleaktest.sh
```
./emailleaktest.sh
```
