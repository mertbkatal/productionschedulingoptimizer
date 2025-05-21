FROM rstudio/plumber:latest

# 1. Install system dependencies (excluding Coin-OR packages)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 2. Set up solver environment
RUN mkdir -p /app/solvers
COPY solvers/cbc.exe /app/solvers/
RUN chmod +x /app/solvers/cbc.exe

# 3. Install R packages
RUN R -e "install.packages(c('ROI', 'ROI.plugin.cbc', 'plumber', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# 4. Configure R to use local CBC executable
RUN R -e "\
  writeLines(paste0('cbc_path <- \"/app/solvers/cbc.exe\"'), '/app/cbc_config.R'); \
  writeLines(paste0('options(ROI.plugin.cbc.cbc = cbc_path)'), '/app/cbc_config.R', append=TRUE)"

# 5. Set up working directory
WORKDIR /app
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
