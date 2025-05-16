FROM rstudio/plumber:latest

# 1. Install system dependencies for CBC solver
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    coinor-libcbc-dev \
    coinor-libclp-dev \
    coinor-libcoinutils-dev \
    coinor-libosi-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

# 2. Install R packages (alternative method)
RUN R -e "install.packages('BiocManager')"
RUN R -e "BiocManager::install('ROI.plugin.cbc')"
RUN R -e "install.packages(c('plumber', 'ROI', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# 3. Verify CBC solver works
RUN R -e "library(ROI); ROI_available_solvers(); library(ROI.plugin.cbc)"

# 4. Set up working directory
WORKDIR /app
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 10000

# 5. Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1

# 6. Entrypoint
ENTRYPOINT ["./entrypoint.sh"]
