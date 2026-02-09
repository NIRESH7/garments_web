$ErrorActionPreference = "Stop"

$baseUrl = "http://127.0.0.1:5001/api"
$email = "garments@gmail.com"
$password = "Admin@123"

# 1. Login
Write-Host "1. Logging in..."
$loginBody = @{
    email = $email
    password = $password
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.access_token
    Write-Host "Login Successful. Token: $token"
} catch {
    Write-Error "Login Failed: $_"
    exit 1
}

$headers = @{
    Authorization = "Bearer $token"
}

# 2. Create Item Group
Write-Host "2. Creating Item Group..."
$itemGroupBody = @{
    groupName = "API Test Group"
    itemNames = @("T-Shirt", "Polo")
    gsm = "180"
    colours = @("Red", "Blue")
} | ConvertTo-Json

try {
    $groupResponse = Invoke-RestMethod -Uri "$baseUrl/master/item-groups" -Method Post -Body $itemGroupBody -ContentType "application/json" -Headers $headers
    Write-Host "Item Group Created: $($groupResponse.message)"
} catch {
    Write-Error "Create Item Group Failed: $_"
    exit 1
}

# 3. Create Lot Inward (New Structure)
Write-Host "3. Creating Lot Inward..."
$inwardDate = Get-Date -Format "yyyy-MM-dd"
$inwardBody = @{
    inwardDate = $inwardDate
    inTime = "10:00 AM"
    outTime = "11:00 AM"
    lotName = "API Test Group"
    lotNo = "LOT-999"
    fromParty = "Test Party"
    process = "Dyeing"
    vehicleNo = "TN-01-AB-1234"
    partyDcNo = "DC-001"
    diaEntries = @(
        @{
            dia = "30"
            roll = 10
            set = 1
            delWt = 100.0
            recRoll = 10
            recWt = 99.5
        }
    )
    storageDetails = @(
        @{
            dia = "30"
            racks = @("R-1", $null, $null)
            pallets = @("P-1", $null, $null)
            rows = @(
                @{
                    colour = "Red"
                    setWeights = @("10.5")
                }
            )
        }
    )
} | ConvertTo-Json -Depth 10

try {
    $inwardResponse = Invoke-RestMethod -Uri "$baseUrl/inventory/inward" -Method Post -Body $inwardBody -ContentType "application/json" -Headers $headers
    Write-Host "Lot Inward Created: $($inwardResponse.message) (ID: $($inwardResponse.id))"
} catch {
    Write-Error "Create Lot Inward Failed: $_"
    exit 1
}

Write-Host "Verification Complete!"
