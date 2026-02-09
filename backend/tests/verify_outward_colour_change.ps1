$ErrorActionPreference = "Stop"
$baseUrl = "http://127.0.0.1:5001/api"
$email = "garments@gmail.com"
$password = "Admin@123"

# 1. Login
Write-Host "1. Logging in..."
$loginBody = @{ email = $email; password = $password } | ConvertTo-Json
$token = (Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json").access_token
$headers = @{ Authorization = "Bearer $token" }

# 2. Create Unique Lot Inward
$rand = Get-Random -Minimum 1000 -Maximum 9999
$lotNo = "LOT-COLOUR-TEST-$rand"
Write-Host "2. Creating Inward for Lot: $lotNo (Set-1: 10kg, Red)"

$inwardBody = @{
    inwardDate = "2026-02-09"
    inTime = "10:00 AM"
    outTime = "11:00 AM" # Added
    lotName = "Test Group"
    lotNo = $lotNo
    fromParty = "Test Party" # Added
    process = "Dyeing" # Added
    vehicleNo = "TN-01-AB-1234" # Added
    partyDcNo = "DC-001" # Added
    diaEntries = @( @{ dia="30"; roll=1; set=1; delWt=10.0; recRoll=1; recWt=10.0 } )
    storageDetails = @(
        @{
            dia = "30"
            racks = @("R-1")
            pallets = @("P-1")
            rows = @( @{ colour="Red"; setWeights=@("10.0") } )
        }
    )
} | ConvertTo-Json -Depth 10

$inwardResponse = Invoke-RestMethod -Uri "$baseUrl/inventory/inward" -Method Post -Body $inwardBody -ContentType "application/json" -Headers $headers
Write-Host "Inward Created."

# 3. Create Outward with DIFFERENT Colour
Write-Host "3. Creating Outward for Set-1 as 'Blue' (4kg)..."
$outwardBody = @{
    lot_number = $lotNo
    dia = "30"
    items = @(
        @{
            set_no = "Set-1"
            colour = "Blue" # Changing color from Red to Blue
            selected_weight = 4.0
        }
    )
    # Metadata
    dc_number = "DC-$rand"
    party_name = "Test Party"
    # Additional required fields
    outward_date_time = "2026-02-09T10:00:00" # Script used date previously
    lot_name = "Test Group"
    process = "Dyeing"
    address = "123 Test St"
    vehicle_no = "TN-01-AB-1234"
    in_time = "10:00 AM"
    out_time = "11:00 AM"
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "$baseUrl/inventory/outward" -Method Post -Body $outwardBody -ContentType "application/json" -Headers $headers
Write-Host "Outward Created."

# 4. Check Balance
Write-Host "4. Checking Balance (Should be 6kg)..."
$balanceResponse = Invoke-RestMethod -Uri "$baseUrl/inventory/inward/balanced-sets?lotNo=$lotNo&dia=30" -Method Get -Headers $headers
$set1 = $balanceResponse.sets | Where-Object { $_.set_no -eq "Set-1" }

if ($set1) {
    Write-Host "Set-1 Found. Weight: $($set1.weight) kg (Expected: 6)"
    if ($set1.weight -eq 6) {
        Write-Host "SUCCESS: Balance is correct implies backend ignored the color change mismatch." -ForegroundColor Green
    } else {
        Write-Error "FAILURE: Balance is $($set1.weight)."
    }
} else {
    Write-Error "FAILURE: Set-1 not found in balance (maybe fully consumed?)"
}
