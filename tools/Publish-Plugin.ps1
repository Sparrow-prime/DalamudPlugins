<#
.SYNOPSIS
    把一个插件的构建产物收进本仓库，并更新 pluginmaster.json。

.DESCRIPTION
    流程：构建（可跳过）→ 读取插件清单 → 把 latest.zip 拷到 plugins/<内部名>/<版本>/ →
    更新 pluginmaster.json 里对应条目（版本号、下载链接、LastUpdate）。

.PARAMETER Plugin
    插件内部名（即程序集名），见 plugins/ 下的目录名。

.PARAMETER SkipBuild
    只用已有的构建产物，不重新编译。

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\Code\Work\DalamudPlugins\tools\Publish-Plugin.ps1 -Plugin AutoBuyer
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('AutoBuyer', 'FFXIV-CrystalTransfer')]
    [string]$Plugin,

    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 仓库下载链接前缀：改成推送后的真实地址（仓库名或默认分支变了就改这里）。
# ---------------------------------------------------------------------------
$RepoBaseUrl = 'https://raw.githubusercontent.com/Sparrow-prime/DalamudPlugins/main'

$Root       = Split-Path -Parent $PSScriptRoot
$MasterPath = Join-Path $Root 'pluginmaster.json'

# 每个插件的源码位置与构建输出位置（与各项目 README 里的构建命令一致）
$ProjectMap = @{
    'AutoBuyer' = @{
        Csproj = 'E:\Code\Work\FFXIV-AutoBuyer\FFXIV-AutoBuyer\FFXIV-AutoBuyer.csproj'
        Output = 'E:\Code\Output\FFXIV-AutoBuyer'
    }
    'FFXIV-CrystalTransfer' = @{
        Csproj = 'E:\Code\Work\FFXIV-CrystalTransfer\FFXIV-CrystalTransfer.csproj'
        Output = 'E:\Code\Output\FFXIV-CrystalTransfer'
    }
}

$project = $ProjectMap[$Plugin]

# 1. 构建 -------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "[1/4] 构建 $Plugin ..." -ForegroundColor Cyan
    & dotnet build $project.Csproj -c Release
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build 失败（exit $LASTEXITCODE），中止发布。"
    }
}
else {
    Write-Host "[1/4] 跳过构建（-SkipBuild）" -ForegroundColor DarkGray
}

# 2. 读插件清单 -------------------------------------------------------------
$manifestPath = Join-Path $project.Output "$Plugin.json"
if (-not (Test-Path $manifestPath)) {
    throw "找不到插件清单：$manifestPath"
}

$manifest = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$internalName = $manifest.InternalName
$version      = [string]$manifest.AssemblyVersion
$shortVersion = ($version.Split('.')[0..2]) -join '.'

if ($internalName -ne $Plugin) {
    throw "清单内部名 $internalName 与参数 $Plugin 不一致。"
}
if ([int]$manifest.DalamudApiLevel -ne 15) {
    Write-Warning "清单里 DalamudApiLevel = $($manifest.DalamudApiLevel)，不是国服 API 15。"
}

# 3. 拷 zip 进仓库 ----------------------------------------------------------
$zipSource = Join-Path $project.Output "$Plugin\latest.zip"
if (-not (Test-Path $zipSource)) {
    throw "找不到构建产物：$zipSource"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipSource)
try {
    $dllName = "$internalName.dll"
    $hasDll  = @($archive.Entries | Where-Object { $_.FullName -eq $dllName }).Count -gt 0
    $hasJson = @($archive.Entries | Where-Object { $_.FullName -eq "$internalName.json" }).Count -gt 0
}
finally {
    $archive.Dispose()
}

if (-not $hasDll -or -not $hasJson) {
    throw "zip 根目录缺少 $internalName.dll / $internalName.json，Dalamud 无法安装。"
}

$zipDir = Join-Path $Root "plugins\$internalName\$shortVersion"
New-Item -ItemType Directory -Force -Path $zipDir | Out-Null
$zipName = "$internalName.zip"
$zipDest = Join-Path $zipDir $zipName
Copy-Item $zipSource $zipDest -Force
Write-Host "[2/4] 已放入 plugins\$internalName\$shortVersion\$zipName" -ForegroundColor Cyan

# 4. 更新 pluginmaster.json -------------------------------------------------
Write-Host "[3/4] 更新 pluginmaster.json ..." -ForegroundColor Cyan

$master = @()
if (Test-Path $MasterPath) {
    $raw = [System.IO.File]::ReadAllText($MasterPath, [System.Text.Encoding]::UTF8)
    if ($raw.Trim().Length -gt 0) {
        # 注意：PowerShell 5.1 的 ConvertFrom-Json 不会把数组拆进管道，
        # 直接用 @(... | ConvertFrom-Json) 会得到「装着数组的数组」，故先赋值再规整。
        $parsed = $raw | ConvertFrom-Json
        if ($null -eq $parsed) {
            $master = @()
        }
        elseif ($parsed -is [array]) {
            $master = $parsed
        }
        else {
            $master = @($parsed)
        }
    }
}

$existing = $master | Where-Object { $_.InternalName -eq $internalName } | Select-Object -First 1

$downloadUrl = "$RepoBaseUrl/plugins/$internalName/$shortVersion/$zipName"

$downloadCount = 0
if ($null -ne $existing) {
    $downloadCount = [int64]$existing.DownloadCount
}

$entry = [ordered]@{
    Author              = [string]$manifest.Author
    Name                = [string]$manifest.Name
    Punchline           = [string]$manifest.Punchline
    Description         = [string]$manifest.Description
    InternalName        = $internalName
    AssemblyVersion     = $version
    ApplicableVersion   = [string]$manifest.ApplicableVersion
    RepoUrl             = [string]$manifest.RepoUrl
    Tags                = @($manifest.Tags)
    DalamudApiLevel     = [int]$manifest.DalamudApiLevel
    DownloadLinkInstall = $downloadUrl
    DownloadLinkUpdate  = $downloadUrl
    DownloadLinkTesting = $downloadUrl
    LastUpdate          = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    DownloadCount       = $downloadCount
    IsHide              = $false
    IsTestingExclusive  = $false
    LoadRequiredState   = 0
    LoadSync            = $false
    CanUnloadAsync      = $false
    LoadPriority        = 0
    AcceptsFeedback     = $true
}

$newMaster = @()
$replaced  = $false
foreach ($item in $master) {
    if ($item.InternalName -eq $internalName) {
        $newMaster += [pscustomobject]$entry
        $replaced  = $true
    }
    else {
        $newMaster += $item
    }
}
if (-not $replaced) {
    $newMaster += [pscustomobject]$entry
}

$newMaster = @($newMaster | Sort-Object -Property Name)

$json = ConvertTo-Json -InputObject $newMaster -Depth 10
# PowerShell 5.1 的 ConvertTo-Json 会在冒号后多输出一个空格，顺手整理成常规格式
$json = $json -replace '":\s{2,}', '": '
[System.IO.File]::WriteAllText($MasterPath, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))

# 回读校验，避免写出坏 JSON
$checkRaw = [System.IO.File]::ReadAllText($MasterPath, [System.Text.Encoding]::UTF8)
$check = $checkRaw | ConvertFrom-Json
if (@($check | Where-Object { $_.InternalName -eq $internalName }).Count -ne 1) {
    throw "pluginmaster.json 回读校验失败。"
}

Write-Host "[4/4] 完成：$($manifest.Name) $version" -ForegroundColor Green
Write-Host ""
Write-Host "下载链接：$downloadUrl"
Write-Host ""
Write-Host "接着提交并推送：" -ForegroundColor Yellow
Write-Host "  git -C `"$Root`" add -A"
Write-Host "  git -C `"$Root`" commit -m `"publish: $internalName $shortVersion`""
Write-Host "  git -C `"$Root`" push"
