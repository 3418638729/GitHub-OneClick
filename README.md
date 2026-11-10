# GitHub-OneClick

双击一个 bat，直接打开 GitHub。打不开就自动诊断、自动修，修不好会如实告诉你是谁在挡路。

> 这是 **Windows 专用**的小工具，只做两件事：加速/修复 `hosts`，以及一键打开 github.com。
> 不代理、不镜像、不改你的浏览器，也不上传任何数据。

---

## 一、快速开始（新电脑照做即可）

### 第 1 步：下载

**方式 A（推荐）**：在本页右上角点 **Code → Download ZIP**，解压。

**方式 B**：如果网页打不开，用命令行下载：

```bat
curl -L -o GitHub.bat https://raw.githubusercontent.com/<你的用户名>/GitHub-OneClick/main/GitHub.bat
```

> 下载到的必须是 **`GitHub.bat` 这一个文件**，别的都不需要。

### 第 2 步：放到一个你能找到的文件夹

例如 `D:\Tools\GitHub-OneClick\`。

⚠️ **不要**放在 `C:\Program Files\`、`C:\Windows\` 这类需要管理员权限才能写的目录，
否则脚本改不了 `hosts`，会一直失败。

### 第 3 步：双击 `GitHub.bat`

就这一步。你会看到两种情况其中之一：

| 你的网络 | 你会看到 | 你要做什么 |
|---|---|---|
| 能正常访问 GitHub（家里宽带、手机热点） | 黑窗口闪一下，浏览器弹出 GitHub | 什么都不用做 |
| 访问受限（部分校园网 / 公司网） | 窗口里显示诊断和修复过程 | 看完提示，按任意键 |

第一次在受限网络下运行，可能会弹一次 **用户账户控制（UAC）**，因为改 `hosts` 需要管理员权限。
点「是」就行，工具只改 `hosts` 里 GitHub 相关的那一段。

---

## 二、这个工具到底做了什么

1. **测连通性**：用 HTTP HEAD 请求判断 `github.com` 现在能不能连上（只看 TCP + TLS 能不能建立，不下载整页，所以很快）。
2. **能连就直接开**：`start https://github.com`，结束。
3. **连不上就诊断 + 修复**：
   - 从 [GitHub520](https://github.com/521xueweihan/GitHub520) 拉取最新的 GitHub IP 列表；
   - 逐个实测候选 IP，挑出**当前真的能建立 TLS 连接**的那个，写进 `hosts`；
   - 同时把 git 的 `clone / fetch / push` 切到可用镜像通道（可选，见下）；
   - 再复检一次，能连就打开浏览器。
4. **修不好就说实话**：如果所有节点都连不上，它不会假装成功，会明确告诉你「本网络限制了 GitHub，需要代理或换网络」。

### 改了系统的哪些地方？

只改这三处，全部可恢复：

| 位置 | 作用 | 如何恢复 |
|---|---|---|
| `C:\Windows\System32\drivers\etc\hosts` 里的一段（以 `# GitHub520 Host Start` 开始） | GitHub 域名指向可用 IP | 菜单 `[6] 恢复清理` 一键移除 |
| `%TEMP%\gh520\` 目录 | 缓存 IP 列表，避免每次重新下载 | 菜单 `[6] 彻底卸载` |
| git 全局配置里的 `url.*.insteadOf` | `git clone` 走镜像通道 | 菜单 `[6] 彻底卸载` |

---

## 三、菜单里的其他功能

双击默认是「打开 GitHub」。想要完整菜单，用命令行：

```bat
GitHub.bat /menu
```

| 菜单项 | 作用 |
|---|---|
| [1] 一键修复可用 | 写 `hosts`；网页不通时自动建立 git 通道 |
| [2] 一键修复 | 强制刷新 / 去重 / 回滚 / 自检 |
| [3] 网络诊断 | 区分「hosts 失效」和「443 被限制」 |
| [4] 镜像兜底 | git 走镜像下载（可撤销） |
| [5] 计划任务 | 登录后 30 秒静默更新 `hosts` |
| [6] 恢复清理 | 回滚 `hosts` 备份 / 彻底卸载 |
| [7] 打开 GitHub | 和双击一样，能通就开，不通自动修复后再试 |

### 隐藏参数（给脚本或计划任务用）

```bat
GitHub.bat /startup     登录时静默运行（不改浏览器，只保证 git 通道正确）
GitHub.bat /accel       一键加速
GitHub.bat /repair      一键修复
GitHub.bat /diag        网络诊断
GitHub.bat /pickip      只探测节点并打印结果（排查用）
GitHub.bat /gitfix      只建立 git 镜像通道
GitHub.bat /open        打开 GitHub（同双击）
GitHub.bat /menu        打开菜单
GitHub.bat /install     安装登录计划任务
GitHub.bat /uninstall   彻底卸载
```

---

## 四、常见问题

### Q1. 双击后窗口一闪就没，GitHub 也没打开？

说明它判断「能连」并直接打开了浏览器。如果你的浏览器还是打不开，看 Q2。

### Q2. 工具说能连，但浏览器还是打不开？

这是真实存在的情况，不是 bug。常见原因是网络对**浏览器**做了限制：

- `curl`、`git` 能连上 `github.com`，但 Chrome / Edge 连不上；
- 这类网络通常按 TLS 指纹拦截 Chromium 内核，改 `hosts` 解决不了。

判断方法：在命令行执行 `curl -I https://github.com`，
如果返回 `HTTP/1.1 200` 而浏览器仍然打不开，就是这种情况。

解决办法（按省事程度排序）：

1. **开手机热点**再双击，通常立刻可用；
2. 用代理 / VPN，让浏览器走代理；
3. 换一个非 Chromium 内核的浏览器（如 Firefox）试试。

### Q3. 一直提示需要管理员权限 / 改不了 hosts？

- 检查安全软件是否锁定了 `hosts`（360、火绒等都有「hosts 保护」，先关掉）；
- 确认 bat 没有放在 `C:\Program Files` 这类受保护目录。

### Q4. 想要完全恢复到用之前的状态？

```bat
GitHub.bat /menu
```
然后选 `[6] 恢复清理 → 彻底卸载`：移除 `hosts` 区块、计划任务、缓存，以及 git 的镜像配置。

### Q5. 日志在哪？

就在 bat 同目录的 `gh520_startup.log`，每次登录静默运行会写一行。
文件超过 100KB 自动清空。

---

## 五、文件说明

| 文件 | 来源 | 说明 |
|---|---|---|
| `GitHub.bat` | 本仓库提供 | 唯一必需文件，双击即用 |
| `README.md` | 本仓库提供 | 就是本文件 |
| `.gitattributes` | 本仓库提供 | 保证 `.bat` 下载后还是 CRLF 换行，否则 cmd 会报语法错误 |
| `gh520_launcher.vbs` | **自动生成** | 菜单 [5] 安装计划任务时生成到 bat 同目录，用于登录时隐藏窗口运行 |
| `gh520_startup.log` | **自动生成** | 登录静默运行的日志，每行一次 |
| `hosts.bak` / `hosts.gh520.orig` | **自动生成** | `hosts` 的备份，位于 `C:\Windows\System32\drivers\etc\` 下 |

---

## 六、已知限制

- **只支持 Windows**（依赖 `cmd`、PowerShell、`curl.exe`，Windows 10 1803 以后都自带）。
- **hosts 只能解决「域名解析到哪个 IP」**，解决不了网络层限速或 TLS 指纹拦截。
- **不提供代理**。需要代理时，请自行准备，工具只会提示你检测到的代理端口。
- 节点可用性**随时变化**：同一分钟里不同 IP 的连通性就可能不同，工具每次运行都会重新实测。

---

## 七、致谢

IP 数据来自 [521xueweihan/GitHub520](https://github.com/521xueweihan/GitHub520)。
本工具只做自动化，不存储、不转发任何账号信息。
