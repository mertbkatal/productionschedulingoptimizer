FROM rstudio/plumber:latest

# 1. Install ALL system dependencies including build tools
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

# 2. Install R packages with multiple fallback methods
RUN R -e "install.packages(c('remotes', 'ROI'))"
RUN R -e "options(timeout=1200); \
          if(!require('ROI.plugin.cbc')) { \
            try(install.packages('ROI.plugin.cbc', repos='https://cran.r-project.org')); \
            if(!require('ROI.plugin.cbc')) { \
              try(remotes::install_github('datastorm-open/ROI.plugin.cbc@0.3-0', dependencies=TRUE, upgrade='always')); \
              if(!require('ROI.plugin.cbc')) { \
                system('apt-get install -y coinor-libcbc-dev'); \
                install.packages('ROI.plugin.cbc', type='source'); \
                if(!require('ROI.plugin.cbc')) stop('Failed to install ROI.plugin.cbc after all attempts') \
              } \
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
RUN R -e "library(ROI.plugin.cbc); cat('ROI.plugin.cbc loaded successfully\n'); \
          print(ROI_available_solvers())"

EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:10000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
