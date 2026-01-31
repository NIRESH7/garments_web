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
    outward_date: str
    lot_number: str
    set_no: str
    party_name: str
    vehicle_no: Optional[str]
    in_time: str
    out_time: Optional[str]
    
    items: List[OutwardItemModel]
    
    created_at: datetime = Field(default_factory=datetime.now)
