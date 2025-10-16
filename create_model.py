# create_model.py
import joblib
from sklearn.linear_model import LogisticRegression
from sklearn.datasets import load_iris

print("Training a simple model...")

# 加载数据并训练一个简单的逻辑回归模型
X, y = load_iris(return_X_y=True)
model = LogisticRegression(max_iter=200)
model.fit(X, y)

# 保存模型到文件
joblib.dump(model, 'model.joblib')

print("Model trained and saved to model.joblib")
