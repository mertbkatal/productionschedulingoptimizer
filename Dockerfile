FROM rstudio/plumber:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    coinor-libcbc-dev && \
    rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('plumber', 'ROI', 'ROI.plugin.cbc', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# Create and set working directory
WORKDIR /app

# Copy ALL files from local folder to container
COPY . .

# Verify file existence (debugging step)
RUN ls -la /app && test -f /app/plumber.R

EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1

# Direct execution command (no intermediate script)
CMD R -e "pr <- plumber::plumb('/app/plumber.R'); pr\$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 10000)))"
