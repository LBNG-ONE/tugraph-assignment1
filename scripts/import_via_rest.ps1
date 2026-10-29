# 通过 TuGraph RESTful API 批量导入 CSV 数据
#
# 用法（管理员不必，但脚本执行策略需放行）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File import_via_rest.ps1 `
#       -Base http://localhost:7070 -Graph lab1_movie `
#       -User admin -Password 73@TuGraph -DataDir ..\data
#
# 说明：
#   - 顶点按每批 10 条拼成单条 CREATE 语句写入
#   - 边用 MATCH (a),(b) CREATE (a)-[:rel]->(b) 逐条写入
#   - 之所以用 REST 而非 Web 界面上传：批量、可重复、可脚本化

param(
    [string]$Base = 'http://localhost:7070',
    [string]$Graph = 'lab1_movie',
    [string]$User = 'admin',
    [string]$Password = '73@TuGraph',
    [string]$DataDir = ''
)

$ErrorActionPreference = 'Stop'
if (-not $DataDir) { $DataDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'data' }

function Write-Log($m) { Write-Host $m }

# ---------- 登录 ----------
$login = Invoke-RestMethod -Uri "$Base/login" -Method Post `
    -Body (@{ user = $User; password = $Password } | ConvertTo-Json -Compress) `
    -ContentType 'application/json' -TimeoutSec 30
$hdr = @{ Authorization = "Bearer $($login.jwt)"; 'Content-Type' = 'application/json; charset=utf-8' }
Write-Log "login ok"

function Cypher([string]$script) {
    $b = @{ graph = $Graph; script = $script } | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($b)
    try {
        return Invoke-RestMethod -Uri "$Base/cypher" -Method Post -Headers $hdr -Body $bytes -TimeoutSec 180
    } catch {
        return @{ error = $_.ErrorDetails.Message }
    }
}

function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    return ($s -replace '\\', '\\\\').Replace("'", "''")
}

# ---------- 顶点 ----------
$personRows = Import-Csv (Join-Path $DataDir 'person.csv') -Encoding UTF8
$movieRows = Import-Csv (Join-Path $DataDir 'movie.csv') -Encoding UTF8
Write-Log ("person=" + $personRows.Count + " movie=" + $movieRows.Count)

$batch = 10
for ($i = 0; $i -lt $personRows.Count; $i += $batch) {
    $slice = $personRows[$i..([Math]::Min($i + $batch - 1, $personRows.Count - 1))]
    $parts = $slice | ForEach-Object {
        $born = if ($_.born) { $_.born } else { 'null' }
        "(p" + $_.id + ":person{id:" + $_.id + ",name:'" + (Esc $_.name) + "',born:" + $born + ",country:'" + (Esc $_.country) + "'})"
    }
    $r = Cypher ('CREATE ' + ($parts -join ','))
    if ($r.error) { Write-Log ("PERSON BATCH $i ERROR: " + $r.error) } else { Write-Log "person batch $i ok" }
}

for ($i = 0; $i -lt $movieRows.Count; $i += $batch) {
    $slice = $movieRows[$i..([Math]::Min($i + $batch - 1, $movieRows.Count - 1))]
    $parts = $slice | ForEach-Object {
        "(m" + $_.id + ":movie{id:" + $_.id + ",title:'" + (Esc $_.title) + "',release_year:" + $_.release_year +
        ",rating:" + $_.rating + ",duration:" + $_.duration + ",country:'" + (Esc $_.country) + "'})"
    }
    $r = Cypher ('CREATE ' + ($parts -join ','))
    if ($r.error) { Write-Log ("MOVIE BATCH $i ERROR: " + $r.error) } else { Write-Log "movie batch $i ok" }
}

# ---------- 边 ----------
function Load-Edges([string]$file, [string]$rel) {
    $rows = Import-Csv (Join-Path $DataDir $file) -Encoding UTF8
    $ok = 0; $bad = 0
    foreach ($r in $rows) {
        $stmt = "MATCH (a:person{id:" + $r.src_id + "}),(b:movie{id:" + $r.dst_id + "}) CREATE (a)-[:" + $rel + "]->(b)"
        $res = Cypher $stmt
        if ($res.error) { $bad++ } else { $ok++ }
    }
    Write-Log ("edges " + $rel + " ok=" + $ok + " bad=" + $bad)
}
Load-Edges 'direct.csv' 'direct'
Load-Edges 'acted_in.csv' 'acted_in'
Load-Edges 'produce.csv' 'produce'

# ---------- 校验 ----------
Write-Log '--- counts ---'
foreach ($q in @(
        'MATCH (n) RETURN COUNT(n) AS c',
        'MATCH ()-[r]->() RETURN COUNT(r) AS c',
        'MATCH (n:person) RETURN COUNT(n) AS c',
        'MATCH (n:movie) RETURN COUNT(n) AS c')) {
    $r = Cypher $q
    $v = if ($r.error) { 'ERR' } else { ($r.result | ForEach-Object { $_[0] }) -join ',' }
    Write-Log ($q + '  =>  ' + $v)
}
