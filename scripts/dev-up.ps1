param(
  [string]$FirebaseWebApiKey = "AIzaSyCPf2mLl4emmB5SxGbOoBlePoCF5UX2elc",
  [string]$DeviceId = "emulator-5554"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$functionsDir = Join-Path $projectRoot "functions"

Write-Host "[1/4] Cerrando emuladores Firebase viejos..."
$ports = @(5001, 4400, 4000, 4500, 9299, 9499)
$processIds = @()
foreach ($port in $ports) {
  $listeners = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue
  if ($listeners) {
    $processIds += $listeners | Select-Object -ExpandProperty OwningProcess
  }
}
$processIds = $processIds | Sort-Object -Unique
foreach ($procId in $processIds) {
  try {
    Stop-Process -Id $procId -Force -ErrorAction Stop
    Write-Host "  - Proceso detenido: $procId"
  } catch {
    Write-Host "  - No se pudo detener proceso $procId (puede que ya no exista)."
  }
}

Write-Host "[2/4] Iniciando Functions Emulator..."
Write-Host "  - Compilando backend (npm run build)..."
Push-Location $functionsDir
try {
  npm run build | Out-Host
} finally {
  Pop-Location
}

$backendCommand = "`$env:FIREBASE_WEB_API_KEY='$FirebaseWebApiKey'; npx firebase-tools emulators:start --only functions"
$backendProc = Start-Process -FilePath "powershell" -ArgumentList "-NoExit", "-Command", $backendCommand -WorkingDirectory $functionsDir -PassThru

Write-Host "  - Esperando backend en /health..."
$healthUrl = "http://127.0.0.1:5001/ganapp-d451b/us-central1/api/health"
$ready = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec 2
    if ($resp.StatusCode -eq 200) {
      $ready = $true
      break
    }
  } catch {
  }
}

if (-not $ready) {
  Write-Host "[ERROR] Backend no respondio en /health. Revisa la terminal de functions."
  exit 1
}

Write-Host "[3/4] Backend listo."
Write-Host "[4/4] Ejecutando Flutter en $DeviceId..."
Set-Location $projectRoot
flutter run -d $DeviceId --dart-define=GANAPP_API_BASE_URL=http://10.0.2.2:5001/ganapp-d451b/us-central1/api
