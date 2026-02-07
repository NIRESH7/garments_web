from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

# --- Inward Models ---

class StickerRowModel(BaseModel):
    colour: Optional[str]
    set_weights: List[str] = [] # Keeping as string to match frontend text controllers, or float? Frontend sends strings.

class InwardRowModel(BaseModel):
    dia: str
    rolls: int
    sets: int
    delivered_weight: float
    rec_roll: int
    rec_weight: float
    difference: float
    loss_percent: float

class LotInwardModel(BaseModel):
    inward_date: str
    in_time: str
    out_time: Optional[str]
    
    lot_name: Optional[str]
    lot_number: Optional[str]
    party_name: Optional[str]
    process: Optional[str]
    vehicle_no: Optional[str]
    dc_number: Optional[str]
    
    # Grids
    grid_rows: List[InwardRowModel]
    
    # Stickers
    sticker_rows: List[StickerRowModel]
    sticker_dia: Optional[str]
    racks: List[Optional[str]]
    pallets: List[Optional[str]]
    
    created_at: datetime = Field(default_factory=datetime.now)

# --- Outward Models ---

class OutwardItemModel(BaseModel):
    colour: str
    selected_weight: float

class LotOutwardModel(BaseModel):
    dc_number: str
    outward_date_time: str # Combined date and time
    lot_name: str
    lot_number: str
    dia: str
    party_name: str
    process: Optional[str]
    address: Optional[str]
    vehicle_no: Optional[str]
    in_time: str
    out_time: Optional[str]
    
    items: List[OutwardItemModel] # Represents selected sets/colours
    
    created_at: datetime = Field(default_factory=datetime.now)

# --- Item Master Models ---

class ItemModel(BaseModel):
    id: str
    lot_name: Optional[str] = Field(alias="group_name") # Mapping 'lot_name' (db col) to 'group_name' concept if needed, or just keeping 'lot_name'
    item_name: str
    gsm: Optional[str]
    colour: str
    item_group: Optional[str]
    size: Optional[str]
    set_val: Optional[str]
    
    class Config:
        allow_population_by_field_name = True

# --- Inward Allocation Models ---

class AllocationSetModel(BaseModel):
    inward_id: str
    lot_number: str # Added for faster lookup
    dia: str
    colour: str
    set_number: str
    weight: float
    pallet_number: str
    rack_name: str
    created_at: Optional[str]

# --- Party Master Models ---

class PartyModel(BaseModel):
    id: str
    name: str # Party Name
    address: Optional[str]
    mobile: Optional[str]
    gst: Optional[str]
    rate: Optional[str] # Keeping as string to match frontend
    process: str # The default process
    
    created_at: datetime = Field(default_factory=datetime.now) 
