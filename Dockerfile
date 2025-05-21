FROM rstudio/plumber:latest

# 1. Install system dependencies (including CoinOR-CBC)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    pkg-config \
    coinor-cbc \
    && rm -rf /var/lib/apt/lists/*

# 2. Create directory structure
RUN mkdir -p /app/solvers
WORKDIR /app

# 3. Install R packages from correct repositories
RUN R -e "\
  install.packages('remotes'); \
  remotes::install_version('ROI', version = '1.0-0'); \
  install.packages(c('plumber', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr')); \
  remotes::install_github('datastorm-open/ROI.plugin.cbc')"

# 4. Verify package installation
RUN R -e "\
  library(ROI); \
  library(ROI.plugin.cbc); \
  print(ROI_registered_solvers())"

# 5. Set up CBC solver
COPY solvers/cbc.exe /app/solvers/
RUN chmod +x /app/solvers/cbc.exe && \
    echo 'options(ROI.plugin.cbc.cbc = "/app/solvers/cbc.exe")' >> /usr/local/lib/R/etc/Rprofile.site

# 6. Copy application files
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
