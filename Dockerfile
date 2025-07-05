# Stage 1: Builder - Install all Python dependencies, uv, and browser binaries
FROM python:3.11-slim as builder

# Set common environment variables for the builder stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory for the builder stage
WORKDIR /app

# Install minimal system dependencies required for Playwright and general use.
# -qq for quiet update, --no-install-recommends to keep image size down.
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    # Add any other fundamental system dependencies your app explicitly needs here.
    # e.g., curl, git, procps (for ps command sometimes used in debug)
    # curl \
    # git \
    # procps \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy your requirements.txt for initial Python dependencies
# This allows Docker to cache this layer efficiently if requirements.txt doesn't change.
COPY requirements.txt .

# Upgrade pip (doesn't need a specific cache mount for itself).
RUN pip install --upgrade pip

# Install main Python dependencies from requirements.txt.
# Uses a cache mount for pip's download cache for these requirements.
RUN --mount=type=cache,target=/root/.cache/pip_reqs,sharing=locked,id=pip-reqs-cache \
    pip install -r requirements.txt

# Install 'uv' using pip. This gets its own RUN command and a dedicated cache mount.
RUN --mount=type=cache,target=/root/.cache/pip_uv,sharing=locked,id=pip-uv-cache \
    pip install uv

# IMPORTANT: Ensure 'uv' (and other pip-installed binaries like 'playwright' CLI) are in the PATH.
# In slim images, pip and uv (with --system) often install executables to /usr/local/bin.
# This ENV instruction applies to all *subsequent* RUN commands in this stage and to the final image.
ENV PATH="/root/.local/bin:/usr/local/bin:$PATH" # Added /usr/local/bin explicitly at the start

# Now, use 'uv' to install playwright and patchright.
# This is a separate RUN command with its own cache mount for uv's internal cache.
# The PATH should now be correctly set from the preceding ENV instruction.
RUN --mount=type=cache,target=/root/.cache/uv_deps,sharing=locked,id=uv-deps-cache \
    uv pip install --system playwright==1.52.0 patchright==1.52.5

# Install Chromium browser binary and its system dependencies using Playwright's installer.
# This step downloads the browser to /root/.cache/ms-playwright/.
# --with-deps: ensures necessary system libraries for the browser are installed.
# --no-shell: prevents interactive prompts during installation.
# Uses cache mounts for apt packages and Playwright's browser downloads.
# Added 'test -d ...' to explicitly check for the directory creation.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache \
    --mount=type=cache,target=/root/.cache/ms-playwright,sharing=locked,id=playwright-browser-cache \
    apt-get update -qq && \
    playwright install --with-deps --no-shell chromium && \
    # VERIFY THE BROWSER CACHE DIRECTORY EXISTS BEFORE CONTINUING
    test -d "/root/.cache/ms-playwright" || (echo "ERROR: Playwright browser cache directory not found!" && exit 1) && \
    rm -rf /var/lib/apt/lists/*


# Stage 2: Final - Create a smaller runtime image
FROM python:3.11-slim

# Set common environment variables for the final stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# CRITICAL: Ensure PATH is also set correctly in the final stage.
# This makes uv and playwright CLI tools callable at runtime.
ENV PATH="/root/.local/bin:/usr/local/bin:$PATH"

# Set the working directory for the final stage
WORKDIR /app

# Copy all installed Python packages from the builder stage.
# This brings over all Python libraries, including playwright and browser_use.
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy the 'uv' and 'playwright' CLI executables from the builder stage.
# Assuming 'uv' is in /root/.local/bin, and 'playwright' is in /usr/local/bin
COPY --from=builder /root/.local/bin/uv /usr/local/bin/uv
COPY --from=builder /usr/local/bin/playwright /usr/local/bin/playwright # <-- CORRECTED COPY PATH FOR PLAYWRIGHT CLI

# --- CRITICAL: Copy the Playwright browser binaries from the builder stage to the final image. ---
# This path must exactly match where playwright installed it in the builder stage.
COPY --from=builder /root/.cache/ms-playwright /root/.cache/ms-playwright

# Copy your application source code last.
# This leverages Docker's build cache effectively: changes to your code won't
# invalidate the dependency installation layers.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
# It uses the PORT environment variable if set (common in cloud deployments like Vercel, Render)
# or defaults to 8000.
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]