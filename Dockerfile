FROM rstudio/plumber:latest

# 1. Install system dependencies for CBC solver
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    coinor-libcbc-dev \
    coinor-libclp-dev \
    coinor-libcoinutils-dev && \
    rm -rf /var/lib/apt/lists/*

# 2. Install R packages with explicit dependencies
RUN R -e "install.packages('remotes')"
RUN R -e "remotes::install_version('ROI.plugin.cbc', version = '0.3.0')"
RUN R -e "install.packages(c('plumber', 'ROI', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# 3. Set up working directory
WORKDIR /app
COPY . .

# 4. Verify installation
RUN R -e "library(ROI.plugin.cbc)" || (echo "Package verification failed" && exit 1)

EXPOSE 10000

# 5. Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1

# 6. Entrypoint
ENTRYPOINT ["./entrypoint.sh"]
