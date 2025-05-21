FROM rstudio/plumber:latest

# 1. Install system dependencies (excluding Coin-OR packages)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 2. Create /app early and set up solver environment
RUN mkdir -p /app/solvers
WORKDIR /app
COPY solvers/cbc.exe /app/solvers/
RUN chmod +x /app/solvers/cbc.exe

# 3. Install R packages
RUN R -e "install.packages(c('ROI', 'ROI.plugin.cbc', 'plumber', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# 4. Configure R to use local CBC executable (now that /app exists)
RUN R -e "\
  writeLines('cbc_path <- \"/app/solvers/cbc.exe\"', 'cbc_config.R'); \
  writeLines('options(ROI.plugin.cbc.cbc = cbc_path)', 'cbc_config.R', append=TRUE); \
  source('cbc_config.R')"

# 5. Copy remaining files
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
