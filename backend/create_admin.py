
import asyncio
from app.database import db
from passlib.context import CryptContext
from datetime import datetime

# Password Context
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

async def create_admin():
    # Connect to DB
    db.connect()
    
    email = "garments1@gmail.com"
    password = "Admin@123"
    hashed_password = pwd_context.hash(password)
    
    user_data = {
        "email": email,
        "password": hashed_password,
        "role": "admin",
        "created_at": datetime.now()
    }
    
    # Check if user exists
    existing_user = await db.db["users"].find_one({"email": email})
    
    if existing_user:
        print(f"User {email} already exists. Updating password...")
        await db.db["users"].update_one(
            {"email": email},
            {"$set": {"password": hashed_password, "role": "admin"}}
        )
        print("Password updated successfully.")
    else:
        print(f"Creating user {email}...")
        await db.db["users"].insert_one(user_data)
        print("User created successfully.")

    db.close()

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(create_admin())
