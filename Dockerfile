# Use official Python image
FROM python:3.11-slim

# Install minimal system dependencies required for Playwright and a clean environment.
# Playwright's 'install --with-deps' will handle most browser-specific dependencies.
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    # Add any other fundamental system dependencies your app might need here,
    # but avoid browser-specific ones like 'chromium' as Playwright handles them.
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install Python dependencies from requirements.txt first
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Install 'uv' - crucial for subsequent 'uv pip install' commands.
# Using cache mount for pip cache.
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-cache \
    pip install uv

# Ensure 'uv' (and other pip-installed binaries) are in the PATH.
# In slim images, pip often installs executables to /root/.local/bin for the root user.
ENV PATH="/root/.local/bin:$PATH"

# Install Playwright Python packages using 'uv'.
# Using cache mount for uv's internal cache.
RUN --mount=type=cache,target=/root/.cache,sharing=locked,id=uv-cache \
    uv pip install playwright==1.52.0 patchright==0.1.0 # Specify desired versions directly here

# Install Chromium browser binary and its system dependencies using Playwright's installer.
# '--with-deps' ensures all necessary system libraries for Chromium are installed.
# '--no-shell' prevents interactive prompts.
# Using cache mounts for apt and playwright's browser downloads.
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