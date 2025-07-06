# Stage 1: Builder - Install all Python dependencies, uv, and the playwright Python package
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

# Copy your requirements.txt
COPY requirements.txt .

# Upgrade pip (needed initially to install uv itself, as uv isn't natively available)
RUN pip install --upgrade pip

# Install 'uv' using pip.
RUN --mount=type=cache,target=/root/.cache/uv_self_install,sharing=locked,id=uv-self-install-cache \
    pip install uv

# IMPORTANT: Ensure 'uv' CLI is in the PATH.
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# NOW, use 'uv' to install ALL Python dependencies from requirements.txt.
# This assumes requirements.txt contains:
# - uvicorn[standard] (or uvicorn)
# - playwright==1.52.0
# - patchright==1.52.5
RUN --mount=type=cache,target=/root/.cache/uv_deps,sharing=locked,id=uv-deps-cache \
    uv pip install --system -r requirements.txt

# Stage 2: Final - Create the runtime image using a Playwright base image
# This image already includes all browser binaries and their system dependencies.
FROM mcr.microsoft.com/playwright/python:v1.52.0-jammy

# Set common environment variables for the final stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Set the working directory for the final stage
WORKDIR /app

# Copy all installed Python packages from the builder stage.
# uv, by default with --system, installs to /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy the 'uv' CLI executable from the builder stage.
# The Playwright base image usually has its own 'playwright' CLI, but copying 'uv' is good practice.
COPY --from=builder /usr/local/bin/uv /usr/local/bin/uv

# Copy your application source code last.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
CMD ["sh", "-c", "python -m uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]