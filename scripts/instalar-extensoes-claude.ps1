# instalar-extensoes-claude.ps1
# Instala as extensoes auditadas em 25/10/2026, fixadas nos commits que foram lidos:
#   - Servidor MCP music21 (analise harmonica)     brightlikethelight/music21-mcp-server @ dd2ca1b
#   - Servidor MCP philosophy (PhilPapers, SEP...)  sea9401/philosophy-mcp              @ 96a3929
#   - Skill d3-viz (Claude Code)                    chrisvoncsefalvay/claude-d3js-skill  @ e198c87
#   - Skill webapp-testing (Claude Code)            anthropics/skills                    @ dbd4588
#   - Plugin superpowers (Claude Code)              obra/superpowers-marketplace
# Cada etapa e independente: se uma falhar, as outras continuam.
#
# Como rodar (PowerShell, na pasta onde salvou este arquivo):
#   powershell -ExecutionPolicy Bypass -File .\instalar-extensoes-claude.ps1

$ErrorActionPreference = 'Stop'
$Base = Join-Path $HOME 'claude-extensoes'
$Src  = Join-Path $Base 'src'
New-Item -ItemType Directory -Force -Path $Src | Out-Null

$Pins = @{
  music21 = 'dd2ca1b10187e1363f5e3c8a9c0c06d40b4f1470'
  philo   = '96a39290ac7095db0fe8895b08d3e288c088c73f'
  d3      = 'e198c87d03f1c9811acbff681886fac24baee53d'
  skills  = 'dbd4588f9e1033efb41dad4bef2f7947c8993d44'
}
$Report = [ordered]@{}

function Say($msg, $color = 'Cyan') { Write-Host "`n== $msg" -ForegroundColor $color }
function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Run($exe, [string[]]$argList) {
  & $exe @argList
  if ($LASTEXITCODE -ne 0) { throw "$exe $($argList -join ' ') terminou com codigo $LASTEXITCODE" }
}
function Get-Pinned($repo, $sha, $dir) {
  if (-not (Test-Path (Join-Path $dir '.git'))) { Run git @('clone', '-q', "https://github.com/$repo.git", $dir) }
  Run git @('-C', $dir, 'fetch', '-q', 'origin', $sha)
  Run git @('-C', $dir, 'checkout', '-q', $sha)
}

# ---------- 0. Pre-requisitos ----------
Say 'Verificando pre-requisitos'
$Py = $null
if (Has 'py') { $Py = @('py', '-3') } elseif (Has 'python') { $Py = @('python') }
$missing = @()
if (-not (Has 'git'))  { $missing += 'Git (https://git-scm.com/download/win)' }
if (-not (Has 'node')) { $missing += 'Node.js LTS (https://nodejs.org)' }
if (-not $Py)          { $missing += 'Python 3.10+ (https://www.python.org/downloads/ - marque "Add to PATH")' }
if ($missing.Count) {
  Write-Host 'Faltam programas. Instale e rode o script de novo:' -ForegroundColor Yellow
  $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
  exit 1
}
$HasClaudeCode = Has 'claude'
Write-Host "git, node, python: ok. Claude Code (comando 'claude'): $HasClaudeCode"

$Mail = Read-Host 'E-mail para a fila prioritaria do OpenAlex (opcional, ENTER para pular)'

# ---------- 1. Servidor music21 ----------
Say 'Instalando servidor music21 (pode levar alguns minutos)'
$VenvPy = Join-Path $Base 'music21-venv\Scripts\python.exe'
try {
  if (-not (Test-Path $VenvPy)) { Run $Py[0] (@($Py | Select-Object -Skip 1) + @('-m', 'venv', (Join-Path $Base 'music21-venv'))) }
  Run $VenvPy @('-m', 'pip', 'install', '-q', '--upgrade', 'pip')
  Run $VenvPy @('-m', 'pip', 'install', '-q', "git+https://github.com/brightlikethelight/music21-mcp-server.git@$($Pins.music21)")
  Run $VenvPy @('-c', 'import music21_mcp.server_minimal')
  $Report['music21 (servidor)'] = 'OK'
} catch { $Report['music21 (servidor)'] = "FALHOU: $_" }

# ---------- 2. Servidor philosophy ----------
Say 'Instalando servidor philosophy'
$PhiloDir = Join-Path $Src 'philosophy-mcp'
$PhiloJs  = Join-Path $PhiloDir 'dist\index.js'
try {
  Get-Pinned 'sea9401/philosophy-mcp' $Pins.philo $PhiloDir
  Push-Location $PhiloDir
  try { Run npm @('ci', '--no-audit', '--no-fund', '--loglevel=error'); Run npm @('run', 'build') } finally { Pop-Location }
  if (-not (Test-Path $PhiloJs)) { throw 'dist\index.js nao foi gerado' }
  $Report['philosophy (servidor)'] = 'OK'
} catch { $Report['philosophy (servidor)'] = "FALHOU: $_" }

# ---------- 3. Claude Desktop: registrar os dois servidores ----------
Say 'Registrando os servidores no Claude Desktop'
$cfgCandidates = @((Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'))
$storePkg = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($storePkg) { $cfgCandidates = @((Join-Path $storePkg.FullName 'LocalCache\Roaming\Claude\claude_desktop_config.json')) + $cfgCandidates }
$Cfg = $cfgCandidates | Where-Object { Test-Path (Split-Path $_) } | Select-Object -First 1
try {
  if (-not $Cfg) { throw 'pasta de configuracao do Claude Desktop nao encontrada (o app esta instalado?)' }
  if (Test-Path $Cfg) {
    Copy-Item $Cfg "$Cfg.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    $raw = [IO.File]::ReadAllText($Cfg)
    $conf = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  } else { $conf = [pscustomobject]@{} }
  if (-not $conf.PSObject.Properties['mcpServers']) { $conf | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) }
  $servers = $conf.mcpServers
  if (Test-Path $VenvPy) {
    $servers | Add-Member -Force -NotePropertyName music21 -NotePropertyValue ([pscustomobject]@{
      command = $VenvPy; args = @('-m', 'music21_mcp.server_minimal') })
  }
  if (Test-Path $PhiloJs) {
    $entry = [pscustomobject]@{ command = 'node'; args = @($PhiloJs) }
    if ($Mail) { $entry | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{ OPENALEX_MAILTO = $Mail }) }
    $servers | Add-Member -Force -NotePropertyName philosophy -NotePropertyValue $entry
  }
  $json = $conf | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($Cfg, $json, (New-Object Text.UTF8Encoding $false))
  $Report['Claude Desktop (config)'] = "OK ($Cfg; backup salvo ao lado)"
} catch { $Report['Claude Desktop (config)'] = "FALHOU: $_" }

# ---------- 4. Claude Code: servidores, skills e superpowers ----------
if ($HasClaudeCode) {
  Say 'Configurando o Claude Code'
  try {
    foreach ($n in 'music21', 'philosophy') {   # remove registro antigo, se houver (ignora erro)
      $prev = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
      try { & claude mcp remove --scope user $n *> $null } catch {} finally { $ErrorActionPreference = $prev }
    }
    if (Test-Path $VenvPy) {
      Run claude @('mcp', 'add', '--scope', 'user', 'music21', '--', $VenvPy, '-m', 'music21_mcp.server_minimal')
    }
    if (Test-Path $PhiloJs) {
      $a = @('mcp', 'add', '--scope', 'user')
      if ($Mail) { $a += @('-e', "OPENALEX_MAILTO=$Mail") }
      Run claude ($a + @('philosophy', '--', 'node', $PhiloJs))
    }
    $Report['Claude Code (servidores)'] = 'OK'
  } catch { $Report['Claude Code (servidores)'] = "FALHOU: $_" }

  try {
    $SkillsDir = Join-Path $HOME '.claude\skills'
    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
    Get-Pinned 'chrisvoncsefalvay/claude-d3js-skill' $Pins.d3 (Join-Path $Src 'd3js-skill')
    Get-Pinned 'anthropics/skills' $Pins.skills (Join-Path $Src 'anthropic-skills')
    $d3 = Join-Path $SkillsDir 'd3-viz'
    New-Item -ItemType Directory -Force -Path $d3 | Out-Null
    foreach ($item in 'SKILL.md', 'references', 'assets') { Copy-Item -Recurse -Force (Join-Path $Src "d3js-skill\$item") $d3 }
    Copy-Item -Recurse -Force (Join-Path $Src 'anthropic-skills\skills\webapp-testing') $SkillsDir
    $Report['Claude Code (skills d3-viz, webapp-testing)'] = "OK ($SkillsDir)"
  } catch { $Report['Claude Code (skills d3-viz, webapp-testing)'] = "FALHOU: $_" }

  try {
    Run claude @('plugin', 'marketplace', 'add', 'obra/superpowers-marketplace')
    Run claude @('plugin', 'install', 'superpowers@superpowers-marketplace')
    # O "companheiro visual" do brainstorming carrega um logo de primeradiant.com; isto desliga.
    [Environment]::SetEnvironmentVariable('SUPERPOWERS_DISABLE_TELEMETRY', '1', 'User')
    $Report['Claude Code (superpowers)'] = 'OK (telemetria desligada)'
  } catch { $Report['Claude Code (superpowers)'] = "FALHOU: $_" }

  # webapp-testing roda scripts no Python do sistema, entao o Playwright vai la (nao no venv do music21)
  $PyArgs = @($Py | Select-Object -Skip 1)
  try { Run $Py[0] ($PyArgs + @('-m', 'pip', 'install', '-q', '--user', 'playwright')); Run $Py[0] ($PyArgs + @('-m', 'playwright', 'install', 'chromium'))
        $Report['Playwright (para webapp-testing)'] = 'OK' } catch { $Report['Playwright (para webapp-testing)'] = "FALHOU: $_" }
} else {
  $Report['Claude Code'] = "PULADO: comando 'claude' nao encontrado no PATH"
}

# ---------- Resumo ----------
Say 'Resumo' 'Green'
foreach ($k in $Report.Keys) {
  $c = if ($Report[$k] -like 'OK*') { 'Green' } elseif ($Report[$k] -like 'PULADO*') { 'Yellow' } else { 'Red' }
  Write-Host ("  {0,-45} {1}" -f $k, $Report[$k]) -ForegroundColor $c
}
Write-Host "`nFeche o Claude Desktop pela bandeja do sistema (Sair) e abra de novo para carregar os servidores." -ForegroundColor Yellow
Write-Host "No Claude Code, abra uma sessao nova e rode /mcp para conferir." -ForegroundColor Yellow
