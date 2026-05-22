import aiosqlite

DB_PATH = "relay.db"


async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT UNIQUE NOT NULL,
                hashed_password TEXT NOT NULL
            )
        """)
        await db.commit()


async def get_user_by_email(email: str):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(
            "SELECT id, email, hashed_password FROM users WHERE email = ?", (email,)
        ) as cursor:
            row = await cursor.fetchone()
            if row:
                return {"id": row[0], "email": row[1], "hashed_password": row[2]}
            return None


async def create_user(email: str, hashed_password: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO users (email, hashed_password) VALUES (?, ?)",
            (email, hashed_password)
        )
        await db.commit()
