<#
.SYNOPSIS
  Smoke test for one SAVIA hub URL (a revision URL before promotion, or the app URL after).

.DESCRIPTION
  Passes only if all three checks pass:
    1. GET  /health returns {"status":"ok"}.
    2. GET  / returns the SAVIA access page.
    3. POST /api/v1/auth/login with an unknown account returns 401 auth.bad_credentials,
       which proves the API reached Azure SQL with its managed identity.
  It retries for up to RetrySeconds to cover a cold start. Exit 0 pass, 1 fail.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern('^(https://|http://127\.0\.0\.1[:/])')] [string] $BaseUrl,
    [ValidateRange(10, 900)] [int] $RetrySeconds = 240
)

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')

function Get-Response([string] $Method, [string] $Path, [string] $Body) {
    $request = @{ Uri = "$BaseUrl$Path"; Method = $Method; TimeoutSec = 20; SkipHttpErrorCheck = $true; MaximumRedirection = 0 }
    if ($Body) { $request.Body = $Body; $request.ContentType = 'application/json' }
    return Invoke-WebRequest @request
}

function Test-Hub {
    $health = Get-Response GET '/health'
    if ($health.StatusCode -ne 200 -or $health.Content -notmatch '"status"\s*:\s*"ok"') { return "health: HTTP $($health.StatusCode)" }
    $page = Get-Response GET '/'
    if ($page.StatusCode -ne 200 -or $page.Content -notmatch 'id="access"') { return "access page: HTTP $($page.StatusCode)" }
    $login = Get-Response POST '/api/v1/auth/login' '{"loginName":"smoke.unknown","password":"not-a-real-password-1"}'
    if ($login.StatusCode -ne 401 -or $login.Content -notmatch 'auth\.bad_credentials') { return "login: HTTP $($login.StatusCode)" }
    return ''
}

$deadline = (Get-Date).AddSeconds($RetrySeconds)
$problem = 'not run'
while ((Get-Date) -lt $deadline) {
    try { $problem = Test-Hub } catch { $problem = $_.Exception.Message }
    if (-not $problem) {
        Write-Host "smoke: PASS $BaseUrl (health, access page, SQL-backed login refusal)"
        exit 0
    }
    Write-Host "smoke: waiting ($problem)"
    Start-Sleep -Seconds 10
}
Write-Host "smoke: FAIL $BaseUrl ($problem)"
exit 1
