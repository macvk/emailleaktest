# Email IP Leak Test

Your IP can be exposed during email sending. The test analyzes mail headers and shows IP leaks.

## How to install and use

Choose the operating system you use: [Windows](#windows), [Linux and macOS](#linux-and-macos), or use the [Python](#python) or [Go](#go) version.

### Windows

Use the [batch file](#windows---batch-file) on Windows.

#### Windows - Batch file

1. Download `emailleaktest.bat`:

```powershell
powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/macvk/emailleaktest/master/emailleaktest.bat', 'emailleaktest.bat') }"
```

2. Run it:

```bat
emailleaktest.bat
```

### Linux and macOS

Use the POSIX-compatible shell script on Linux, macOS, and other systems with a POSIX shell. Make sure `curl` and `mail` are installed first.

#### Linux and macOS - POSIX shell script

1. Download `emailleaktest.sh`:

```sh
curl -fLO https://raw.githubusercontent.com/macvk/emailleaktest/master/emailleaktest.sh
```

```sh
chmod +x emailleaktest.sh
```

2. Run it:

```sh
./emailleaktest.sh
```

### Python

The Python client requires Python 3. It uses the `mail` command when available; otherwise, it asks for SMTP settings. It sends the test email automatically and waits for the result.

1. Download `emailleaktest.py`:

```sh
curl -fLO https://raw.githubusercontent.com/macvk/emailleaktest/master/emailleaktest.py
```

2. Run it with Python 3:

```sh
python3 emailleaktest.py
```

On Windows:

```bat
python emailleaktest.py
```

### Go

The Go client requires Go. It uses the `mail` command when available; otherwise, it asks for SMTP settings. It sends the test email automatically and waits for the result.

1. Download `emailleaktest.go`:

```sh
curl -fLO https://raw.githubusercontent.com/macvk/emailleaktest/master/emailleaktest.go
```

2. Build and run it:

```sh
go build -o emailleaktest emailleaktest.go
./emailleaktest
```

On Windows:

```bat
go build -o emailleaktest.exe emailleaktest.go
emailleaktest.exe
```
