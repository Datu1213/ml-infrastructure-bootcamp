# Dockerfile

# Stage 1: Build environment with dependencies
FROM python:3.9-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Production runtime with minimal footprint
FROM python:3.9-slim AS production
WORKDIR /app

# Copy Python dependencies from builder stage
COPY --from=builder /root/.local /root/.local

# Copy application code, models, etc.
COPY ./src ./src
COPY model.joblib .

# Set Python path and environment variables to find packages and modules
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONPATH=/app/src

# Expose the port the app runs on
EXPOSE 8000

# Start the application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]