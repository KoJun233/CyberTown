param(
    [int]$Port = 18080,
    [string]$DatabasePath = '',
    [string]$InviteCodes = 'CYBER-NEIGHBOR-A,CYBER-NEIGHBOR-B'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$serverDirectory = Join-Path $projectRoot 'server'

if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    throw "端口 $Port 已被使用。请先在原服务端终端按 Ctrl+C 停止旧服务，或使用 -Port 指定其他端口。"
}

if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
    if ($env:CYBERTOWN_DB_PATH) {
        $DatabasePath = $env:CYBERTOWN_DB_PATH
    } elseif (Test-Path -LiteralPath (Join-Path $serverDirectory 'target\cybertown-pc-test.db')) {
        # Continue the first PC test database so existing residents remain available.
        $DatabasePath = Join-Path $serverDirectory 'target\cybertown-pc-test.db'
    } else {
        $DatabasePath = Join-Path $serverDirectory 'cybertown.db'
    }
}
$databaseCandidate = if ([System.IO.Path]::IsPathRooted($DatabasePath)) {
    $DatabasePath
} else {
    Join-Path $serverDirectory $DatabasePath
}
$resolvedDatabase = [System.IO.Path]::GetFullPath($databaseCandidate)
$env:SERVER_PORT = [string]$Port
$env:CYBERTOWN_DB_PATH = $resolvedDatabase
$env:CYBERTOWN_BOOTSTRAP_INVITE_CODES = $InviteCodes
$env:CYBERTOWN_AI_ENABLED = 'false'

$javaExecutable = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { (Get-Command java).Source }
Push-Location $serverDirectory
try {
    & '.\mvnw.cmd' package -DskipTests
    if ($LASTEXITCODE -ne 0) { throw '服务端构建失败，请查看上面的错误。' }
    $socketDirectory = Join-Path $serverDirectory 'target'
    $jarPath = Join-Path $socketDirectory 'cybertown-server-0.0.1-SNAPSHOT.jar'
    Write-Host "CyberTown API: http://127.0.0.1:$Port/api"
    Write-Host "数据库: $resolvedDatabase"
    Write-Host "测试邀请码: $InviteCodes（每个邀请码只能使用一次）"
    & $javaExecutable "-Djdk.net.unixdomain.tmpdir=$socketDirectory" -jar $jarPath
    if ($LASTEXITCODE -ne 0) { throw "服务端退出，错误码为 $LASTEXITCODE。" }
} finally {
    Pop-Location
}
