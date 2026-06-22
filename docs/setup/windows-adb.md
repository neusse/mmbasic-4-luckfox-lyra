# Windows ADB Setup

ADB is required to inspect the PicoCalc, push test binaries, and run smoke
tests.

On Windows with the Android SDK installed for the current user, `adb.exe` is
commonly found at:

```text
%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
```

## Add ADB To User PATH

PowerShell:

```powershell
$adbDir = "$env:LOCALAPPDATA\Android\Sdk\platform-tools"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $adbDir) {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$adbDir", 'User')
}
$env:Path = "$env:Path;$adbDir"
```

Open a new terminal after changing PATH.

## Verify

```powershell
adb version
adb devices -l
```

If `adb devices -l` shows no device:

- reconnect the PicoCalc USB cable
- confirm USB debugging or ADB access is enabled on the image
- try a different USB cable or port
- run `adb kill-server` and `adb start-server`

The setup scripts do not fabricate target data. If no device is connected, the
device checks should fail clearly.
