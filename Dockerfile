# Use the specified Python 3.12 on Debian Bookworm as the base image
FROM python:3.12-bookworm

# Set common environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory for your application
WORKDIR /app

# Update apt and install minimal core system dependencies that might be needed.
# 'bookworm' is more complete than 'slim', so fewer specific packages might be needed here,
# but 'playwright install --with-deps' will handle most browser-specific ones.
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    unzip \
    # Add any other fundamental system utilities your app might need here if not in bookworm
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy your requirements.txt file
COPY requirements.txt .

# Upgrade pip and install all Python dependencies from requirements.txt.
# Ensure uvicorn is in your requirements.txt (e.g., uvicorn[standard])
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Install the Playwright Python package and then download the Chromium browser binaries
# along with their necessary system dependencies.
# Corrected syntax for playwright version from ==@1.52.0 to ==1.52.0
RUN pip install playwright==1.52.0 && \
    playwright install --with-deps chromium

# Copy your application source code last.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
CMD ["sh", "-c", "python -m uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]