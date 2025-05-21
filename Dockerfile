FROM rstudio/plumber:latest

# 1. Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 2. Create directory structure early
RUN mkdir -p /app/solvers
WORKDIR /app

# 3. Install R packages (with error checking)
RUN R -e "install.packages(c('ROI', 'ROI.plugin.cbc', 'plumber', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))" && \
    R -e "library(ROI); library(ROI.plugin.cbc)"  # Verify packages load

# 4. Copy solver and configure (simplified approach)
COPY solvers/cbc.exe /app/solvers/
RUN chmod +x /app/solvers/cbc.exe && \
    echo 'cbc_path <- "/app/solvers/cbc.exe"' > cbc_config.R && \
    echo 'options(ROI.plugin.cbc.cbc = cbc_path)' >> cbc_config.R

# 5. Alternative configuration that always works
RUN echo 'options(ROI.plugin.cbc.cbc = "/app/solvers/cbc.exe")' > /usr/local/lib/R/etc/Rprofile.site

# 6. Copy application files
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
