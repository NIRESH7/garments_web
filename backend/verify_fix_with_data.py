import requests
import json

BASE_URL = "http://localhost:5001/api"
AUTH_URL = f"{BASE_URL}/auth/login"
INWARD_URL = f"{BASE_URL}/inventory/inward"
COLOURS_URL = f"{BASE_URL}/inventory/inward/colours"

def run_test():
    session = requests.Session()
    
    # 1. Login
    print("Logging in...")
    resp = session.post(AUTH_URL, json={"email": "garments@gmail.com", "password": "Admin@123"})
    if resp.status_code != 200:
        print("Login failed:", resp.text)
        return
    
    token = resp.json()['token']
    headers = {'Authorization': f'Bearer {token}'}
    
    # 2. Create Test Data
    lot_no = "TEST-LOT-MULTI-COLOUR"
    print(f"Creating Inward for {lot_no}...")
    
    inward_data = {
        "inwardDate": "2023-10-27",
        "inTime": "10:00 AM",
        "outTime": "11:00 AM",
        "lotName": "Test Fabric",
        "lotNo": lot_no,
        "fromParty": "Test Party",
        "diaEntries": [
            {"dia": "34", "recRoll": 10, "recWt": 200, "rolls": 10, "weight": 200, "rate": 150}
        ],
        "storageDetails": [
            {
                "dia": "34",
                "rows": [
                    {
                        "colour": "Red",
                        "setWeights": ["20", "20"]
                    },
                    {
                        "colour": "Blue",
                        "setWeights": ["20", "20"]
                    },
                    {
                        "colour": "Green",
                        "setWeights": ["20", "20"]
                    }
                ]
            }
        ]
    }
    
    # Check if exists first to avoid dupes (optional, but good practice)
    # Actually just create new one, duplicate lotNo is allowed in loose schema usually, or we use unique lotNo
    import time
    lot_no = f"TEST-LOT-{int(time.time())}"
    inward_data['lotNo'] = lot_no
    
    resp = session.post(INWARD_URL, json=inward_data, headers=headers)
    if resp.status_code != 201:
        print("Failed to create inward:", resp.text)
        return
    
    print(f"Inward created for {lot_no}")
    
    # 3. Verify Colours
    print("Verifying colours...")
    resp = session.get(COLOURS_URL, params={'lotNo': lot_no}, headers=headers)
    if resp.status_code == 200:
        colours = resp.json()
        print(f"Returned colours: {colours}")
        expected = ["Red", "Blue", "Green"]
        # check if all expected are in colours
        if set(expected).issubset(set(colours)):
             print("SUCCESS: All colours found!")
        else:
             print(f"FAILURE: Expected {expected}, got {colours}")
    else:
        print("Failed to get colours:", resp.status_code, resp.text)

if __name__ == "__main__":
    run_test()
