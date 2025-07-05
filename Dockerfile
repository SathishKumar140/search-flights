# Stage 1: Builder - Install all Python dependencies, uv, and browser binaries
FROM python:3.11-slim as builder

# Set common environment variables for the builder stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory for the builder stage
WORKDIR /app

# Install minimal system dependencies required for Playwright and general use.
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy your requirements.txt for initial Python dependencies
COPY requirements.txt .

# Upgrade pip.
RUN pip install --upgrade pip

# Install main Python dependencies from requirements.txt.
RUN --mount=type=cache,target=/root/.cache/pip_reqs,sharing=locked,id=pip-reqs-cache \
    pip install -r requirements.txt

# Install 'uv' using pip. This gets its own RUN command and a dedicated cache mount.
RUN --mount=type=cache,target=/root/.cache/pip_uv,sharing=locked,id=pip-uv-cache \
    pip install uv

# IMPORTANT: Ensure 'uv' (and other pip-installed binaries like 'playwright' CLI) are in the PATH.
# In slim images, pip and uv (with --system) often install executables to /usr/local/bin.
# This ENV instruction applies to all *subsequent* RUN commands in this stage and to the final image.
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Now, use 'uv' to install playwright and patchright.
RUN --mount=type=cache,target=/root/.cache/uv_deps,sharing=locked,id=uv-deps-cache \
    uv pip install --system playwright==1.52.0 patchright==1.52.5

# Install Chromium browser binary and its system dependencies using Playwright's installer.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache \
    --mount=type=cache,target=/root/.cache/ms-playwright,sharing=locked,id=playwright-browser-cache \
    apt-get update -qq && \
    playwright install --with-deps --no-shell chromium && \
    test -d "/root/.cache/ms-playwright" || (echo "ERROR: Playwright browser cache directory not found!" && exit 1) && \
    rm -rf /var/lib/apt/lists/*

# --- DEBUGGING START (CRITICAL: Examine this output carefully in your next build) ---
# This RUN command will execute *after* all installations in the builder stage.
RUN echo "--- Verifying paths in Builder Stage before copying ---" && \
    echo "1. Contents of /usr/local/bin/ (expected location for uv and playwright CLI):" && \
    ls -la /usr/local/bin/ || echo "  /usr/local/bin not found or empty." && \
    echo "2. Contents of /root/.local/bin/ (fallback location for uv):" && \
    ls -la /root/.local/bin/ || echo "  /root/.local/bin not found or empty." && \
    echo "3. Location of 'uv' executable:" && which uv || echo "  uv not found in PATH." && \
    echo "4. Location of 'playwright' executable:" && which playwright || echo "  playwright not found in PATH." && \
    echo "5. Contents of Playwright browser cache directory (/root/.cache/ms-playwright/):" && \
    ls -la /root/.cache/ms-playwright/ || echo "  /root/.cache/ms-playwright not found or empty." && \
    ls -la /root/.cache/ms-playwright/chromium-* || echo "  Chromium browser directory not found in cache." && \
    echo "----------------------------------------------------"
# --- DEBUGGING END ---


# Stage 2: Final - Create a smaller runtime image
FROM python:3.11-slim

# Set common environment variables for the final stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# CRITICAL: Ensure PATH is also set correctly in the final stage.
# This makes uv and playwright CLI tools callable at runtime.
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Set the working directory for the final stage
WORKDIR /app

# Copy all installed Python packages from the builder stage.
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy the 'uv' and 'playwright' CLI executables from the builder stage.
# Assuming 'uv' is in /usr/local/bin, and 'playwright' is in /usr/local/bin
COPY --from=builder /usr/local/bin/uv /usr/local/bin/uv
COPY --from=builder /usr/local/bin/playwright /usr/local/bin/playwright

# CRITICAL: Copy the Playwright browser binaries from the builder stage to the final image.
# This path must exactly match where playwright installed it in the builder stage.
COPY --from=builder /root/.cache/ms-playwright /root/.cache/ms-playwright

# Copy your application source code last.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]