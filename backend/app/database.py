import os
from motor.motor_asyncio import AsyncIOMotorClient

# Default to local mongo if not env var
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
DB_NAME = "garments_erp"

class Database:
    client: AsyncIOMotorClient = None
    db = None

    def connect(self):
        self.client = AsyncIOMotorClient(MONGO_URL)
        self.db = self.client[DB_NAME]
        print(f"Connected to MongoDB: {DB_NAME}")

    def close(self):
        self.client.close()

db = Database()
