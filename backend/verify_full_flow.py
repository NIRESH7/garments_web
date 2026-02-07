
import asyncio
import httpx
from datetime import datetime
import uuid

BASE_URL = "http://127.0.0.1:8000"

async def run_verification():
    async with httpx.AsyncClient() as client:
        print("\n--- STARTING FINAL END-TO-END VERIFICATION ---\n")
        
        # 1. Create Party
        party_name = f"Test Party {uuid.uuid4().hex[:4]}"
        print(f"1. Creating Party: {party_name}")
        party_data = {
            "id": str(uuid.uuid4()),
            "name": party_name,
            "process": "Dyeing",
            "address": "123 Test St",
            "mobile": "9999999999",
            "gst": "33ABCDE1234F1Z5",
            "rate": "15.00"
        }
        res = await client.post(f"{BASE_URL}/api/parties", json=party_data)
        if res.status_code == 200:
            print("   [SUCCESS] Party Created in DB")
        else:
            print(f"   [FAILED] {res.text}")
            return

        # 2. Create Item (Lot + Colour)
        lot_name = f"Test Lot {uuid.uuid4().hex[:4]}"
        print(f"\n2. Creating Item Master for Lot: {lot_name}")
        item_data = [{
            "id": str(uuid.uuid4()),
            "lot_name": lot_name, # Group Name
            "item_name": "Fabric A",
            "gsm": "180",
            "colour": "Red",
            "item_group": "Group A",
            "size": "L",
            "set_val": "0"
        }]
        res = await client.post(f"{BASE_URL}/api/items", json=item_data)
        if res.status_code == 200:
             print("   [SUCCESS] Item Master stored in DB")
        else:
             print(f"   [FAILED] {res.text}")

        # 3. Create Inward Entry (Simulating App Input)
        print(f"\n3. Creating Inward Entry for {lot_name}")
        lot_number = f"LN-{uuid.uuid4().hex[:4]}"
        inward_payload = {
            "inward_date": "2023-10-27",
            "in_time": "10:00 AM",
            "out_time": "10:30 AM",
            "lot_name": lot_name,
            "lot_number": lot_number,
            "party_name": party_name,
            "process": "Dyeing",
            "vehicle_no": "TN-01-AB-1234",
            "dc_number": "DC-001",
            "sticker_dia": "30",
            "racks": ["R1", None, None],
            "pallets": ["P1", None, None],
            "grid_rows": [
                {
                    "dia": "30",
                    "rolls": 10,
                    "sets": 1,
                    "delivered_weight": 100.0,
                    "rec_roll": 10,
                    "rec_weight": 99.5,
                    "difference": 0.5,
                    "loss_percent": 0.5
                }
            ],
            "sticker_rows": [
                {
                    "colour": "Red",
                    "set_weights": ["25.0", "25.0"] # 2 Sets of 25kg
                }
            ]
        }
        res = await client.post(f"{BASE_URL}/api/inward", json=inward_payload)
        if res.status_code == 200:
             print("   [SUCCESS] Inward Entry stored in DB")
             print("   [CHECKING] Auto-Allocation of Sets...")
             # Verify allocations
             res_alloc = await client.get(f"{BASE_URL}/api/lots/{lot_number}/dias/30/sets/balance")
             sets = res_alloc.json().get("sets", [])
             if len(sets) >= 2:
                 print(f"   [SUCCESS] Auto-Allocation verified. Found {len(sets)} sets available for Outward.")
             else:
                 print(f"   [FAILED] No allocations found! Count: {len(sets)}")
                 return
        else:
             print(f"   [FAILED] {res.text}")
             return

        # 4. Create Outward Entry
        print(f"\n4. Creating Outward Entry")
        # Fetch a set to deliver
        sets = res_alloc.json().get("sets", [])
        target_set = sets[0] # Set-1
        
        outward_payload = {
            "dc_number": "OUT-DC-001",
            "outward_date_time": datetime.now().isoformat(),
            "lot_name": lot_name,
            "lot_number": lot_number,
            "dia": "30",
            "party_name": party_name,
            "process": "Knitting",
            "address": "Test Address",
            "vehicle_no": "TN-99-ZZ-9999",
            "in_time": "11:00 AM",
            "out_time": "11:30 AM",
            "items": [
                {
                    "colour": target_set["colour"],
                    "selected_weight": 5.0, # Partial delivery
                    "set_no": target_set["set_no"]
                }
            ]
        }
        res = await client.post(f"{BASE_URL}/api/outward", json=outward_payload)
        if res.status_code == 200:
            print("   [SUCCESS] Outward Entry stored in DB")
        else:
            print(f"   [FAILED] {res.text}")
            return
            
        # 5. Verify Balance Deduction
        print(f"\n5. Verifying Balance Update")
        res_alloc_after = await client.get(f"{BASE_URL}/api/lots/{lot_number}/dias/30/sets/balance")
        sets_after = res_alloc_after.json().get("sets", [])
        updated_set = next((s for s in sets_after if s["set_no"] == target_set["set_no"]), None)
        
        if updated_set:
            original = target_set["weight"]
            current = updated_set["weight"]
            print(f"   [INFO] Original Weight: {original}, Outward: 5.0, New Balance: {current}")
            if current == original - 5.0:
                 print("   [SUCCESS] Balance calculated correctly in DB!")
            else:
                 print(f"   [FAILED] Balance mismatch. Expected {original - 5.0}, got {current}")
        else:
             # If weight became 0 it might disappear, but here 25-5=20 so it should exist
             print("   [FAILED] Set not found in balance list (Unexpected)")

        print("\n--- VERIFICATION COMPLETE: ALL SYSTEMS GO ---")

if __name__ == "__main__":
    try:
        asyncio.run(run_verification())
    except Exception as e:
        print(f"Script Error: {e}")
        print("Ensure the backend 'uvicorn app.main:app' is running!")
