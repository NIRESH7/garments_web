import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:8000"

def test_dc_generation():
    print("Testing DC Generation...")
    response = requests.get(f"{BASE_URL}/api/generate-dc-number")
    if response.status_code == 200:
        dc = response.json().get("dc_number")
        print(f"Generated DC: {dc}")
        assert dc.startswith("EX-")
        assert "/" in dc
    else:
        print(f"Failed to generate DC: {response.text}")

def test_party_details():
    print("Testing Party Details...")
    party_name = "Mock Party"
    response = requests.get(f"{BASE_URL}/api/parties/{party_name}")
    if response.status_code == 200:
        details = response.json()
        print(f"Party Details: {details}")
        assert details["name"] == party_name
        assert "process" in details
        assert "address" in details
    else:
        print(f"Failed to fetch party details: {response.text}")

if __name__ == "__main__":
    test_dc_generation()
    test_party_details()
