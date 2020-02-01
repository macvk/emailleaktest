# Email IP Leak Test
Your IP can be exposed during email sending. The test analyzes mail headers and shows IP leaks.

## Windows

1. Download emailleaktest.bat

```
powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/macvk/emailleaktest/master/emailleaktest.bat', 'emailleaktest.bat') }"
```

2. Run emailleaktest.bat
```
emailleaktest.bat
```

## Linux

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
