from pydantic import BaseModel

class UserBase(BaseModel):
    username: str
    age: int
    nationality: str

class UserCreate(UserBase):
    pass

class UserUpdate(UserBase):
    pass

class UserOut(UserBase):
    id: int

    class Config:
        orm_mode = True
