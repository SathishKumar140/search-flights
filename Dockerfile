# Use official Python image
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    chromium \
    fontconfig \
    libnss3 \
    libgconf-2-4 \
    libappindicator1 \
    libasound2 \
    libatk1.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libfreetype6 \
    libgbm-dev \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    ca-certificates \
    fonts-liberation \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install system dependencies (if needed for browser_use, e.g., Chrome/Chromium)
# RUN apt-get update && apt-get install -y chromium-driver chromium

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-cache \
    pip install uv

# Install Playwright browsers and dependencies
RUN --mount=type=cache,target=/root/.cache,sharing=locked,id=uv-cache \
    uv pip install playwright==1.52.0 patchright==0.1.0 # Specify desired versions directly here

# Install Chromium browser binary and its system dependencies
# This step also uses cache mounts for apt and playwright downloads
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache \
    --mount=type=cache,target=/root/.cache/ms-playwright,sharing=locked,id=playwright-browser-cache \
    apt-get update -qq \
    && playwright install --with-deps --no-shell chromium \
    && rm -rf /var/lib/apt/lists/*


# Copy project files
COPY . .
# Expose FastAPI port
EXPOSE 8000

# Start FastAPI app with uvicorn, using PORT env variable if set (for Vercel compatibility)
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
