@echo off
chcp 936 >nul
title GitHub 加速器 + 诊断 v2026.11.10
setlocal enabledelayedexpansion
set "VER=2026.11.10"

:: ============================================================
::  GitHub 一键打开工具
::  双击 -> 能开就直接开；打不开自动修复后再开
::  菜单: GitHub.bat /menu
:: ============================================================

set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
set "HOSTS_BAK=%HOSTS%.bak"
set "HOSTS_ORIG=%HOSTS%.gh520.orig"
set "CACHE_DIR=%TEMP%\gh520"
set "TMPFILE=%CACHE_DIR%\hosts_tmp.txt"
set "CACHE_FILE=%CACHE_DIR%\hosts_cached.txt"
set "TIMESTAMP_FILE=%CACHE_DIR%\timestamp.txt"
set "MARKER_START=GitHub520 Host Start"
set "MARKER_END=GitHub520 Host End"
set "TASK_NAME=GitHub-Hosts-Update"
set "LAUNCHER=%~dp0gh520_launcher.vbs"
set "TARGET_URL=https://github.com"

:: ------------------------------------------------------------
::  参数解析（兼容旧的 /startup /install /uninstall /check）
:: ------------------------------------------------------------
set "ARG1=%~1"
set "ARG2=%~2"
set "ARG3=%~3"
set "PRESET_IP="
if /i "%ARG1%"=="/elevated" set "ELEVATED=1"
if /i "%ARG1%"=="/elevated" set "PRESET_IP=%ARG3%"
if /i "%ARG1%"=="/elevated" set "ARG1=%ARG2%"
if /i "%ARG1%"=="/quickfix" if defined ARG2 set "PRESET_IP=%ARG2%"

if /i "%ARG1%"=="/startup"       goto :startup
if /i "%ARG1%"=="/install"       goto :task_install
if /i "%ARG1%"=="/taskinstall"   goto :task_install
if /i "%ARG1%"=="/taskuninstall" goto :task_uninstall
if /i "%ARG1%"=="/uninstall"     goto :full_uninstall
if /i "%ARG1%"=="/restorebak"    goto :restore_bak
if /i "%ARG1%"=="/restoreorig"   goto :restore_orig
if /i "%ARG1%"=="/strip"         goto :strip_only
if /i "%ARG1%"=="/check"     goto :diag
if /i "%ARG1%"=="/diag"      goto :diag
if /i "%ARG1%"=="/accel"     goto :accel_core
if /i "%ARG1%"=="/repair"    goto :repair_core
if /i "%ARG1%"=="/mirror"    goto :mirror_core
if /i "%ARG1%"=="/restore"   goto :restore_core
if /i "%ARG1%"=="/task"      goto :task_core
if /i "%ARG1%"=="/gitfix"    goto :gitfix_cli
if /i "%ARG1%"=="/open"      goto :open_github
if /i "%ARG1%"=="/quickfix"  goto :quickfix_core
if /i "%ARG1%"=="/pickip"    goto :pickip_cli
if /i "%ARG1%"=="/menu"      goto :menu
:: 无参数（双击）＝ 直接打开 GitHub，打不开就自动修复
goto :quick_open


:: ============================================================
::  主菜单
:: ============================================================
:menu
cls
echo ============================================================
echo            GitHub 加速器 + 诊断  v!VER!
echo ============================================================
call :status_line
echo ------------------------------------------------------------
echo   [1] 一键修复可用  写 hosts；网页不通时自动建立 git 通道
echo   [2] 一键修复    强制刷新 / 去重 / 回滚 / 自检
echo   [3] 网络诊断    区分 hosts 失效与 443 被墙
echo   [4] 镜像兜底    git 走镜像下载（可撤销）
echo   [5] 计划任务    登录后自动更新 hosts
echo   [6] 恢复清理    回滚 hosts 备份 / 彻底卸载
echo   [7] 打开 GitHub  能通就开，不通自动修复后再试
echo   [0] 退出
echo ============================================================
set "CH="
set /p "CH=请输入选项并回车: "
if not defined CH exit /b
if "%CH%"=="1" goto :accel_core
if "%CH%"=="2" goto :repair_core
if "%CH%"=="3" goto :diag
if "%CH%"=="4" goto :mirror_core
if "%CH%"=="5" goto :task_core
if "%CH%"=="6" goto :restore_core
if "%CH%"=="7" goto :open_github
if "%CH%"=="0" exit /b
goto :menu


:: ============================================================
::  状态行
:: ============================================================
:status_line
set "HS=未配置"
%SystemRoot%\System32\findstr.exe /c:"%MARKER_START%" "%HOSTS%" >nul 2>&1
if not errorlevel 1 set "HS=已配置"
set "CS=无缓存"
if exist "%CACHE_FILE%" set "CS=有缓存"
if exist "%TIMESTAMP_FILE%" (
    set "CT="
    set /p "CT="<"%TIMESTAMP_FILE%"
    if defined CT set "CS=缓存 !CT!"
)
set "TS=未安装"
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if not errorlevel 1 set "TS=已安装"
echo   hosts: !HS!    !CS!    计划任务: !TS!
echo   提示: 直接双击本文件 = 打开 GitHub（打不开会自动修复）
exit /b


:: ============================================================
::  管理员权限请求
::  返回值 0=已有权限  1=用户拒绝/失败  2=已在新窗口继续
:: ============================================================
:require_admin
net session >nul 2>&1
if not errorlevel 1 exit /b 0
if defined ELEVATED (
    echo [警告] 已提权但仍无管理员权限，操作取消。
    exit /b 1
)
echo.
echo [*] 需要管理员权限，正在请求提升...
set "EA=%~1"
set "EB=%~2"
set "EARGS=/elevated %EA%"
if defined EB set "EARGS=%EARGS% %EB%"
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -ArgumentList '/c \"\"%~f0\"\" !EARGS!' -Verb RunAs -ErrorAction Stop } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo [警告] 提权被拒绝或失败，操作已取消。
    exit /b 1
)
echo [*] 已在新窗口继续，请查看新打开的窗口。
exit /b 2


:: ============================================================
::  [1] 一键加速
:: ============================================================
:accel_core
call :require_admin "/accel"
if errorlevel 2 exit /b
if errorlevel 1 goto :accel_end

echo.
echo ================== 一键加速 ==================
call :update_hosts 0
set "UPOK=!errorlevel!"
echo.
if "!UPOK!"=="0" (
    echo [OK] hosts 已写入（或今日缓存已生效）。
) else (
    echo [WARN] hosts 写入未成功，下面按实际情况诊断。
)
echo.
echo [实际连通性]
call :selfcheck
echo.
call :net_check
if not "!NETMODE!"=="ok" call :auto_git_fix
call :advice

:accel_end
goto :menu_pause


:pickip_cli
call :pick_ip
echo BESTIP=!BESTIP!  BESTMS=!BESTMS!
exit /b 0


:gitfix_cli
cls
call :auto_git_fix
echo.
pause
exit /b


:: ============================================================
::  双击主流程：能开 -> 直接打开；打不开 -> 自动修复后再打开
::  参数: 1 = 完成后回到菜单（菜单 [7] 调用）
:: ============================================================

:: ============================================================
::  打开目标网址：优先用 Firefox（本网络只拦 Chromium 内核）
:: ============================================================
:open_target
set "FF="
if exist "C:\Program Files\Mozilla Firefox\firefox.exe" set "FF=C:\Program Files\Mozilla Firefox\firefox.exe"
if not defined FF if exist "C:\Program Files (x86)\Mozilla Firefox\firefox.exe" set "FF=C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
if defined FF (
    start "" "!FF!" "%TARGET_URL%"
) else (
    start "" "%TARGET_URL%"
)
exit /b 0

:open_github
set "RETMENU=1"
goto :quick_open

:quick_open
if not defined RETMENU set "RETMENU=%~1"
call :page_ok
if not errorlevel 1 goto :quick_open_do

:: 打不开：先用无需权限的方式找可用节点
cls
echo ==================== 自动修复 ====================
echo.
echo [X] GitHub 当前打不开，开始自动修复...
echo.
call :pick_ip
if not defined BESTIP goto :quick_no_node
echo [OK] 找到可用节点 !BESTIP!，需要管理员权限写入 hosts...
echo.
net session >nul 2>&1
if not errorlevel 1 goto :quick_repair
call :require_admin "/quickfix" "!BESTIP!"
exit /b 0

:quick_no_node
echo [X] 试了十多个 GitHub 节点，没有一个能在 6 秒内建立 TLS 连接。
echo.
echo 本网络对 GitHub 网页的限制已经很严，自动修复无能为力。
echo   - git clone / fetch / push 会自动切到镜像通道，可以正常用
echo   - 浏览器打开官网请开代理，或改用手机热点
call :auto_git_fix
call :proxy_hint
echo.
echo 仍然尝试打开浏览器（可能很慢或失败）...
call :open_target
call :write_log "自动修复失败（无可用节点），已尽力打开"
if "!RETMENU!"=="1" goto :menu_pause
exit /b 0

:quick_open_do
call :open_target
call :write_log "已打开 GitHub（!NETMODE!）"
if "!RETMENU!"=="1" (
    echo [OK] 已打开 GitHub。
    goto :menu_pause
)
exit /b 0


:: ============================================================
::  自动修复（管理员）：
::  刷新 hosts -> 实测节点挑最快 -> 写回 -> 复检 -> 打开
:: ============================================================
:quickfix_core
:quick_repair
echo [1/3] 刷新 hosts 加速列表...
call :update_hosts 0
if defined PRESET_IP (
    echo [2/3] 使用已探测到的节点 !PRESET_IP!
    set "BESTIP=!PRESET_IP!"
    call :apply_best_ip
) else (
    echo [2/3] 逐个实测 GitHub 节点（HEAD，只看连通性）...
    call :pick_ip
    if defined BESTIP (
        echo       选中 !BESTIP!（TLS 握手 !BESTMS!）
        call :apply_best_ip
    ) else (
        echo       没有节点能建立 TLS 连接
    )
)
echo [3/3] 复检页面...
call :page_ok
if not errorlevel 1 (
    echo       连接正常
    echo.
    echo [OK] 已修复，正在打开 GitHub...
    call :open_target
    call :write_log "自动修复成功（!BESTIP!），已打开 GitHub"
    %SystemRoot%\System32\timeout.exe /t 3 /nobreak >nul 2>&1
    if "!RETMENU!"=="1" goto :menu_pause
    exit /b 0
)

:: 仍然不稳：浏览器是最真实的测试，照样打开，同时如实说明
echo       连接仍不稳定
echo.
echo [注意] 已尽力修复：hosts 已换成实测能返回数据的节点。
echo        但本网络对 GitHub 限速严重，页面可能加载很慢或失败。
echo        如果浏览器打不开，请开代理或改用手机热点。
call :auto_git_fix
call :proxy_hint
echo.
echo 现在仍会尝试打开 GitHub...
call :open_target
call :write_log "自动修复后打开 GitHub（节点 !BESTIP!，页面仍不稳定）"
echo.
echo 按任意键打开完整菜单（直接关窗口即可退出）。
pause >nul
goto :menu


:: ============================================================
::  [2] 一键修复
:: ============================================================
:repair_core
call :require_admin "/repair"
if errorlevel 2 exit /b
if errorlevel 1 goto :menu_pause

echo.
echo ================= 一键修复开始 =================
echo.
echo [1/6] 备份当前 hosts...
if not exist "%HOSTS_ORIG%" copy /y "%HOSTS%" "%HOSTS_ORIG%" >nul 2>&1
call :backup_hosts_guarded
if errorlevel 1 (
    echo       失败: 无法备份 hosts，可能是权限或文件被占用。
    echo       请关掉杀毒软件/安全软件的 hosts 保护后重试。
    goto :repair_end
)
echo       完成。

echo.
echo [2/6] 清除今日缓存，强制重新下载...
del /q "%CACHE_FILE%" >nul 2>&1
del /q "%TIMESTAMP_FILE%" >nul 2>&1
del /q "%TMPFILE%" >nul 2>&1
echo       完成。

echo.
echo [3/6] 下载并写入 hosts（自动去重）...
call :update_hosts 1
set "UPOK=!errorlevel!"
if "!UPOK!"=="0" (
    echo       完成。
) else (
    echo       失败: 三个镜像都没拿到数据，或写入被拦截。
    goto :repair_end
)

echo.
echo [4/6] 校验结果...
call :verify_hosts

echo.
echo [5/6] 刷新 DNS 缓存...
ipconfig /flushdns >nul 2>&1
echo       完成。

echo.
echo [6/6] 连通性自检...
call :selfcheck
echo.
call :verdict

:repair_end
echo.
echo ================= 修复流程结束 =================
goto :menu_pause


:: ============================================================
::  [3] 网络诊断
:: ============================================================
:diag
cls
echo ==================== GitHub 网络诊断 ====================
echo.
echo [hosts 文件]
echo   路径: %HOSTS%
if exist "%HOSTS%" (echo   状态: 存在) else (echo   状态: 不存在)
set "BLOCKS=0"
for /f %%n in ('%SystemRoot%\System32\findstr.exe /c:"%MARKER_START%" "%HOSTS%" 2^>nul ^| %SystemRoot%\System32\find.exe /c /v ""') do set "BLOCKS=%%n"
echo   GitHub520 区块数: !BLOCKS!
if !BLOCKS! GTR 1 echo   [警告] 存在重复区块，建议执行 [2] 一键修复
if !BLOCKS! EQU 0 echo   [警告] 未配置加速条目，建议执行 [2] 一键修复

echo.
echo [缓存与任务]
if exist "%CACHE_FILE%" (echo   缓存文件: 存在) else (echo   缓存文件: 无)
set "CT="
if exist "%TIMESTAMP_FILE%" set /p "CT="<"%TIMESTAMP_FILE%"
if defined CT (echo   缓存日期: !CT!) else (echo   缓存日期: 无)
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (echo   计划任务: 未安装) else (echo   计划任务: 已安装)

echo.
echo [域名解析 - 当前生效的 hosts]
set "GIP=解析失败"
for /f "delims=" %%i in ('%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "try{( [System.Net.Dns]::GetHostAddresses('github.com') ).IPAddressToString -join ', '}catch{'解析失败'}"') do set "GIP=%%i"
echo   github.com 指向: !GIP!
set "RIP=解析失败"
for /f "delims=" %%i in ('%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "try{( [System.Net.Dns]::GetHostAddresses('raw.githubusercontent.com') ).IPAddressToString -join ', '}catch{'解析失败'}"') do set "RIP=%%i"
echo   raw.githubusercontent.com 指向: !RIP!

echo.
echo [端口连通性]
call :probe https://github.com
call :probe http://github.com
call :probe https://api.github.com
call :probe https://raw.githubusercontent.com
call :probe https://objects.githubusercontent.com
call :probe https://codeload.github.com

echo.
call :verdict
echo ============================================================
goto :menu_pause


:: ============================================================
::  连通性自检（简洁版）
:: ============================================================
:selfcheck
%SystemRoot%\System32\curl.exe -s -m 8 --connect-timeout 5 -o nul "https://api.github.com" 2>nul
if errorlevel 1 (echo   [X] api.github.com 不可达) else (echo   [OK] api.github.com 可达)
%SystemRoot%\System32\curl.exe -s -m 8 --connect-timeout 5 -o nul "%TARGET_URL%" 2>nul
if errorlevel 1 (echo   [X] github.com:443 不通) else (echo   [OK] github.com 可达)
exit /b


:: ============================================================
::  单个域名探测
:: ============================================================
:probe
set "U=%~1"
%SystemRoot%\System32\curl.exe -s -m 8 --connect-timeout 5 -o nul "%U%" 2>nul
if errorlevel 1 (
    echo   [X] %U%
) else (
    echo   [OK] %U%
)
exit /b


:: ============================================================
::  结论判定：hosts 问题 还是 网络被封
:: ============================================================
:verdict
call :net_check
call :advice
exit /b


:: ============================================================
::  网络模式判定：ok=443 可达  sni=80通443不通  down=都不通
:: ============================================================
:net_check
set "NETMODE=down"
%SystemRoot%\System32\curl.exe -s -m 6 --connect-timeout 4 -o nul "https://github.com" 2>nul
if not errorlevel 1 (
    set "NETMODE=ok"
    exit /b 0
)
%SystemRoot%\System32\curl.exe -s -m 5 --connect-timeout 4 -o nul "http://github.com" 2>nul
if not errorlevel 1 (
    set "NETMODE=sni"
    exit /b 1
)
exit /b 2


:: ============================================================
::  按网络模式给出如实的结论和建议
:: ============================================================
:advice
echo.
echo [判定]
if "!NETMODE!"=="ok" (
    echo   [OK] github.com:443 可达，hosts 加速已生效。
    exit /b
)
if "!NETMODE!"=="sni" (
    echo   [X] github.com 的 80 端口通、443 端口不通。
    echo       这是网络层对 GitHub 的 TLS/SNI 阻断，换 hosts IP 解决不了。
    echo.
    echo   可行的办法：
    git config --global --get-regexp "^url\..*\.insteadof" >nul 2>&1
    if not errorlevel 1 (
        echo     1^) git 操作：已配置镜像通道，clone / fetch / push 可直接用。
    ) else (
        echo     1^) git 操作：运行菜单 [1]，会自动建立镜像通道。
    )
    echo     2^) 浏览器网页：必须开代理 / VPN（Clash、V2Ray 等）。
    echo     3^) 或换到手机流量 / 热点，通常可直接打开。
    call :proxy_hint
    exit /b
)
echo   [X] github.com 完全不可达（80 / 443 都超时）。
echo       请先检查网络或校园网认证，再考虑代理。
call :proxy_hint
exit /b


:: ============================================================
::  自动修复：网页不通时，建立可用的 git 镜像通道
:: ============================================================
:auto_git_fix
echo.
echo [自动修复] 网页走不通，尝试建立 git 可用通道...
git --version >nul 2>&1
if errorlevel 1 (
    echo   [X] 未安装 git，跳过。
    exit /b 1
)
set "MIRROR="
call :test_mirror "https://ghfast.top/"
if not defined MIRROR call :test_mirror "https://gh-proxy.com/"
if not defined MIRROR call :test_mirror "https://ghproxy.net/"
if not defined MIRROR (
    echo   [X] 所有镜像都不可用，只能等网络恢复或使用代理。
    exit /b 1
)
git config --global "url.%MIRROR%https://github.com/.insteadOf" "https://github.com/"
call :setup_git_cred
echo   [OK] git clone / fetch / push 已自动改为走镜像。
echo        普通 https://github.com/... 地址无需改动。
exit /b 0


:setup_git_cred
gh --version >nul 2>&1
if errorlevel 1 (
    echo   [注意] 未安装 gh，push 时会提示输入账号和令牌。
    exit /b
)
gh auth status >nul 2>&1
if errorlevel 1 (
    echo   [注意] gh 未登录，push 时会提示输入账号和令牌。
    exit /b
)
set "MHOST=%MIRROR:~0,-1%"
git config --global --replace-all "credential.%MHOST%.helper" ""
setlocal disabledelayedexpansion
git config --global --add "credential.%MHOST%.helper" "!f() { echo username=oauth2; echo password=$(gh auth token); }; f"
endlocal
echo   [OK] 已用 gh 令牌配置镜像凭据（令牌不落盘）。
exit /b


:: ============================================================
::  实测候选节点：用 HEAD 请求看 TCP + TLS 能否建立
::  只看「连得上、握手快」，不下载正文（省时间，也不受限速影响）
::  结果: BESTIP   BESTSEC(握手秒数)
:: ============================================================
:pick_ip
set "BESTIP="
set "BESTMS=99999"
set "DONE="

set "CURIP="
if exist "%CACHE_FILE%" (
    for /f "tokens=1,2" %%a in ('%SystemRoot%\System32\findstr.exe /r /c:"^[0-9][0-9.]*  *github\.com$" "%CACHE_FILE%" 2^>nul') do set "CURIP=%%a"
)
if not defined CURIP set "CURIP=20.205.243.166"

set "IPLIST=!CURIP! 140.82.112.3 140.82.114.3 140.82.113.3 140.82.116.3 4.237.22.38 20.29.134.23 20.207.73.82 20.200.245.247 20.233.83.145 20.27.177.113 20.205.243.166"

for %%i in (!IPLIST!) do (
    if not defined DONE (
        for /f "tokens=1,2" %%a in ('%SystemRoot%\System32\curl.exe -sI -o NUL -w "%%{http_code} %%{time_appconnect}" --connect-timeout 3 --max-time 6 --resolve github.com:443:%%i "%TARGET_URL%/" 2^>nul') do (
            if not "%%a"=="000" (
                set "MS=%%b"
                set "MS=!MS:.=!"
                if !MS! LSS !BESTMS! (
                    set "BESTMS=!MS!"
                    set "BESTIP=%%i"
                    if !BESTMS! LSS 1500000 set "DONE=1"
                )
            )
        )
    )
)
if defined BESTIP exit /b 0
exit /b 1


:: 用当前 hosts 解析结果做一次 HEAD，确认现在真能连上
:page_ok
for /f "tokens=1" %%a in ('%SystemRoot%\System32\curl.exe -sI -o NUL -w "%%{http_code}" --connect-timeout 3 --max-time 6 "%TARGET_URL%/" 2^>nul') do (
    if not "%%a"=="000" exit /b 0
)
exit /b 1


:: 把缓存里的 github.com 记录替换成实测出来的节点，再写回 hosts
:apply_best_ip
if not defined BESTIP exit /b 1
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$f='%CACHE_FILE%';$ip='!BESTIP!';$t=[IO.File]::ReadAllText($f,[Text.Encoding]::UTF8);$t=[regex]::Replace($t,'(?im)^[0-9.]+(\s+)github\.com\s*$',$ip+'$1github.com');[IO.File]::WriteAllText($f,$t,(New-Object Text.UTF8Encoding($false)))" >nul 2>&1
call :apply_to_hosts
exit /b %errorlevel%


:: ============================================================
::  提示本机是否有常见代理端口在监听（只提示，不改配置）
:: ============================================================
:proxy_hint
set "PFOUND="
for %%p in (7890 7897 10809 10808 1080 8080 2080) do call :port_listening %%p
if defined PFOUND (
    echo   检测到本机代理端口:!PFOUND!
    echo   若代理已开，请在代理软件里把 GitHub 走代理规则即可。
) else (
    echo   本机未检测到常见代理端口，需要时必须先启动代理软件。
)
exit /b

:port_listening
netstat -ano 2>nul | findstr /r /c:":%~1 .*LISTENING" >nul 2>&1
if not errorlevel 1 set "PFOUND=!PFOUND! %~1"
exit /b


:: ============================================================
::  校验 hosts 写入结果
:: ============================================================
:verify_hosts
set "BLOCKS=0"
for /f %%n in ('%SystemRoot%\System32\findstr.exe /c:"%MARKER_START%" "%HOSTS%" 2^>nul ^| %SystemRoot%\System32\find.exe /c /v ""') do set "BLOCKS=%%n"
set "ENDS=0"
for /f %%n in ('%SystemRoot%\System32\findstr.exe /c:"%MARKER_END%" "%HOSTS%" 2^>nul ^| %SystemRoot%\System32\find.exe /c /v ""') do set "ENDS=%%n"
set "LINES=0"
for /f %%n in ('%SystemRoot%\System32\findstr.exe /r /c:"^[0-9][0-9.]* " "%HOSTS%" 2^>nul ^| %SystemRoot%\System32\find.exe /c /v ""') do set "LINES=%%n"
echo   起始标记数: !BLOCKS!   结束标记数: !ENDS!
echo   解析条目总数: !LINES!
if "!BLOCKS!"=="1" (
    if "!ENDS!"=="1" (
        if !LINES! GTR 5 (echo   [OK] 结构正常) else (echo   [警告] 条目过少，数据可能不完整)
    ) else (
        echo   [警告] 起止标记不配对，建议再次修复
    )
) else (
    echo   [警告] 区块数异常，可能被安全软件改写，请检查后重试
)
exit /b


:: ============================================================
::  [4] 镜像兜底
:: ============================================================
:mirror_core
cls
echo ================= 镜像兜底（git 走镜像） =================
echo.
git --version >nul 2>&1
if errorlevel 1 (
    echo [X] 未检测到 git，跳过。
    goto :menu_pause
)

set "CUR="
for /f "delims=" %%a in ('git config --global --get-regexp "url\..*\.(insteadof|pushinsteadof)" 2^>nul') do set "CUR=%%a"
if defined CUR (
    echo 当前已配置镜像:
    echo   !CUR!
    echo.
    echo   [1] 撤销镜像，恢复官方地址
    echo   [2] 重新检测并切换到可用镜像
    echo   [3] 返回
    set "CH="
    set /p "CH=请选择: "
    if "%CH%"=="1" goto :mirror_undo
    if "%CH%"=="2" goto :mirror_redo
    goto :menu
)

echo 正在测试镜像可用性（优先选支持 push 的）...
set "MIRROR="
call :test_mirror "https://ghfast.top/"
if defined MIRROR goto :mirror_apply
call :test_mirror "https://gh-proxy.com/"
if defined MIRROR goto :mirror_apply
call :test_mirror "https://ghproxy.net/"
if defined MIRROR goto :mirror_apply
echo.
echo [X] 所有镜像均不可用，请使用代理/VPN。
goto :menu_pause

:test_mirror
set "M=%~1"
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>&1
set "MTEST=%CACHE_DIR%\mirror_test.txt"
%SystemRoot%\System32\curl.exe -fsL -m 12 -o "%MTEST%" "%M%https://raw.githubusercontent.com/521xueweihan/GitHub520/main/hosts" 2>nul
if errorlevel 1 exit /b
%SystemRoot%\System32\findstr.exe /c:"%MARKER_START%" "%MTEST%" >nul 2>&1
if errorlevel 1 exit /b
set "MIRROR=%M%"
exit /b

:mirror_apply
echo.
echo 使用镜像: %MIRROR%
git config --global "url.%MIRROR%https://github.com/.insteadOf" "https://github.com/"
if errorlevel 1 (
    echo [X] 写入 git 配置失败。
    goto :menu_pause
)
git config --global --unset-all "url.https://github.com/.pushInsteadOf" >nul 2>&1
call :setup_git_cred
echo.
echo [OK] 已配置：clone / fetch / push 均走镜像。
echo      该配置只影响 git，不影响浏览器的 github.com。
echo      撤销：重新运行菜单 [4]，选择 1。
echo      安全提示：镜像会中转你的令牌，敏感仓库请谨慎使用。
goto :menu_pause

:mirror_redo
for /f "tokens=1" %%a in ('git config --global --get-regexp "url\..*\.(insteadof|pushinsteadof)" 2^>nul') do git config --global --unset-all "%%a"
goto :mirror_core

:mirror_undo
for /f "tokens=1" %%a in ('git config --global --get-regexp "url\..*\.(insteadof|pushinsteadof)" 2^>nul') do git config --global --unset-all "%%a"
for %%h in (https://ghfast.top https://gh-proxy.com https://ghproxy.net) do git config --global --unset-all "credential.%%h.helper" >nul 2>&1
echo.
echo [OK] 镜像配置与镜像凭据已撤销。
goto :menu_pause


:: ============================================================
::  [5] 计划任务
:: ============================================================
:task_core
cls
echo ====================== 计划任务 ======================
echo.
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 goto :task_missing
if not exist "%LAUNCHER%" goto :task_broken
goto :task_installed

:task_missing
echo 状态: 未安装
echo   安装后每次登录延迟 30 秒静默更新 hosts。
echo.
echo   [1] 安装
echo   [2] 返回
set "CH="
set /p "CH=请选择: "
if "%CH%"=="1" goto :task_install
goto :menu

:task_broken
echo 状态: 已安装，但启动器 gh520_launcher.vbs 丢失，开机自动更新已失效。
echo   上次运行结果应为失败，hosts 不会自动刷新。
echo.
echo   [1] 修复安装（重建启动器与任务）
echo   [2] 卸载
echo   [3] 返回
set "CH="
set /p "CH=请选择: "
if "%CH%"=="1" goto :task_install
if "%CH%"=="2" goto :task_uninstall
goto :menu

:task_installed
echo 状态: 已安装，运行正常
echo   任务名: %TASK_NAME%
echo.
echo   [1] 立即运行一次
echo   [2] 卸载
echo   [3] 返回
set "CH="
set /p "CH=请选择: "
if "%CH%"=="1" goto :task_run
if "%CH%"=="2" goto :task_uninstall
goto :menu

:task_run
schtasks /run /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (echo [X] 运行失败) else (echo [OK] 已触发一次静默更新)
goto :menu_pause

:task_install
call :require_admin "/task"
if errorlevel 2 exit /b
if errorlevel 1 goto :menu_pause

(
    echo Set WshShell = CreateObject^("WScript.Shell"^)
    echo WshShell.Run "cmd.exe /c """"%~f0"""" /startup", 0, False
) > "%LAUNCHER%"
if not exist "%LAUNCHER%" (
    echo [X] 无法写入启动器 %LAUNCHER%
    goto :menu_pause
)

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /create /tn "%TASK_NAME%" /tr "wscript.exe //B \"%LAUNCHER%\"" /sc onlogon /delay 0000:30 /rl highest /f >nul 2>&1
if errorlevel 1 (
    echo [X] 创建计划任务失败。
) else (
    echo [OK] 已安装，登录后 30 秒静默更新 hosts。
)
goto :menu_pause

:task_uninstall
call :require_admin "/task"
if errorlevel 2 exit /b
if errorlevel 1 goto :menu_pause
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
if exist "%LAUNCHER%" del /q "%LAUNCHER%" >nul 2>&1
echo [OK] 计划任务已卸载。
goto :menu_pause


:: ============================================================
::  [6] 恢复与清理
:: ============================================================
:restore_core
cls
echo ==================== 恢复与清理 ====================
echo.
echo   [1] 回滚到最近一次加速前的 hosts（hosts.bak）
echo   [2] 回滚到最初的 hosts（hosts.gh520.orig）
echo   [3] 仅移除 hosts 里的 GitHub520 区块
echo   [4] 彻底卸载（任务 + 启动器 + 缓存 + 区块）
echo   [5] 返回
echo.
set "CH="
set /p "CH=请选择: "
if "%CH%"=="1" goto :restore_bak
if "%CH%"=="2" goto :restore_orig
if "%CH%"=="3" goto :strip_only
if "%CH%"=="4" goto :full_uninstall
goto :menu

:restore_bak
call :require_admin "/restore"
if errorlevel 2 exit /b
if errorlevel 1 goto :menu_pause
if not exist "%HOSTS_BAK%" (
    echo [X] 没有找到备份 %HOSTS_BAK%
    goto :menu_pause
)
attrib -r "%HOSTS%" >nul 2>&1
copy /y "%HOSTS_BAK%" "%HOSTS%" >nul 2>&1
if errorlevel 1 (echo [X] 回滚失败，文件可能被占用) else (echo [OK] 已回滚到最近备份)
ipconfig /flushdns >nul 2>&1
goto :menu_pause

:restore_orig
call :require_admin "/restore"
if errorlevel 2 exit /b
if errorlevel 1 goto :menu_pause
if not exist "%HOSTS_ORIG%" (
    echo [X] 没有找到最初备份 %HOSTS_ORIG%
    goto :menu_pause
)
attrib -r "%HOSTS%" >nul 2>&1
copy /y "%HOSTS_ORIG%" "%HOSTS%" >nul 2>&1
if errorlevel 1 (echo [X] 回滚失败，文件可能被占用) else (echo [OK] 已恢复为最初的 hosts)
ipconfig /flushdns >nul 2>&1
goto :menu_pause

:strip_only
call :require_admin "/restore"
if errorlevel 2 exit /b
if errorlevel 1 goto :menu_pause
attrib -r "%HOSTS%" >nul 2>&1
call :backup_hosts_guarded
call :strip_blocks
if errorlevel 1 (echo [X] 清理失败) else (echo [OK] 已移除 GitHub520 区块)
ipconfig /flushdns >nul 2>&1
goto :menu_pause

:full_uninstall
call :require_admin "/restore"
if errorlevel 2 exit /b
if errorlevel 1 goto :menu_pause
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
if exist "%LAUNCHER%" del /q "%LAUNCHER%" >nul 2>&1
attrib -r "%HOSTS%" >nul 2>&1
call :backup_hosts_guarded
call :strip_blocks
if errorlevel 1 (
    echo [警告] hosts 区块清理失败，请手动检查 %HOSTS%
) else (
    echo [OK] hosts 区块已清除
)
if exist "%CACHE_DIR%" (
    del /q "%CACHE_DIR%\*" >nul 2>&1
    rmdir "%CACHE_DIR%" >nul 2>&1
)
ipconfig /flushdns >nul 2>&1
for /f "tokens=1" %%a in ('git config --global --get-regexp "url\..*\.(insteadof|pushinsteadof)" 2^>nul') do git config --global --unset-all "%%a"
for %%h in (https://ghfast.top https://gh-proxy.com https://ghproxy.net) do git config --global --unset-all "credential.%%h.helper" >nul 2>&1
echo [OK] 已彻底卸载：任务、启动器、缓存、hosts 区块、git 镜像配置均已清除。
goto :menu_pause


:: ============================================================
::  开机静默更新
:: ============================================================
:startup
call :update_hosts 0
call :startup_netmode
exit /b


:: ============================================================
::  登录时按网络环境自动切换 git 通道
::  直连可用 -> 撤销镜像；直连不可用 -> 确保镜像
:: ============================================================
:startup_netmode
call :net_check_stable
if "!NETMODE!"=="ok" (
    call :mirror_off_quiet
    call :write_log "直连可用，git 已切回官方地址"
    exit /b 0
)
call :auto_git_fix
if errorlevel 1 (
    call :write_log "GitHub 直连不可用（!NETMODE!），镜像配置失败或缺少 git"
) else (
    call :write_log "GitHub 直连不可用（!NETMODE!），已确保 git 镜像通道"
)
exit /b 0


:: 连续两次都成功才算真正可用，避免网络抖动来回切换
:net_check_stable
call :net_check
if not "!NETMODE!"=="ok" exit /b 1
call :net_check
if not "!NETMODE!"=="ok" exit /b 1
exit /b 0


:mirror_off_quiet
for /f "tokens=1" %%a in ('git config --global --get-regexp "url\..*\.(insteadof|pushinsteadof)" 2^>nul') do git config --global --unset-all "%%a"
for %%h in (https://ghfast.top https://gh-proxy.com https://ghproxy.net) do git config --global --unset-all "credential.%%h.helper" >nul 2>&1
exit /b 0


:write_log
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>&1
for %%s in ("%~dp0gh520_startup.log") do if %%~zs GTR 102400 del /q "%%~s" >nul 2>&1
for /f %%t in ('%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%t"
echo [!NOW!] %~1 >>"%~dp0gh520_startup.log"
exit /b 0


:: ============================================================
::  更新 hosts 主流程   参数: 1=强制刷新  0=按缓存
:: ============================================================
:update_hosts
setlocal
set "FORCE=%~1"
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>&1

if "%FORCE%"=="1" goto :uh_network

:: 缓存当天有效，且 hosts 里确实还有加速条目
if exist "%TIMESTAMP_FILE%" (
    for /f %%a in ('%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd"') do set "TODAY=%%a"
    set "CACHE_DATE="
    set /p "CACHE_DATE="<"%TIMESTAMP_FILE%"
    if "!CACHE_DATE!"=="!TODAY!" (
        set "LINES=0"
        for /f %%n in ('%SystemRoot%\System32\findstr.exe /r /c:"^[0-9][0-9.]* " "%HOSTS%" 2^>nul ^| %SystemRoot%\System32\find.exe /c /v ""') do set "LINES=%%n"
        if !LINES! GTR 5 (
            ipconfig /flushdns >nul 2>&1
            exit /b 0
        )
        call :apply_to_hosts
        exit /b
    )
)

:uh_network
:: 探测加速源（不要探测被墙的 raw.githubusercontent.com）
%SystemRoot%\System32\ping.exe -n 1 -w 2000 raw.hellogithub.com >nul 2>&1
if errorlevel 1 (
    %SystemRoot%\System32\ping.exe -n 1 -w 2000 github.com >nul 2>&1
    if errorlevel 1 (
        if exist "%CACHE_FILE%" call :apply_to_hosts
        exit /b 1
    )
)

call :try_download
if errorlevel 1 (
    if exist "%CACHE_FILE%" call :apply_to_hosts
    exit /b 1
)

:: 校验下载内容（起止标记都必须存在）
%SystemRoot%\System32\findstr.exe /c:"%MARKER_START%" "%TMPFILE%" >nul 2>&1
if errorlevel 1 goto :uh_badfile
%SystemRoot%\System32\findstr.exe /c:"%MARKER_END%" "%TMPFILE%" >nul 2>&1
if errorlevel 1 goto :uh_badfile
goto :uh_apply

:uh_badfile
del "%TMPFILE%" >nul 2>&1
if exist "%CACHE_FILE%" call :apply_to_hosts
exit /b 1

:uh_apply

copy /y "%TMPFILE%" "%CACHE_FILE%" >nul 2>&1

call :apply_to_hosts
if errorlevel 1 (
    del "%TMPFILE%" >nul 2>&1
    exit /b 1
)

:: 只有真正写进 hosts 才算今天已更新
for /f %%a in ('%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd"') do <nul set /p "=%%a" > "%TIMESTAMP_FILE%"
del "%TMPFILE%" >nul 2>&1
exit /b 0


:: ============================================================
::  下载：3 个镜像 × 每个 2 次重试
:: ============================================================
:try_download
set "URL1=https://raw.hellogithub.com/hosts"
set "URL2=https://cdn.jsdelivr.net/gh/521xueweihan/GitHub520@main/hosts"
set "URL3=https://ghproxy.net/https://raw.githubusercontent.com/521xueweihan/GitHub520/main/hosts"

for %%U in ("%URL1%" "%URL2%" "%URL3%") do (
    for /l %%r in (1,1,2) do (
        %SystemRoot%\System32\curl.exe -fsL --connect-timeout 8 --max-time 15 -o "%TMPFILE%" %%~U 2>nul
        if not errorlevel 1 (
            for %%A in ("%TMPFILE%") do if %%~zA geq 100 exit /b 0
        )
        if %%r lss 2 %SystemRoot%\System32\timeout.exe /t 2 /nobreak >nul 2>&1
    )
)
exit /b 1


:: ============================================================
::  写入 hosts：去掉所有旧区块 -> 追加新内容
:: ============================================================
:backup_hosts_guarded
findstr /c:"%MARKER_START%" "%HOSTS%" >nul 2>&1
if errorlevel 1 (
    rem 当前 hosts 没有加速块，不是既有良好状态，保留旧备份不覆盖
    if not exist "%HOSTS_BAK%" copy /y "%HOSTS%" "%HOSTS_BAK%" >nul 2>&1
    exit /b 0
)
copy /y "%HOSTS%" "%HOSTS_BAK%" >nul 2>&1
exit /b %errorlevel%


:apply_to_hosts
if not exist "%CACHE_FILE%" exit /b 1

attrib -r "%HOSTS%" >nul 2>&1
call :backup_hosts_guarded

%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$h='%HOSTS%';$c='%CACHE_FILE%';$by=[IO.File]::ReadAllBytes($h);if($by.Length -ge 3 -and $by[0] -eq 239 -and $by[1] -eq 187 -and $by[2] -eq 191){$enc=New-Object System.Text.UTF8Encoding($false);$txt=$enc.GetString($by,3,$by.Length-3)}else{try{$st=New-Object System.Text.UTF8Encoding($false,$true);$txt=$st.GetString($by);$enc=New-Object System.Text.UTF8Encoding($false)}catch{$enc=[System.Text.Encoding]::GetEncoding(936);$txt=$enc.GetString($by)}};$o=New-Object System.Collections.ArrayList;$s=$false;foreach($l in ($txt -split '\r?\n')){if($l -match 'GitHub520 Host Start'){$s=$true;continue};if($l -match 'GitHub520 Host End'){$s=$false;continue};if(-not $s){[void]$o.Add($l)}};while($o.Count -gt 0 -and $o[$o.Count-1].Trim() -eq ''){$o.RemoveAt($o.Count-1)};$o.Add('');[void]$o.AddRange([string[]](Get-Content -LiteralPath $c -Encoding UTF8));[IO.File]::WriteAllLines($h,$o,$enc)" >nul 2>&1

if errorlevel 1 (
    copy /y "%HOSTS_BAK%" "%HOSTS%" >nul 2>&1
    exit /b 1
)

%SystemRoot%\System32\findstr.exe /c:"%MARKER_START%" "%HOSTS%" >nul 2>&1
if errorlevel 1 (
    copy /y "%HOSTS_BAK%" "%HOSTS%" >nul 2>&1
    exit /b 1
)

ipconfig /flushdns >nul 2>&1
exit /b 0


:: ============================================================
::  只移除区块，不追加
:: ============================================================
:strip_blocks
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$h='%HOSTS%';$by=[IO.File]::ReadAllBytes($h);if($by.Length -ge 3 -and $by[0] -eq 239 -and $by[1] -eq 187 -and $by[2] -eq 191){$enc=New-Object System.Text.UTF8Encoding($false);$txt=$enc.GetString($by,3,$by.Length-3)}else{try{$st=New-Object System.Text.UTF8Encoding($false,$true);$txt=$st.GetString($by);$enc=New-Object System.Text.UTF8Encoding($false)}catch{$enc=[System.Text.Encoding]::GetEncoding(936);$txt=$enc.GetString($by)}};$o=New-Object System.Collections.ArrayList;$s=$false;foreach($l in ($txt -split '\r?\n')){if($l -match 'GitHub520 Host Start'){$s=$true;continue};if($l -match 'GitHub520 Host End'){$s=$false;continue};if(-not $s){[void]$o.Add($l)}};while($o.Count -gt 0 -and $o[$o.Count-1].Trim() -eq ''){$o.RemoveAt($o.Count-1)};$o.Add('');[IO.File]::WriteAllLines($h,$o,$enc)" >nul 2>&1
exit /b %errorlevel%


:: ============================================================
::  收尾
:: ============================================================
:menu_pause
echo.
pause
goto :menu
