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
    wget \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

# 2. Build CBC from source as fallback
RUN mkdir -p /tmp/cbc && cd /tmp/cbc && \
    wget https://github.com/coin-or/Cbc/archive/refs/tags/releases/2.10.5.tar.gz && \
    tar xzf 2.10.5.tar.gz && \
    cd Cbc-releases-2.10.5 && \
    ./configure -C && \
    make && \
    make install && \
    ldconfig && \
    rm -rf /tmp/cbc

# 3. Install R packages with multiple fallbacks
RUN R -e "install.packages(c('remotes', 'ROI'))"
RUN R -e "options(timeout=600); \
          if(!require('ROI.plugin.cbc')) { \
            try(remotes::install_github('datastorm-open/ROI.plugin.cbc@0.3-0')); \
            if(!require('ROI.plugin.cbc')) install.packages('ROI.plugin.cbc', repos='https://cran.r-project.org'); \
            if(!require('ROI.plugin.cbc')) stop('Failed to install ROI.plugin.cbc') \
          }"
RUN R -e "install.packages(c('plumber', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# 4. Set up working directory
WORKDIR /app
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# 5. Final verification
RUN R -e "library(ROI.plugin.cbc); cat('ROI.plugin.cbc loaded successfully\n')"

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
