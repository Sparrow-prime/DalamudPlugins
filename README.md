# DalamudPlugins — Sparrow-prime 的 FF14 插件第三方仓库

面向**国服 XIVLauncherCN（Dalamud API 15）**的第三方插件库，收录我自己的两个 Dalamud 插件。

- 仓库清单：`pluginmaster.json`
- 插件包：`plugins/<内部名>/<版本>/<内部名>.zip`

## 安装

游戏内：

1. 输入 `/xlsettings` → 切到 **实验性（Experimental）** 页；
2. 找到「**第三方插件库**（Third party plugin repositories）」，点右侧 `+`，填入：

   ```
   https://raw.githubusercontent.com/Sparrow-prime/DalamudPlugins/main/pluginmaster.json
   ```

3. 保存后打开 `/xlplugins` → 在「全部插件」里搜索 **AutoBuyer** 或 **FFXIV-CrystalTransfer** → 安装。

> 仓库必须保持**公开**，私有仓库 Dalamud 拉不到清单。

## 收录的插件

| 插件 | 内部名 | 当前版本 | 说明 | 源码 |
| ---- | ---- | ---- | ---- | ---- |
| AutoBuyer | `AutoBuyer` | 1.1.6 | 市场布告板增强：跨服比价、在售列表、按目标数量一键购买 | [FFXIV-AutoBuyer](https://github.com/Sparrow-prime/FFXIV-AutoBuyer) |
| FFXIV-CrystalTransfer | `FFXIV-CrystalTransfer` | 1.0.1 | 把背包中的水晶自动存入雇员背包 | [FFXIV-CrystalTransfer](https://github.com/Sparrow-prime/FFXIV-CrystalTransfer) |

## 关于「小树枝信使 FeoMessenger」

`FFXIV-LNPCMSR` 是**安卓 App**（电脑端鲶鱼精邮差把游戏聊天转发到手机），不是 Dalamud 插件，
**不能**放进本仓库、也装不进 Dalamud。它的发布走自己的仓库：
<https://github.com/Sparrow-prime/FFXIV-LNPCMSR/releases>。

## 发版流程（作者）

```powershell
# 构建 + 打包进仓库 + 更新 pluginmaster.json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Publish-Plugin.ps1 -Plugin AutoBuyer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Publish-Plugin.ps1 -Plugin FFXIV-CrystalTransfer

git add -A
git commit -m "publish: AutoBuyer 1.1.7"
git push
```

脚本做的事：

1. `dotnet build <工程>.csproj -c Release`（加 `-SkipBuild` 只用已有产物）；
2. 读插件清单 `<内部名>.json`，校验 zip 根目录里有 `<内部名>.dll` 和 `<内部名>.json`；
3. 把 `latest.zip` 拷到 `plugins/<内部名>/<版本>/<内部名>.zip`；
4. 用最新版本号、下载链接、`LastUpdate` 覆盖 `pluginmaster.json` 里的对应条目（保留 `DownloadCount`）。

**为什么按版本建目录**：Dalamud 按 `AssemblyVersion` 判断要不要更新，
同名 zip 覆盖上传时 CDN 可能还返回旧包；每次发版换新路径就没这个问题。

## 排错

| 现象 | 原因 / 处理 |
| ---- | ---- |
| 游戏里加仓库后提示「无法获取插件列表」 | 地址不通。先用浏览器打开清单地址确认能下载；国内网络可改用 jsDelivr 镜像（见下） |
| 插件列表里出现但显示「不兼容」 | `DalamudApiLevel` 不是 15，或 `AssemblyVersion` 与实际包不一致 |
| 安装时报「Distributed internal name does not match」/ 版本不匹配 | zip 里的 `<内部名>.json` 与 `pluginmaster.json` 里的 `InternalName`、`AssemblyVersion` 不一致；用发布脚本生成，别手改 |
| 装了但没更新 | `AssemblyVersion` 没变。`1.1.6.0` 与 `1.1.6` 在 Dalamud 眼里不是同一个版本号，别漏掉第四位 |

### 镜像（GitHub 直连不稳时）

把 `https://raw.githubusercontent.com/Sparrow-prime/DalamudPlugins/main/` 换成
`https://cdn.jsdelivr.net/gh/Sparrow-prime/DalamudPlugins@main/`，两条路径同样可用（清单和 zip 都能走）。
jsDelivr 缓存较久，发版后短时间内可能还拿到旧的 `pluginmaster.json`。
