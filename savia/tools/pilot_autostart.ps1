[CmdletBinding(DefaultParameterSetName = 'Status')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Install')][switch]$Install,
    [Parameter(Mandatory, ParameterSetName = 'Uninstall')][switch]$Uninstall,
    [Parameter(ParameterSetName = 'Status')][switch]$Status,
    [Parameter(Mandatory, ParameterSetName = 'RunPilot')][switch]$RunPilot,
    [Parameter(Mandatory, ParameterSetName = 'RunBackup')][switch]$RunBackup,
    [Parameter(ParameterSetName = 'RunPilot')]
    [Parameter(ParameterSetName = 'RunBackup')]
    [string]$PythonPath = 'python'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$logFolder = Join-Path $repoRoot 'savia\.out\pilot'
$logPath = Join-Path $logFolder 'autostart.log'
$taskNames = @('SAVIA Piloto', 'SAVIA Respaldo')
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentUser = $currentIdentity.Name
$currentSid = $currentIdentity.User.Value

function Write-OperationLog([string]$Message) {
    Add-Content -LiteralPath $logPath -Value ('{0} {1}' -f (Get-Date -Format o), $Message) -Encoding UTF8
}

function Assert-TaskOwner($Task) {
    if ($null -eq $Task) { return }
    $owner = $Task.Principal.UserId
    if ($owner -ne $currentUser -and $owner -ne $currentSid) {
        throw "La tarea '$($Task.TaskName)' pertenece a otro usuario."
    }
}

function Wait-LocalSql {
    $deadline = (Get-Date).AddMinutes(5)
    $docker = (Get-Command docker.exe -ErrorAction Stop).Source
    # Bound each Docker probe as well as the total wait.
    function Invoke-DockerProbe([string]$Arguments) {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $docker
        $info.Arguments = $Arguments
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($info)
        try {
            if (-not $process.WaitForExit(5000)) {
                $process.Kill()
                return $null
            }
            if ($process.ExitCode -ne 0) { return $null }
            return $process.StandardOutput.ReadToEnd().Trim()
        }
        finally { $process.Dispose() }
    }
    if ($null -eq (Invoke-DockerProbe 'info --format "{{.ServerVersion}}"')) {
        $desktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
        if (-not (Test-Path -LiteralPath $desktop)) { throw 'No se encuentra Docker Desktop.' }
        Start-Process -FilePath $desktop -WindowStyle Hidden | Out-Null
        Write-OperationLog 'Iniciando Docker Desktop.'
    }
    while ((Get-Date) -lt $deadline) {
        $health = Invoke-DockerProbe 'inspect --format "{{.State.Health.Status}}" savia-sqlserver-dev'
        if ($health -eq 'healthy') { return }
        Start-Sleep -Seconds 2
    }
    throw 'SQL Server no quedó saludable dentro de cinco minutos; no se inició el piloto.'
}

try {
    if ($RunPilot -or $RunBackup) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        Set-Location -LiteralPath $repoRoot
        Write-OperationLog ('Inicio: ' + $PSCmdlet.ParameterSetName)
        Wait-LocalSql
        # Pin the existing container; never create one or use a remote context intentionally.
        $env:SAVIA_SQL_CONTAINER = 'savia-sqlserver-dev'
        if ($RunPilot) {
            & $PythonPath 'savia/tools/pilot.py' up --no-provision 2>&1 |
                ForEach-Object { Add-Content -LiteralPath $logPath -Value $_ -Encoding UTF8 }
        }
        else {
            & $PythonPath 'savia/tools/pilot_backup.py' backup 2>&1 |
                ForEach-Object { Add-Content -LiteralPath $logPath -Value $_ -Encoding UTF8 }
        }
        $operationExit = $LASTEXITCODE
        Write-OperationLog "Fin: exit $operationExit"
        exit $operationExit
    }

    if ($Install) {
        $python = Get-Command python -ErrorAction Stop
        if ($python.Source -like '*\WindowsApps\*') {
            throw 'Configure un Python local ejecutable, sin el alias de Microsoft Store.'
        }
        foreach ($name in $taskNames) {
            Assert-TaskOwner (Get-ScheduledTask -TaskName $name -TaskPath '\' -ErrorAction SilentlyContinue)
        }
        $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
            -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        $engine = Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $engine)) { $engine = Join-Path $PSHOME 'pwsh.exe' }
        $quotedScript = '"' + $PSCommandPath + '"'
        $quotedPython = '"' + $python.Source + '"'
        $pilotAction = New-ScheduledTaskAction -Execute $engine -WorkingDirectory $repoRoot `
            -Argument "-NoProfile -NonInteractive -File $quotedScript -RunPilot -PythonPath $quotedPython"
        $backupAction = New-ScheduledTaskAction -Execute $engine -WorkingDirectory $repoRoot `
            -Argument "-NoProfile -NonInteractive -File $quotedScript -RunBackup -PythonPath $quotedPython"
        $logon = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
        $daily = New-ScheduledTaskTrigger -Daily -At '20:00'
        Register-ScheduledTask -TaskName $taskNames[0] -TaskPath '\' -Action $pilotAction `
            -Trigger $logon -Principal $principal -Settings $settings -Force | Out-Null
        Register-ScheduledTask -TaskName $taskNames[1] -TaskPath '\' -Action $backupAction `
            -Trigger @($logon, $daily) -Principal $principal -Settings $settings -Force | Out-Null
        Write-Output 'Tareas instaladas para el usuario actual, sin contraseña almacenada.'
    }
    elseif ($Uninstall) {
        foreach ($name in $taskNames) {
            $task = Get-ScheduledTask -TaskName $name -TaskPath '\' -ErrorAction SilentlyContinue
            Assert-TaskOwner $task
            if ($null -ne $task) {
                Unregister-ScheduledTask -TaskName $name -TaskPath '\' -Confirm:$false
            }
        }
        Write-Output 'Tareas retiradas.'
    }
    else {
        foreach ($name in $taskNames) {
            $task = Get-ScheduledTask -TaskName $name -TaskPath '\' -ErrorAction SilentlyContinue
            if ($null -eq $task) { Write-Output "$name : no instalada"; continue }
            $info = Get-ScheduledTaskInfo -TaskName $name -TaskPath '\'
            [pscustomobject]@{
                Tarea = $name; Estado = $task.State; Usuario = $task.Principal.UserId
                Nivel = $task.Principal.RunLevel; TipoIngreso = $task.Principal.LogonType
                UltimaEjecucion = $info.LastRunTime; Resultado = $info.LastTaskResult
                ProximaEjecucion = $info.NextRunTime
            } | Format-List
        }
    }
    exit 0
}
catch {
    if ($RunPilot -or $RunBackup) { Write-OperationLog ('ERROR: ' + $_.Exception.Message) }
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
