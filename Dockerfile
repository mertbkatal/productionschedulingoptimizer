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

WORKDIR /app
COPY . .

EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1

# Use direct Rscript command (most reliable)
CMD ["Rscript", "-e", "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 10000)))"]
