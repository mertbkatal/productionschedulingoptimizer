FROM rstudio/plumber:latest

# 1. Install ALL required system dependencies
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
    cmake && \
    rm -rf /var/lib/apt/lists/*

# 2. Install R packages with explicit build flags
RUN R -e "install.packages('remotes')"
RUN R -e "Sys.setenv(ROI_PLUGIN_CBC_SYSTEM=TRUE)"
RUN R -e "remotes::install_github('datastorm-open/ROI.plugin.cbc@0.3-0', dependencies=TRUE, upgrade='always')"
RUN R -e "install.packages(c('ROI>=0.3-0', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr', 'plumber'))"

# 3. Set up working directory
WORKDIR /app
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# 4. Final verification
RUN R -e "if(!requireNamespace('ROI.plugin.cbc', quietly=TRUE)) { install.packages('ROI.plugin.cbc', repos='https://cran.r-project.org'); library(ROI.plugin.cbc) }"

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
