# src/main.py
from fastapi import FastAPI

# 创建 FastAPI 应用实例
app = FastAPI()

# 定义一个根路由
@app.get("/")
def read_root():
    return {"message": "Hello, FastAPI running inside Docker!"}

    # 定义一个根路由
@app.get("/health")
def read_health():
    return {"message": "Hello, I'm healthy!"}

@app.get("/ready")
def read_health():
    return {"message": "Hello, I'm healthy!"}

# 定义一个带参数的路由
@app.get("/items/{item_id}")
def read_item(item_id: int, q: str | None = None):
    return {"item_id": item_id, "q": q}
