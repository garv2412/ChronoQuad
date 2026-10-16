# Run Quadruped-PyMPC Simulation in Docker with GPU & Windows GUI
param (
    [switch]$Headless,
    [string]$Command = "python simulation/simulation.py"
)

$HostWorkspace = "D:\Academics\cs_project"

# 1. Ensure Docker Engine is running
Write-Host "[*] Checking Docker Desktop status..." -ForegroundColor Cyan
$dockerStatus = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[*] Docker daemon is not running. Starting Docker Desktop..." -ForegroundColor Yellow
    $desktopExe = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
    $backendPath = "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\com.docker.backend.exe"

    if (Test-Path $desktopExe) {
        Start-Process -FilePath $desktopExe
    } elseif (Test-Path $backendPath) {
        Start-Process -FilePath $backendPath -ArgumentList "-h" -WindowStyle Hidden
    }

    $retries = 30
    while ($retries -gt 0) {
        Start-Sleep -Seconds 2
        $test = docker ps 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] Docker is ready!" -ForegroundColor Green
            break
        }
        $retries--
        Write-Host "    Waiting for Docker Desktop to finish booting... ($retries left)" -ForegroundColor Gray
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] Could not connect to Docker. Please make sure Docker Desktop is open and running." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[+] Docker daemon is running." -ForegroundColor Green
}

# 2. Build Docker command
$isInteractive = [System.Console]::IsInputRedirected -eq $false
$ttyFlags = if ($isInteractive) { @("-it") } else { @("-i") }

$dockerArgs = @(
    "run"
) + $ttyFlags + @(
    "--rm",
    "--gpus", "all",
    "-v", "${HostWorkspace}:/workspace",
    "-e", "PYTHONPATH=/workspace:/workspace/quadruped_pympc/acados/interfaces/acados_template",
    "-e", "ACADOS_SOURCE_DIR=/workspace/quadruped_pympc/acados",
    "-e", "LD_LIBRARY_PATH=/workspace/quadruped_pympc/acados/lib"
)

if (-not $Headless) {
    # Mount WSLg X11 & Wayland sockets for native Windows desktop GUI
    $dockerArgs += @(
        "-v", "/mnt/host/wslg/.X11-unix:/tmp/.X11-unix:rw",
        "-v", "/mnt/host/wslg:/mnt/wslg:rw",
        "-e", "DISPLAY=:0",
        "-e", "WAYLAND_DISPLAY=wayland-0",
        "-e", "XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir",
        "-e", "PULSE_SERVER=/mnt/wslg/PulseServer"
    )
    Write-Host "[*] GUI mode enabled via WSLg display forwarding." -ForegroundColor Cyan
} else {
    Write-Host "[*] Running in headless mode." -ForegroundColor Yellow
}

$dockerArgs += "quadruped_pympc:sim"
$dockerArgs += @("bash", "-c", $Command)

Write-Host "[*] Launching Quadruped-PyMPC Simulation..." -ForegroundColor Green
Write-Host "    Controls in GUI:" -ForegroundColor White
Write-Host "    - Arrow Up / Down:    Accelerate forward / backward" -ForegroundColor Gray
Write-Host "    - Arrow Left / Right: Yaw turn left / right" -ForegroundColor Gray
Write-Host "    - Ctrl:               Reset reference velocities to zero" -ForegroundColor Gray
Write-Host "    - Space:              Pause / Resume simulation" -ForegroundColor Gray
Write-Host "    - Mouse drag:         Orbit camera / apply perturbation forces" -ForegroundColor Gray
Write-Host "    - Ctrl+C in terminal: Stop simulation" -ForegroundColor Gray
Write-Host ""

& docker $dockerArgs
