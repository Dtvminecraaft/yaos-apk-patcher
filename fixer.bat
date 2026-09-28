@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title APK Patcher для Яндекс ТВ

REM ==== Проверка аргументов ====
if "%~1"=="" (
    echo.
    echo Перетащите APK-файл на этот скрипт.
    echo.
    pause
    exit /b 1
)

set "APK=%~f1"
set "WORKDIR=%~dp0"
set "TEMP_FOLDER=%WORKDIR%_temp_apk"
set "JAVA_EXE=java"

for %%F in ("%APK%") do set "BASENAME=%%~nF"
set "OUT_APK=%WORKDIR%!BASENAME!_patched.apk"

echo.
echo ============================================================
echo  APK Patcher для Яндекс ТВ (обычная версия)
echo ============================================================
echo  Исходный файл: %APK%
echo  Выходной файл: !BASENAME!_patched.apk
echo  Удаляемых разрешений: 8
echo.

REM ============================================================
REM  ПРОВЕРКА И АВТОУСТАНОВКА JAVA
REM ============================================================
echo [0/4] Проверка наличия Java...

set "JAVA_FOUND=0"

where java >nul 2>nul
if not errorlevel 1 (
    for /f "delims=" %%j in ('where java 2^>nul') do (
        set "JAVA_EXE=%%j"
        set "JAVA_FOUND=1"
        goto :java_ok
    )
)

if exist "C:\Program Files\Eclipse Adoptium\" (
    for /d %%d in ("C:\Program Files\Eclipse Adoptium\jdk-*") do (
        if exist "%%d\bin\java.exe" (
            set "JAVA_EXE=%%d\bin\java.exe"
            set "JAVA_FOUND=1"
            goto :java_ok
        )
    )
)

if exist "C:\Program Files\Java\" (
    for /d %%d in ("C:\Program Files\Java\jdk-*") do (
        if exist "%%d\bin\java.exe" (
            set "JAVA_EXE=%%d\bin\java.exe"
            set "JAVA_FOUND=1"
            goto :java_ok
        )
    )
)

:java_ok
if "%JAVA_FOUND%"=="1" (
    echo  Java найдена: !JAVA_EXE!
    goto :after_java
)

echo  Java не найдена. Начинаю установку Eclipse Temurin JDK 17...
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo [ОШИБКА] Для установки Java нужны права администратора.
    echo Запустите этот скрипт от имени администратора и повторите.
    pause & exit /b 1
)

set "JAVA_MSI=%TEMP%\TemurinJDK17.msi"
set "JAVA_URL=https://api.adoptium.net/v3/installer/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"

echo  Скачивание установщика Java...
powershell -NoProfile -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "try {" ^
  "  Invoke-WebRequest -Uri '%JAVA_URL%' -OutFile '%JAVA_MSI%' -UseBasicParsing;" ^
  "  Write-Host '  Скачивание завершено.'" ^
  "} catch {" ^
  "  Write-Host ('  [ОШИБКА] Не удалось скачать Java: '+$_.Exception.Message);" ^
  "  exit 1" ^
  "}"

if errorlevel 1 (
    echo [ОШИБКА] Скачать Java не удалось. Проверьте интернет.
    pause & exit /b 1
)

echo.
echo  Установка Java (тихий режим, 1-2 минуты)...
msiexec /i "%JAVA_MSI%" /qn ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome /norestart

if errorlevel 1 (
    echo [ОШИБКА] Установка Java не удалась (код: %errorlevel%).
    echo Установите вручную: https://adoptium.net/temurin/releases/?version=17
    pause & exit /b 1
)

del /q "%JAVA_MSI%" 2>nul
echo  Java успешно установлена.

set "JAVA_FOUND=0"
for /d %%d in ("C:\Program Files\Eclipse Adoptium\jdk-*") do (
    if exist "%%d\bin\java.exe" (
        set "JAVA_EXE=%%d\bin\java.exe"
        set "JAVA_FOUND=1"
    )
)
if "%JAVA_FOUND%"=="0" (
    echo [ОШИБКА] Java установлена, но не найдена в ожидаемой папке.
    echo Закройте скрипт и запустите снова.
    pause & exit /b 1
)

echo  Использую: !JAVA_EXE!
echo.

:after_java
echo.

REM ==== Проверка нужных файлов ====
if not exist "%WORKDIR%apktool.jar" (
    echo [ОШИБКА] Не найден apktool.jar в папке скрипта.
    pause & exit /b 1
)
if not exist "%WORKDIR%uber-apk-signer.jar" (
    echo [ОШИБКА] Не найден uber-apk-signer.jar в папке скрипта.
    pause & exit /b 1
)

REM ==== Очистка предыдущих временных данных ====
if exist "%TEMP_FOLDER%" rmdir /s /q "%TEMP_FOLDER%"
if exist "%OUT_APK%" del /q "%OUT_APK%"
if exist "%OUT_APK%.idsig" del /q "%OUT_APK%.idsig" 2>nul

REM ==== Декомпиляция ====
echo [1/4] Распаковка APK...
"!JAVA_EXE!" -jar "%WORKDIR%apktool.jar" d "%APK%" -o "%TEMP_FOLDER%" -f
if errorlevel 1 (
    echo [ОШИБКА] Не удалось распаковать APK.
    pause & exit /b 1
)

REM ==== Удаление запрещённых разрешений ====
echo.
echo [2/4] Удаление запрещённых разрешений (8 штук)...

set "MANIFEST=%TEMP_FOLDER%\AndroidManifest.xml"
if not exist "%MANIFEST%" (
    echo [ОШИБКА] Не найден AndroidManifest.xml.
    pause & exit /b 1
)

powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$manifest='%MANIFEST%';" ^
  "$forbidden=@('android.permission.INSTALL_PACKAGES','android.permission.REQUEST_INSTALL_PACKAGES','android.permission.REQUEST_DELETE_PACKAGES','android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION','android.permission.ENFORCE_UPDATE_OWNERSHIP','android.permission.BIND_DEVICE_ADMIN','android.permission.SYSTEM_ALERT_WINDOW','android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS');" ^
  "[xml]$doc=Get-Content -Path $manifest -Raw -Encoding UTF8;" ^
  "$ns=New-Object System.Xml.XmlNamespaceManager($doc.NameTable);" ^
  "$ns.AddNamespace('android','http://schemas.android.com/apk/res/android');" ^
  "$removed=0;" ^
  "foreach($tag in @('uses-permission','uses-permission-sdk-23')){" ^
  "  $nodes=@($doc.SelectNodes('//'+$tag,$ns));" ^
  "  foreach($n in $nodes){" ^
  "    $name=$n.GetAttribute('name','http://schemas.android.com/apk/res/android');" ^
  "    if($forbidden -contains $name){" ^
  "      $n.ParentNode.RemoveChild($n) | Out-Null;" ^
  "      Write-Host ('  Удалено: '+$name);" ^
  "      $removed++" ^
  "    }" ^
  "  }" ^
  "}" ^
  "if($removed -eq 0){Write-Host '  Запрещённых разрешений не найдено.'}else{Write-Host ('  Всего удалено: '+$removed)}" ^
  "$settings=New-Object System.Xml.XmlWriterSettings;" ^
  "$settings.Indent=$true;" ^
  "$settings.Encoding=New-Object System.Text.UTF8Encoding($false);" ^
  "$w=[System.Xml.XmlWriter]::Create($manifest,$settings);" ^
  "$doc.Save($w);" ^
  "$w.Close()"

if errorlevel 1 (
    echo [ОШИБКА] Не удалось изменить манифест.
    pause & exit /b 1
)

REM ==== Сборка ====
echo.
echo [3/4] Сборка APK...
"!JAVA_EXE!" -jar "%WORKDIR%apktool.jar" b "%TEMP_FOLDER%" -o "%OUT_APK%"
if errorlevel 1 (
    echo [ОШИБКА] Не удалось собрать APK.
    pause & exit /b 1
)

REM ==== Подпись ====
echo.
echo [4/4] Подпись APK...
"!JAVA_EXE!" -jar "%WORKDIR%uber-apk-signer.jar" --apks "%OUT_APK%" --overwrite
if errorlevel 1 (
    echo [ОШИБКА] Не удалось подписать APK.
    pause & exit /b 1
)

REM ==== Итог ====
echo.
echo ============================================================
echo  ГОТОВО!
echo ============================================================
echo  Подписанный APK:
echo    %OUT_APK%
echo.
echo  Файл %OUT_APK%.idsig — подпись v4 для Google Play,
echo  для установки на ТВ не нужен, можно удалить.
echo.
echo  ⚠  Перед установкой удалите старую версию приложения.
echo.
rmdir /s /q "%TEMP_FOLDER%" 2>nul
echo.
pause