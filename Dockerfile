FROM rstudio/plumber:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    coinor-libcbc-dev

# Install R packages
RUN R -e "install.packages(c('plumber', 'ROI', 'ROI.plugin.cbc', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# Set working directory
WORKDIR /app

# Copy only necessary files
COPY plumber.R .
COPY entrypoint.sh .

# Verify files
RUN ls -la && \
    chmod +x entrypoint.sh

EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1

# Use entrypoint
ENT
