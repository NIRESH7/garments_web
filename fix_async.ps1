$file = 'lib\screens\transactions\lot_outward_screen.dart'
$lines = Get-Content $file
$out = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $lines.Count; $i++) {
    # Skip line index 452 (line 453 in 1-based) - the stray extra closing brace
    # It comes right after "  }" (the _onLotNoChanged closing), before the blank line
    if ($i -eq 452) {
        Write-Host "Skipping stray brace at line 453: '$($lines[$i])'"
        continue
    }
    $out.Add($lines[$i])
}

Set-Content $file -Value $out -Encoding UTF8
Write-Host "Done. Total lines: $($out.Count)"
