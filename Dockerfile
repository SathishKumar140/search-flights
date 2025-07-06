# Use Python 3.13 as the base image
FROM python:3.13

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
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 \
    libnspr4 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libxkbcommon0 \
    libasound2 \
    libatspi2.0-0 \
    xvfb \
    x11vnc \
    fontconfig \
    # The following were commented out in your reference, keeping them commented here.
    # libx11-xcb1 \
    # libgtk-3-0 \
    # gstreamer1.0-libav \
    # gstreamer1.0-plugins-good \
    && rm -rf /var/lib/apt/lists/*

# --- Then, install Playwright browser binaries ---
# By default, 'playwright install' downloads Chromium, Firefox, and WebKit.
# Now that system dependencies are present, this step should proceed without the missing dependency error.
RUN playwright install

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