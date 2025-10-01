# Multi-stage build optimized for ML API production deployment

# Stage 1: Build environment with all development dependencies
FROM python:3.9-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y\
    gcc \
    g++ \
    libc6-dev \
    git \
    # Clean up apt cache to reduce image size 
    # and risk of leaking sensitive data
    && rm -rf /var/lib/apt/lists/*\
    && apt-get clean
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt



# Stage 2: Production runtime with minimal footprint
FROM python:3.9-slim as production

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy Python dependencies from builder stage
COPY --from=builder /root/.local /root/.local

# Create non-root user for security
# A new syystem group and system user 'mluser' is created
RUN groupadd -r mluser && useradd-r-g mluser mluser

# Set working directory
WORKDIR /app

# Copy application code with proper ownership
COPY --chown=mluser:mluser src/ ./src/
COPY --chown=mluser:mluser models/ ./models/
COPY --chown=mluser:mluser config/ ./config/

# Set Python path and environment variables
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONPATH=/app/src
# Ensure stdout and stderr are unbuffered so that logs are visible in real-time
ENV PYTHONUNBUFFERED=1
# Prevent Python from writing .pyc files to disk
# Reduce image size and avoid permission issues e.g. in read-only filesystems
ENV PYTHONDONTWRITEBYTECODE=1

# Switch to non-root user
USER mluser

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
CMD curl -f http://localhost:8000/health || exit 1

# Expose application port 8000
EXPOSE 8000

# Start application with proper signal handling
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]