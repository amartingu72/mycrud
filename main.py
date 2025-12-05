from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base, sessionmaker
import os
# Database configuration

db_host = os.getenv("DB_HOST")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_name = os.getenv("DB_NAME")

DATABASE_URL = "postgresql://{}:{}@{}/{}".format(db_user,db_password,db_host,db_name)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

# SQLAlchemy model
class User(Base):
    __tablename__ = "users"
    username = Column(String, primary_key=True, index=True)
    age = Column(Integer)

# Create the table
Base.metadata.create_all(bind=engine)

# Pydantic schemas
class UserCreate(BaseModel):
    username: str
    age: int

class UserUpdate(BaseModel):
    age: int

# FastAPI app
app = FastAPI()

@app.post("/users/", response_model=UserCreate)
def create_user(user: UserCreate):
    db = SessionLocal()
    if db.query(User).filter(User.username == user.username).first():
        db.close()
        raise HTTPException(status_code=400, detail="Username already exists")
    new_user = User(username=user.username, age=user.age)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    db.close()
    return new_user

@app.get("/users/", response_model=List[UserCreate])
def read_users():
    db = SessionLocal()
    users = db.query(User).all()
    db.close()
    return users

@app.get("/users/{username}", response_model=UserCreate)
def read_user(username: str):
    db = SessionLocal()
    user = db.query(User).filter(User.username == username).first()
    db.close()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.put("/users/{username}", response_model=UserCreate)
def update_user(username: str, user_update: UserUpdate):
    db = SessionLocal()
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")
    user.age = user_update.age
    db.commit()
    db.refresh(user)
    db.close()
    return user

@app.delete("/users/{username}")
def delete_user(username: str):
    db = SessionLocal()
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    db.close()
    return {"detail": "User deleted"}