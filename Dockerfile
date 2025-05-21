FROM rstudio/plumber:latest

# 1. Install ALL system dependencies including CBC solver
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
    cmake \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 2. Install R packages with guaranteed installation method
RUN R -e "install.packages(c('remotes', 'ROI'))"
RUN R -e "options(timeout=1200); \
          if(!require('ROI.plugin.cbc')) { \
            install.packages('https://cran.r-project.org/src/contrib/Archive/ROI.plugin.cbc/ROI.plugin.cbc_0.3-0.tar.gz', \
                            repos=NULL, type='source'); \
            if(!require('ROI.plugin.cbc')) { \
              system('apt-get install -y coinor-libcbc-dev'); \
              remotes::install_github('datastorm-open/ROI.plugin.cbc@0.3-0', dependencies=TRUE); \
              if(!require('ROI.plugin.cbc')) stop('Installation failed after all methods') \
            } \
          }"

# 3. Install remaining packages
RUN R -e "install.packages(c('plumber', 'ompr', 'dplyr', 'readxl', 'openxlsx', 'httr'))"

# 4. Set up working directory
WORKDIR /app
COPY plumber.R .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# 5. Final verification
RUN R -e "library(ROI.plugin.cbc); \
          cat('### ROI.plugin.cbc successfully loaded ###\n'); \
          print(ROI_available_solvers())"

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
