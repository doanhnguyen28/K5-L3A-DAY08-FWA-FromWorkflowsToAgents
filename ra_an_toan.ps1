# Rà an toàn CP4 cho 3 shape: workflow, single, orchestrator
# Chạy trong thư mục src/:  powershell -ExecutionPolicy Bypass -File ..\ra_an_toan.ps1

$ErrorActionPreference = "Stop"

# 1. Sinh trace mới
Remove-Item -Recurse -Force traces -ErrorAction SilentlyContinue
python -m pytest -q -m student -o addopts=
if ($LASTEXITCODE -ne 0) { Write-Host "pytest FAIL" -ForegroundColor Red; exit 1 }

# 2. Danh sách chuỗi cấm: secret + SĐT, địa chỉ, tên hàng, internal_note của mọi order
$patterns = @("CANARY_SECRET", "parent_secret", "raw_headers", "internal_note", "Bearer ")
$world = Get-Content data\public_world_state.json -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($o in $world.orders) {
    $patterns += "$($o.phone)", "$($o.address)", "$($o.item_name)", "$($o.internal_note)"
}
$patterns = $patterns | Where-Object { $_ -ne "" } | Sort-Object -Unique

# 3. Quét trace của 3 shape
$files = Get-ChildItem traces -File | Where-Object { $_.Name -match '^R-(workflow|single|orchestrator)-' }
Write-Host "So file trace quet: $($files.Count)"
$leaks = $files | Select-String -SimpleMatch -Pattern $patterns -Encoding UTF8

if ($leaks) {
    Write-Host "LO SECRET/PII:" -ForegroundColor Red
    $leaks | ForEach-Object { "{0}:{1}  ->  {2}" -f $_.Filename, $_.LineNumber, $_.Pattern }
} else {
    Write-Host "Trace sach: 0 file vi pham" -ForegroundColor Green
}

# 4. Kiểm tra không có print() trong 3 file shape
$shapes = "lab8\shapes\workflow.py", "lab8\shapes\single.py", "lab8\shapes\orchestrator.py"
$prints = Select-String -Path $shapes -Pattern '\bprint\(' -Encoding UTF8
if ($prints) {
    Write-Host "Co print():" -ForegroundColor Red
    $prints | ForEach-Object { "{0}:{1}  {2}" -f $_.Filename, $_.LineNumber, $_.Line.Trim() }
} else {
    Write-Host "Khong co print() trong 3 shape" -ForegroundColor Green
}

if ($leaks -or $prints) { exit 1 } else { exit 0 }