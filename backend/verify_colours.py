import requests

BASE_URL = "http://localhost:5001/api/inventory"

def test_get_colours(lot_no):
    print(f"Testing getInwardColours for Lot No: {lot_no}")
    
    # Needs auth token. Let's assume we can get one or just test if endpoint exists (401 is fine if auth works, but we want 200).
    # For quick test, I'll skip auth if I don't have it easily. 
    # But wait, local backend requires auth.
    
    # Let's try to login first.
    auth_url = "http://localhost:5001/api/auth/login"
    login_payload = {"email": "garments1@gmail.com", "password": "Admin@123"}
    
    try:
        session = requests.Session()
        login_resp = session.post(auth_url, json=login_payload)
        if login_resp.status_code == 200:
            token = login_resp.json()['token']
            headers = {'Authorization': f'Bearer {token}'}
            
            # Fetch Inwards to debug
            print(f"Fetching ALL Inwards to find lot {lot_no}...")
            inward_resp = session.get(f"{BASE_URL}/inward", headers=headers)
            if inward_resp.status_code == 200:
                inwards = inward_resp.json()
                print(f"Found {len(inwards)} total inwards.")
                found = False
                for i in inwards:
                    if i.get('lotNo') == lot_no:
                        print(f"Found EXACT match for {lot_no}")
                        found = True
                        if 'storageDetails' in i:
                            print("StorageDetails:", i['storageDetails'])
                    elif lot_no in i.get('lotNo', ''):
                        print(f"Found PARTIAL match: {i.get('lotNo')}")
                
                if not found:
                    print("Available Lot Nos:", [i.get('lotNo') for i in inwards])
            else:
                print(f"Failed to fetch inwards: {inward_resp.status_code}")
        else:
            print(f"Login failed: {login_resp.status_code}")
            print(login_resp.text[:200])

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Test with a known lot no, e.g. "2526/102" from user screenshot context
    test_get_colours("2526/102")
