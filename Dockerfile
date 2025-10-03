# Multi-stage build optimized for ML API production deployment

# Stage 1: Build environment with all development dependencies
FROM python:3.12-slim AS builder

# Install build dependencies

# Layer Caching（层缓存）
#Docker 镜像是分层构建的，每条 RUN、COPY、ADD 指令都会生成一个新层。缓存的关键点在于：
#缓存复用：如果某一层的指令和输入文件没有变化，Docker 会直接复用之前的层，而不是重新执行。
#优化顺序：
#把变化少的步骤放前面（如安装系统依赖、pip/npm install），变化多的步骤放后面（如 COPY . .）。
#这样可以避免频繁失效导致整个构建层层重跑。
#合并指令：多个 RUN 合并成一个，减少层数和冗余文件。如下所示：

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
RUN pip install --no-cache-dir -r requirements.txt


# 选择精简基础镜像：如 python:3.9-slim 而不是 python:3.9。

# Layer Caching：把不常变的步骤（如安装系统依赖、pip install）放前面，常变的步骤（如 COPY 代码）放后面。

# 多阶段构建：在 builder 阶段编译，最后只 COPY 需要的产物到 runtime 阶段。

# 合理利用缓存：先 COPY requirements.txt 再安装依赖，最后 COPY 代码。

# .dockerignore 清理上下文：避免无关文件进入镜像和触发缓存失效。



# Stage 2: Production runtime with minimal footprint
FROM python:3.12-slim AS production

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy Python dependencies from builder stage
COPY --from=builder /usr/local /usr/local

# Create non-root user for security
# A new syystem group and system user 'mluser' is created
RUN groupadd -r mluser && useradd -r -g mluser -m mluser

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
CMD curl -f http://localhost:8000/ || exit 1

# Expose application port 8000
EXPOSE 8000

# Start application with proper signal handling
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "localhost", "--port", "8000"]