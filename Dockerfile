# Use official R Plumber image as base
FROM rstudio/plumber:latest

# Install system dependencies for R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    coinor-libcbc-dev \  # Required for ROI.plugin.cbc
    && rm -rf /var/lib/apt/lists/*

# Install required R packages (all from your Shiny app)
RUN R -e "install.packages(c( \
    'plumber', \
    'openxlsx', \
    'ROI', \
    'ROI.plugin.cbc', \
    'ompr', \
    'ompr.roi', \
    'dplyr', \
    'readxl', \
    'ggplot2', \
    'httr', \
    'jsonlite' \
    ), repos='https://cloud.r-project.org/')"

# Create and set working directory
WORKDIR /app

# Copy all files from local folder to container
COPY . .

# Set environment variables
ENV PORT=8000
EXPOSE $PORT

# Health check (optional but recommended)
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:$PORT/health || exit 1

# Command to run when container starts
CMD ["R", "-e", "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 8000)))"]