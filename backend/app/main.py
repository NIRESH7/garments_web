from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List
from .database import db
from .models import LotInwardModel, LotOutwardModel, PartyModel

app = FastAPI(title="Garments ERP API")

# Allow Flutter (Web/Mobile) to access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_db():
    db.connect()

@app.on_event("shutdown")
async def shutdown_db():
    db.close()

# --- Routes ---

@app.get("/")
def read_root():
    return {"status": "online", "system": "Garments ERP Backend"}

# 1. Save Lot Inward
@app.post("/api/inward")
async def create_inward(data: LotInwardModel):
    new_inward = data.dict()
    result = await db.db["lot_inward"].insert_one(new_inward)
    inward_id = str(result.inserted_id)
    
    # --- Auto Allocation Logic ---
    # Convert sticker rows into individual allocation records
    # This allows Lot Outward to find specific sets
    
    allocations = []
    
    # Determine default Rack/Pallet
    # LotInwardModel has lists: racks: [r1, r2, r3], pallets: [p1, p2, p3]
    default_rack = next((r for r in data.racks if r), "Pending")
    default_pallet = next((p for p in data.pallets if p), "Pending")
    
    if data.sticker_dia and data.sticker_rows:
        for row in data.sticker_rows:
            colour = row.colour or "Unknown"
            for idx, weight_str in enumerate(row.set_weights):
                try:
                    w = float(weight_str)
                    if w > 0:
                        allocations.append({
                            "inward_id": inward_id,
                            "lot_number": data.lot_number,
                            "dia": data.sticker_dia,
                            "colour": colour,
                            "set_number": f"Set-{idx + 1}",
                            "weight": w,
                            "pallet_number": default_pallet,
                            "rack_name": default_rack,
                            "created_at": datetime.now().isoformat()
                        })
                except (ValueError, TypeError):
                    continue
                    
    if allocations:
        await db.db["inward_sets_allocation"].insert_many(allocations)
        
    return {"id": inward_id, "message": "Inward & Allocations Saved Successfully"}

@app.get("/api/inward")
async def get_inwards():
    inwards = await db.db["lot_inward"].find().to_list(100)
    # Convert ObjectId to str
    for i in inwards:
        i["_id"] = str(i["_id"])
    return inwards

# 2. Save Lot Outward
@app.post("/api/outward")
async def create_outward(data: LotOutwardModel):
    new_outward = data.dict()
    result = await db.db["lot_outward"].insert_one(new_outward)
    return {"id": str(result.inserted_id), "message": "Outward Saved Successfully"}

# 3. Master Data (Dynamic)
@app.get("/api/master-data")
async def get_master_data():
    # Fetch distinct values from relevant collections
    # optimised to run concurrently if needed, but sequential is fine for now
    
    lots = await db.db["lot_inward"].distinct("lot_number")
    parties = await db.db["parties"].distinct("name")
    
    # For now, keeping some static if no better source, or fetch from dropdown collection if exists
    # The requirement implies these are master data. 
    # Let's assume there is a 'dropdowns' collection or we fetch distinct from usage.
    # For a robust system, we should have a 'masters' collection. 
    # But based on current file structure, we will fetch distinct usage for now 
    # and keep defaults for things not yet in DB.
    
    # Actually, the user has a 'dropdowns' table in SQLite. 
    # We should probably migrate that or just use distinct values from transactions + some defaults.
    
    dias = await db.db["lot_inward"].distinct("grid_rows.dia")
    if not dias: dias = ["30", "32", "34", "36"] # Fallback
    
    colours = await db.db["items"].distinct("colour")
    if not colours: colours = ["Red", "Blue", "Black", "White", "Green"] # Fallback
    
    racks = await db.db["inward_sets_allocation"].distinct("rack_name")
    if not racks: racks = ["R-1", "R-2", "R-3"]
    
    pallets = await db.db["inward_sets_allocation"].distinct("pallet_number")
    if not pallets: pallets = ["P-1", "P-2", "P-3"]

    return {
        "lots": lots,
        "parties": parties,
        "dias": dias,
        "colours": colours,
        "racks": racks,
        "pallets": pallets
    }

# 4. Item Master
@app.post("/api/items")
async def create_items(items: List[dict]):
    if not items:
        raise HTTPException(status_code=400, detail="No items provided")
    
    result = await db.db["items"].insert_many(items)
    return {"inserted_count": len(result.inserted_ids), "message": "Items Saved Successfully"}

@app.get("/api/items/colours")
async def get_colours_by_lot(lot_name: str):
    # Fetch distinct colours for the given lot_name from items collection
    colours = await db.db["items"].find({"lot_name": lot_name}).distinct("colour")
    return {"colours": colours if colours else []}

# 5. Inward Allocation
@app.post("/api/inward/allocation")
async def create_allocation(allocations: List[dict]):
    if not allocations:
        raise HTTPException(status_code=400, detail="No allocation data provided")
    
    result = await db.db["inward_sets_allocation"].insert_many(allocations)
    return {"inserted_count": len(result.inserted_ids), "message": "Allocation Saved Successfully"}

# 6. DC Auto-Generator
@app.get("/api/generate-dc-number")
async def generate_dc_number():
    from datetime import datetime
    
    # Get current financial year (Apr-Mar)
    now = datetime.now()
    if now.month >= 4:  # April onwards
        fy_start = now.year
        fy_end = now.year + 1
    else:
        fy_start = now.year - 1
        fy_end = now.year
    
    fy_prefix = f"EX-{str(fy_start)[-2:]}-{str(fy_end)[-2:]}" # Changed format to EX-YY-YY
    
    # Find max DC number for this FY
    existing_dcs = await db.db["lot_outward"].find(
        {"dc_number": {"$regex": f"^{fy_prefix}/"}}
    ).to_list(1000)
    
    if existing_dcs:
        # Extract numbers and find max
        nums = []
        for dc in existing_dcs:
            try:
                nums.append(int(dc["dc_number"].split("/")[1]))
            except (IndexError, ValueError):
                continue
        new_num = max(nums) + 1 if nums else 1
    else:
        new_num = 1
    
    dc_number = f"{fy_prefix}/{str(new_num).zfill(5)}"
    return {"dc_number": dc_number}

# 7. FIFO Lot Numbers (Filtered by DIA if provided)
@app.get("/api/lots/fifo")
async def get_lots_fifo(dia: str = None):
    query = {}
    if dia:
        query["grid_rows.dia"] = dia
        
    lots = await db.db["lot_inward"].find(query).sort("created_at", 1).to_list(100)
    # Return unique lot numbers in FIFO order
    seen = set()
    lot_numbers = []
    for lot in lots:
        ln = lot.get("lot_number")
        if ln and ln not in seen:
            lot_numbers.append(ln)
            seen.add(ln)
    return {"lots": lot_numbers}

# 8. Party Management
@app.post("/api/parties")
async def create_party(party: PartyModel):
    # Check for existing
    existing = await db.db["parties"].find_one({"name": party.name})
    if existing:
         raise HTTPException(status_code=400, detail="Party name already exists")
         
    new_party = party.dict()
    result = await db.db["parties"].insert_one(new_party)
    return {"id": str(result.inserted_id), "message": "Party Saved Successfully"}

@app.get("/api/parties/{name}")
async def get_party_details(name: str):
    party = await db.db["parties"].find_one({"name": name})
    if party:
        return {
            "name": party.get("name"),
            "process": party.get("process"),
            "address": party.get("address")
        }
    else:
        # Fallback for now if not found (or return 404)
        return {
            "name": name,
            "process": "", # Empty if not found
            "address": ""
        }

# 9. Balanced Sets
@app.get("/api/lots/{lot_number}/dias/{dia}/sets/balance")
async def get_balanced_sets(lot_number: str, dia: str):
    # 1. Get all Inward Sets for this Lot & DIA
    inward_allocations = await db.db["inward_sets_allocation"].find({
        "lot_number": lot_number, # Assuming lot_number is stored in allocation
        "dia": dia
    }).to_list(1000)
    
    # If lot_number wasn't in allocation, we might need to find inwardId first
    if not inward_allocations:
        inward_header = await db.db["lot_inward"].find_one({"lot_number": lot_number})
        if inward_header:
            inward_id = str(inward_header["_id"])
            inward_allocations = await db.db["inward_sets_allocation"].find({
                "inward_id": inward_id,
                "dia": dia
            }).to_list(1000)

    # 2. Get all Outward Sets for this Lot & DIA
    outward_docs = await db.db["lot_outward"].find({
        "lot_number": lot_number,
        "dia": dia
    }).to_list(1000)
    
    outward_weights = {} # (set_no, colour) -> total_outward_weight
    for doc in outward_docs:
        for item in doc.get("items", []):
            key = (doc.get("set_no"), item.get("colour"))
            outward_weights[key] = outward_weights.get(key, 0) + item.get("selected_weight", 0)

    # 3. Calculate Balance
    balance_sets = []
    for alloc in inward_allocations:
        set_no = alloc.get("set_number")
        colour = alloc.get("colour")
        in_weight = alloc.get("weight", 0)
        out_weight = outward_weights.get((set_no, colour), 0)
        
        balance = in_weight - out_weight
        if balance > 0:
            balance_sets.append({
                "set_no": set_no,
                "colour": colour,
                "weight": balance,
                "original_weight": in_weight
            })
            
    return {"sets": balance_sets}

# 8. PDF Generation for DC Print
@app.post("/api/generate-dc-print")
async def generate_dc_print(data: dict):
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from io import BytesIO
    from fastapi.responses import StreamingResponse
    
    # Create PDF in memory
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4)
    elements = []
    styles = getSampleStyleSheet()
    
    # Title
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=16,
        textColor=colors.HexColor('#000000'),
        spaceAfter=12,
        alignment=1  # Center
    )
    elements.append(Paragraph("DELIVERY CHALLAN", title_style))
    elements.append(Spacer(1, 0.2*inch))
    
    # DC Number and Date
    info_data = [
        ["DC No:", data.get("dc_number", ""), "Date:", data.get("date", "")],
        ["Party Name:", data.get("party_name", ""), "Lot No:", data.get("lot_number", "")],
    ]
    info_table = Table(info_data, colWidths=[1.5*inch, 2*inch, 1.5*inch, 2*inch])
    info_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('TEXTCOLOR', (0, 0), (0, -1), colors.grey),
        ('TEXTCOLOR', (2, 0), (2, -1), colors.grey),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
    ]))
    elements.append(info_table)
    elements.append(Spacer(1, 0.3*inch))
    
    # Weights Table
    # Requirement: Group by Colour, show multiple weights in columns (Weight 1, Weight 2)
    # Header: S.NO, COLOUR NAME, WEIGHT 1, WEIGHT 2, TOTAL WEIGHT
    table_data = [["S.NO", "COLOUR NAME", "WEIGHT 1", "WEIGHT 2", "TOTAL WEIGHT"]]
    
    items = data.get("items", [])
    grouped_items = {} 
    
    # Group by colour
    for item in items:
        colour = item.get("colour", "Unknown")
        weight = item.get("selected_weight", 0)
        if colour not in grouped_items:
            grouped_items[colour] = []
        grouped_items[colour].append(weight)
        
    idx = 1
    for colour, weights in grouped_items.items():
        # logic to handle more than 2 weights? Packet them in chunks of 2?
        # For now, let's just take first two or list them. Requirement implies 2 columns.
        # If > 2 weights, we might need multiple rows or comma separated. 
        # Simpler approach: List up to 2 specific weights, sum the rest? 
        # Or just fill W1, W2. If 3rd exists, add to W2 or ignore?
        # Better: Create multiple rows if > 2 weights? 
        # Let's just fill W1 and W2. If there are more, we add a new row for same colour?
        # Actually, let's just show first 2. If list has 1, W2 is empty.
        
        # Iterate in chunks of 2 to support any number of weights
        for i in range(0, len(weights), 2):
            chunk = weights[i:i+2]
            w1 = chunk[0]
            w2 = chunk[1] if len(chunk) > 1 else 0
            
            # If it's a continuation row (i > 0), maybe don't show S.No/Colour again? 
            # But straightforward is fine.
            
            total_chunk = sum(chunk)
            
            # If it's the first chunk, show Colour. Else empty string for clean look?
            disp_colour = colour if i == 0 else ""
            disp_sno = str(idx) if i == 0 else ""
            
            table_data.append([
                disp_sno,
                disp_colour,
                str(w1),
                str(w2) if w2 != 0 else "", # Empty if 0
                str(total_chunk)
            ])
            
        idx += 1
    
    weights_table = Table(table_data, colWidths=[0.7*inch, 2*inch, 1.5*inch, 1.5*inch, 1.5*inch])
    weights_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 11),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 9),
    ]))
    elements.append(weights_table)
    elements.append(Spacer(1, 0.5*inch))
    
    # Footer signatures
    footer_data = [
        ["CHECKED BY: ______________", "RECEIVED BY: ______________", "AUTHORIZED SIGN: ______________"]
    ]
    footer_table = Table(footer_data, colWidths=[2.5*inch, 2.5*inch, 2.5*inch])
    footer_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
    ]))
    elements.append(footer_table)
    
    # Build PDF
    doc.build(elements)
    buffer.seek(0)
    
    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=DC_{data.get('dc_number', 'print')}.pdf"}
    )
