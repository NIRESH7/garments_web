from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List
from .database importdb
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
