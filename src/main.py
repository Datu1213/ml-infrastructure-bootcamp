# src/main.py
import joblib
import numpy as np
from fastapi import FastAPI
from pydantic import BaseModel
import time

app = FastAPI(title="ML Model Serving API")

# 加载模型 (在应用启动时)
try:
    model = joblib.load('model.joblib')
    print("Model loaded successfully.")
except FileNotFoundError:
    model = None
    print("Model file not found. /predict endpoint will not work.")

# 定义预测请求的数据模型
class IrisFeatures(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float

# --- Endpoints ---

@app.get("/")
def read_root():
    return {"message": "Welcome to the ML Model Serving API"}

@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {"status": "ok", "timestamp": time.time()}

@app.post("/predict")
def predict(features: IrisFeatures):
    """Endpoint to make predictions."""
    if model is None:
        return {"error": "Model is not loaded."}

    # 将输入数据转换为numpy数组
    prediction_data = np.array([[
        features.sepal_length,
        features.sepal_width,
        features.petal_length,
        features.petal_width
    ]])

    # 进行预测
    prediction = model.predict(prediction_data)
    
    # 返回预测结果
    return {"prediction": int(prediction[0])}