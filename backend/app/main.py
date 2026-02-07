from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List
from .database import db
from .models import LotInwardModel, LotOutwardModel

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
    return {"id": str(result.inserted_id), "message": "Inward Saved Successfully"}

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

# 3. Master Data (Mock)
@app.get("/api/master-data")
async def get_master_data():
    return {
        "lots": ["Lot Alpha", "Lot Beta", "Lot Gamma"],
        "parties": ["Client A", "Client B", "Client C"],
        "dias": ["30", "32", "34", "36"],
        "colours": ["Red", "Blue", "Black", "White", "Green"],
        "racks": ["R-1", "R-2", "R-3"],
        "pallets": ["P-1", "P-2", "P-3"]
    }

# 4. Item Master
@app.post("/api/items")
async def create_items(items: List[dict]):
    if not items:
        raise HTTPException(status_code=400, detail="No items provided")
    
    result = await db.db["items"].insert_many(items)
    return {"inserted_count": len(result.inserted_ids), "message": "Items Saved Successfully"}

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

# 8. Party Details
@app.get("/api/parties/{name}")
async def get_party_details(name: str):
    # This is mock data, ideally fetch from a 'parties' collection
    # The requirement says Process & Address automatic according to party name
    return {
        "name": name,
        "process": "Dyeing & Finishing",
        "address": "123 Textile Park, Erode, Tamil Nadu"
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
    table_data = [["S.NO", "COLOUR NAME", "WEIGHT 1", "WEIGHT 2", "TOTAL WEIGHT"]]
    
    items = data.get("items", [])
    for idx, item in enumerate(items, 1):
        w1 = item.get("weight1", 0)
        w2 = item.get("weight2", 0)
        total = w1 + w2
        table_data.append([
            str(idx),
            item.get("colour", ""),
            str(w1),
            str(w2),
            str(total)
        ])
    
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
