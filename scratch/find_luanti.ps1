$file = "bin\Terrixa.exe"
$bytes = [System.IO.File]::ReadAllBytes($file)
$search = [System.Text.Encoding]::ASCII.GetBytes("Luanti")
$found = 0

for ($i = 0; $i -le $bytes.Length - $search.Length; $i++) {
    $match = $true
    for ($j = 0; $j -lt $search.Length; $j++) {
        if ($bytes[$i + $j] -ne $search[$j]) {
            $match = $false
            break
        }
    }
    if ($match) {
        $found++
        Write-Host "Found Luanti at offset: $i"
        # Check surrounding bytes
        $context = $bytes[($i-5)..($i+10)]
        $hex = ($context | ForEach-Object { $_.ToString("X2") }) -join " "
        Write-Host "Context (Hex): $hex"
        if ($found -ge 20) { break }
    }
}
