import os
from motor.motor_asyncio import AsyncIOMotorClient

# Default to local mongo if not env var
MONGO_URL = os.getenv("MONGO_URL", "mongodb+srv://deepaks24062000_db_user:deepak%4024@cluster0.ffresp2.mongodb.net/garments_mobile")
DB_NAME = "garments_mobile"

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
