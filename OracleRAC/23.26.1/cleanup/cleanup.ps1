#Requires -Version 5.1
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# cleanup.ps1
#   Windows (PowerShell) port of cleanup.sh. Tears down the RAC lab and removes
#   the shared ASM disks (and per-node u01 disks on VirtualBox) that
#   `vagrant destroy` intentionally leaves behind.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\cleanup.ps1 [-Force]
#   # or, if execution policy allows:
#   .\cleanup.ps1 [-Force]
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本在 Windows 上销毁 RAC 实验环境，并删除共享 ASM 磁盘与节点专用磁盘。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

[CmdletBinding()]
param(
    [Alias('f')][switch]$Force,
    [Alias('h')][switch]$Help
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)

$Config = '.\config\vagrant.yml'
if (-not (Test-Path -LiteralPath 'Vagrantfile')) {
    Write-Error '未找到 Vagrantfile；请从项目根目录运行'; exit 1
}
if (-not (Test-Path -LiteralPath $Config)) {
    Write-Error "$Config 未找到"; exit 1
}

# Minimal YAML scalar reader for the flat 2-level structure vagrant.yml uses
# (top-level section, then 2-space-indented key: value lines). Mirrors the awk
# logic in cleanup.sh so behaviour stays identical.
# 轻量解析 vagrant.yml，避免依赖额外 YAML 模块。
function Get-YamlValue {
    param([string]$Section, [string]$Key)
    $current = $null
    foreach ($raw in Get-Content -LiteralPath $Config) {
        if ($raw -match '^[A-Za-z_][A-Za-z0-9_]*:') {
            $current = ($raw -split ':', 2)[0].Trim()
            continue
        }
        if ($current -ne $Section) { continue }
        $line = $raw -replace '^\s+', ''
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $idx = $line.IndexOf(':')
        if ($idx -lt 0) { continue }
        if ($line.Substring(0, $idx) -ne $Key) { continue }
        $val = $line.Substring($idx + 1)
        $val = ($val -replace '#.*$', '').Trim()
        return $val
    }
    return ''
}

$Provider = Get-YamlValue -Section 'env'    -Key 'provider'
$Prefix   = Get-YamlValue -Section 'env' -Key 'prefix_name'
$AsmNum   = Get-YamlValue -Section 'env' -Key 'asm_disk_num'
$AsmPath  = Get-YamlValue -Section 'env' -Key 'asm_disk_path'
$Pool     = Get-YamlValue -Section 'env' -Key 'storage_pool_name'

if ([string]::IsNullOrEmpty($Provider) -or [string]::IsNullOrEmpty($Prefix) -or [string]::IsNullOrEmpty($AsmNum)) {
    Write-Error "必须在 $Config 中设置 env.provider / shared.prefix_name / shared.asm_disk_num"
    exit 1
}
$AsmNumInt = [int]$AsmNum

if ($Help) {
@"
用法：.\cleanup.ps1 [-Force]
  运行 'vagrant destroy -f' 并删除已配置 provider 的共享 ASM 磁盘
  当前 provider 为 $Provider。传入 -Force 可跳过确认提示。
"@
    exit 0
}

if (-not $Force) {
    Write-Host "将执行以下操作："
    Write-Host "  1. vagrant destroy -f"
    Write-Host "  2. 删除 $AsmNumInt 个共享 ASM 磁盘（provider：$Provider）"
    if ($Provider -eq 'virtualbox') {
        Write-Host "  3. 删除每个节点的 u01 磁盘（node1_u01.vdi、node2_u01.vdi）"
    }
    Write-Host ""
    $ans = Read-Host '是否继续？[y/N]'
    if ($ans -notmatch '^[yY]$') { Write-Host '已取消。'; exit 0 }
}

# Resolve VBoxManage: prefer PATH, then default install location.
function Get-VBoxManage {
    $cmd = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $default = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
    if (Test-Path -LiteralPath $default) { return $default }
    return $null
}

function Invoke-VBoxCloseAndDelete {
    param([string]$Path, [string]$VBoxManage)
    $listed = & $VBoxManage list hdds 2>$null
    if ($LASTEXITCODE -eq 0 -and ($listed | Select-String -SimpleMatch $Path -Quiet)) {
        & $VBoxManage closemedium disk "$Path" --delete 2>$null
        if ($LASTEXITCODE -ne 0) {
            & $VBoxManage closemedium disk "$Path" 2>$null | Out-Null
        }
    }
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}

Write-Host '=== 正在执行 vagrant destroy -f ==='
try { & vagrant destroy -f } catch { Write-Warning $_ }

switch ($Provider) {
    'libvirt' {
        # libvirt isn't native on Windows; surface a clear error rather than
        # pretending to clean up. Users on Hyper-V/WSL should run cleanup.sh
        # from inside the Linux environment that actually hosts the pool.
        Write-Error "Windows 不支持 provider 'libvirt'；请在拥有该存储池的 Linux 主机上运行 cleanup.sh"
        exit 1
    }
    'virtualbox' {
        $vbm = Get-VBoxManage
        if (-not $vbm) {
            Write-Error '在 PATH 或默认安装位置中未找到 VBoxManage.exe'
            exit 1
        }
        $dir = if ([string]::IsNullOrEmpty($AsmPath)) { '.' } else { $AsmPath.TrimEnd('\','/') }
        Write-Host "=== 正在从 $dir 删除 VirtualBox 共享 ASM 磁盘 ==="
        for ($i = 0; $i -lt $AsmNumInt; $i++) {
            $p = [System.IO.Path]::GetFullPath((Join-Path $dir "asm_disk$i.vdi"))
            Invoke-VBoxCloseAndDelete -Path $p -VBoxManage $vbm
        }
        Write-Host '=== 正在删除每个节点的 u01 磁盘 ==='
        foreach ($node_disk in 'node1_u01.vdi', 'node2_u01.vdi') {
            $p = [System.IO.Path]::GetFullPath((Join-Path '.' $node_disk))
            Invoke-VBoxCloseAndDelete -Path $p -VBoxManage $vbm
        }
    }
    default {
        Write-Error "配置文件 $Config 中的 provider '$Provider' 未知"
        exit 1
    }
}

Write-Host '清理完成。'
