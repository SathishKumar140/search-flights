# Use official Python image
FROM python:3.11-slim

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

# Install Playwright browsers and dependencies
RUN playwright install --with-deps

# NOTE: If 'browser_use' is not available on PyPI, you must install it manually here.
# For example, if it's a local package, add:
# COPY browser_use ./browser_use
# RUN pip install ./browser_use

# Copy project files
COPY . .

# Create browseruse user data directories and set permissions for both root and /app
RUN mkdir -p /root/.config/browseruse/profiles/default /app/.config/browseruse/profiles/default && chmod -R 777 /root/.config/browseruse /app/.config/browseruse

# Expose FastAPI port
EXPOSE 8000

# Start FastAPI app with uvicorn, using PORT env variable if set (for Vercel compatibility)
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
