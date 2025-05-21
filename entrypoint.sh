#!/bin/sh
# Load CBC configuration before starting Plumber
Rscript -e "source('/app/cbc_config.R')"
Rscript -e "pr <- plumber::plumb('plumber.R'); pr\$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 10000)))"
