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

# Set working directory and copy files
WORKDIR /app
COPY plumber.R .
COPY entrypoint.sh .

# Verify files exist and set permissions
RUN ls -la && \
    test -f plumber.R && \
    test -f entrypoint.sh && \
    chmod +x entrypoint.sh

EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1

# Corrected instruction (was 'ENT' now 'ENTRYPOINT')
ENTRYPOINT ["./entrypoint.sh"]
