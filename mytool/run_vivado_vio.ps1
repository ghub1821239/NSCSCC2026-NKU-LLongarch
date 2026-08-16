$ErrorActionPreference = "Stop"

$vivadoRunDir = "D:\chiplab\fpga\nscscc-team\run_vivado"
$resultDir = Join-Path $vivadoRunDir "result"

if (-not (Test-Path -LiteralPath $vivadoRunDir -PathType Container)) {
    throw "Vivado run directory does not exist: $vivadoRunDir"
}

New-Item -ItemType Directory -Force -Path $resultDir | Out-Null

$vivadoExitCode = 0
Push-Location -LiteralPath $resultDir
try {
    & vivado `
        -mode tcl `
        -source "..\vio.tcl" `
        -tclargs `
        "..\project\loongson.runs\impl_1\soc_top.bit" `
        "..\project\loongson.runs\impl_1\soc_top.ltx" `
        "perf"

    $vivadoExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($vivadoExitCode -ne 0) {
    exit $vivadoExitCode
}
