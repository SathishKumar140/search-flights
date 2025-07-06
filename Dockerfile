# Use Python 3.13 as the base image
FROM python:3.12-bookworm

RUN pip install playwright==@1.52.0 && \
    playwright install --with-deps

# Set the working directory for your application
WORKDIR /app

# Copy your requirements.txt file into the container
COPY requirements.txt .

# Install Python dependencies from requirements.txt.
# --no-cache-dir prevents pip from storing downloaded packages, saving image space.
RUN pip install --no-cache-dir -r requirements.txt

# --- IMPORTANT CHANGE: Install system dependencies FIRST ---
# Install system dependencies required by Playwright browsers and other tools.
# This list is taken directly from your reference and from Playwright's recommendations.
# --no-install-recommends helps keep the image size down by avoiding recommended packages.

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Set DISPLAY for headless browser environments (e.g., when using Xvfb)
ENV DISPLAY=:99

# Copy your application source code last.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
CMD ["sh", "-c", "python -m uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]