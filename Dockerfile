# Stage 1: Builder - Only used for Playwright browser binaries download (optional now, but kept for cache)
# Since the final image contains Python and Playwright, this builder stage is less critical for deps.
FROM python:3.11-slim as builder

# Set common environment variables for the builder stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory for the builder stage
WORKDIR /app

# Install minimal system dependencies required for building Python packages.
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    unzip \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Install 'uv' using pip (uv itself is needed to install playwright-python)
RUN pip install --upgrade pip && \
    pip install uv

# IMPORTANT: Ensure 'uv' CLI is in the PATH.
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Install playwright and patchright using uv in the builder.
# We remove version pins here to let uv pick the latest compatible versions,
# which should avoid the browser-use conflict.
RUN --mount=type=cache,target=/root/.cache/uv_deps_builder,sharing=locked,id=uv-deps-builder-cache \
    uv pip install --system playwright patchright

# Install Chromium browser binary and its system dependencies using Playwright's installer.
# This downloads and extracts the browser based on the 'playwright' version just installed.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache \
    apt-get update -qq && \
    echo "--- Starting playwright install ---" && \
    playwright install --with-deps --no-shell chromium || (echo "ERROR: playwright install command failed!" && exit 1) && \
    echo "--- playwright install command completed. Verifying cache directory. ---" && \
    test -d "/root/.cache/ms-playwright" || (echo "CRITICAL ERROR: /root/.cache/ms-playwright does not exist after install!" && ls -la /root/.cache/ && exit 1) && \
    rm -rf /var/lib/apt/lists/*


# Stage 2: Final - Create the runtime image using a Playwright base image
# IMPORTANT: Adjust this image version if the 'playwright' version installed in the final stage updates significantly.
FROM mcr.microsoft.com/playwright/python:v1.52.0-jammy

# Set common environment variables for the final stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Set the working directory for the final stage
WORKDIR /app

# Copy requirements.txt to the final stage
COPY requirements.txt .

# Install 'uv' in the final stage.
# This is necessary because the Playwright image might not have uv pre-installed.
RUN pip install uv

# Now, use 'uv' to install ALL Python dependencies from requirements.txt directly in the final stage.
# Assuming requirements.txt now only specifies "playwright" and "patchright" without pins.
RUN uv pip install --system -r requirements.txt

# Copy your application source code last.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
CMD ["sh", "-c", "python -m uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]