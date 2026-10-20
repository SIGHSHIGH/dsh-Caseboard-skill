<#
.SYNOPSIS
  CaseBoard 一键自检：按 skill 约定的台阶跑验证，输出 PASS/FAIL 摘要。
.DESCRIPTION
  在仓库根目录执行，也可以从任何位置执行（脚本会自己往上找仓库根）。
    -Root <dir> 显式指定仓库根（找不到时用这个）
    -Quick   只跑 typecheck + smoke（改 lib/ 或 commands/ 用这个）
    -Full    跑全部五道：typecheck / smoke / build / ui-smoke / bench（默认）
    -NoBench 跳过 bench
  退出码 = 失败步骤数（0 表示全绿）。
.NOTES
  TMP/TEMP 会自动指向 <root>\.tmp-esbuild，避免 esbuild 在系统 Temp 报
  "[vite:esbuild-transpile] remove ...: Access is denied"。
#>
param(
  [string]$Root,
  [switch]$Quick,
  [switch]$Full,
  [switch]$NoBench
)

$ErrorActionPreference = 'Stop'

function Test-RepoRoot([string]$dir) {
  if (-not $dir) { return $false }
  return (Test-Path -LiteralPath (Join-Path $dir 'scripts\pnpm.cmd')) -and
         (Test-Path -LiteralPath (Join-Path $dir 'src-tauri\tauri.conf.json'))
}

function Resolve-RepoRoot([string]$hint) {
  if ($hint) {
    if (Test-RepoRoot $hint) { return (Resolve-Path -LiteralPath $hint).Path }
    throw "指定的 -Root 不是 CaseBoard 仓库根（缺 scripts\pnpm.cmd 或 src-tauri\tauri.conf.json）：$hint"
  }
  $dir = $PSScriptRoot
  for ($i = 0; $i -lt 12 -and $dir; $i++) {
    if (Test-RepoRoot $dir) { return $dir }
    $dir = Split-Path -LiteralPath $dir -Parent
  }
  $gitRoot = (& git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -eq 0 -and $gitRoot) {
    $gitRoot = $gitRoot.Trim()
    if (Test-RepoRoot $gitRoot) { return $gitRoot }
  }
  throw "找不到 CaseBoard 仓库根（向上找了 12 层也没见到 scripts\pnpm.cmd + src-tauri\tauri.conf.json）。请用 -Root <仓库根> 指定。"
}

$root = Resolve-RepoRoot $Root
Set-Location $root

$env:TMP = Join-Path $root '.tmp-esbuild'
$env:TEMP = $env:TMP
New-Item -ItemType Directory -Force -Path $env:TMP | Out-Null

$pnpm = Join-Path $root 'scripts\pnpm.cmd'
if (-not (Test-Path $pnpm)) { throw "找不到 $pnpm —— 确认当前仓库是 CaseBoard。" }

if ($Quick) {
  $steps = @('typecheck', 'smoke')
} else {
  $steps = @('typecheck', 'smoke', 'build', 'ui-smoke')
  if (-not $NoBench) { $steps += 'bench' }
}

Write-Host ''
Write-Host "CaseBoard 自检 · $root" -ForegroundColor Cyan
Write-Host ("步骤：" + ($steps -join ' → '))
Write-Host ''

$results = @()
foreach ($step in $steps) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Write-Host "── $step " -ForegroundColor Yellow -NoNewline
  # 原生命令的 stderr（vite 进度、tsc 提示）不能被 ErrorActionPreference=Stop 当成异常中断
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $pnpm $step 2>&1 | Tee-Object -Variable out | Out-Null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $sw.Stop()
  if ($code -eq 0) {
    Write-Host ("OK  ({0:n1}s)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
  } else {
    Write-Host ("FAIL (exit $code)" -f 0) -ForegroundColor Red
    $out | Select-Object -Last 25 | ForEach-Object { Write-Host "   $_" }
  }
  $results += [pscustomobject]@{ Step = $step; Exit = $code; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}

Write-Host ''
$results | Format-Table -AutoSize | Out-String | Write-Host

$failed = @($results | Where-Object { $_.Exit -ne 0 })
if ($failed.Count -eq 0) {
  Write-Host '全部通过 ✔' -ForegroundColor Green
  Write-Host '提醒：改到 .tsx 或 Rust 时，ui-smoke 前必须先 build；打包发布还要跑 node scripts/run-selftest.cjs（桌面两轮）。' -ForegroundColor DarkGray
} else {
  Write-Host ("失败 " + $failed.Count + " 步：" + (($failed | ForEach-Object { $_.Step }) -join ', ')) -ForegroundColor Red
  Write-Host '先读 references/02-verification.md 的「失败处置」，不要改断言来迁就实现。' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '本次改动：' -ForegroundColor Cyan
git status --short
exit $failed.Count
