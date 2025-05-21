FROM rstudio/plumber:latest

# 1. Install ALL system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    coinor-libcbc-dev \
    coinor-libclp-dev \
    coinor-libcoinutils-dev \
    coinor-libosi-dev \
    pkg-config \
    libblas-dev \
    liblapack-dev \
    gfortran \
    zlib1g-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 2. Install ROI.plugin.cbc from local copy
# Replace the installation section with:
RUN mkdir -p /tmp/r-packages && cd /tmp/r-packages && \
    wget https://cran.r-project.org/src/contrib/Archive/ROI.plugin.cbc/ROI.plugin.cbc_0.3-0.tar.gz -O pkg.tar.gz && \
    R CMD INSTALL pkg.tar.gz && \
    rm -rf /tmp/r-packages

# 3. Install remaining R packages
RUN R -e "install.packages(c('ROI', 'plumber', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# 4. Set up working directory
WORKDIR /app
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# 5. Final verification
RUN R -e "library(ROI.plugin.cbc); cat('ROI.plugin.cbc successfully installed and loaded\n')"

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
