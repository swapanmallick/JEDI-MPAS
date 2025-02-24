#!/bin/csh -f

####################################
## workflow-relevant state variables
####################################
set MPASHydroIncrementVariables = (qc qi qg qr qs)
set MPASHydroStateVariables = (${MPASHydroIncrementVariables} cldfrac)

set StandardAnalysisVariables = ( \
  spechum \
  surface_pressure \
  temperature \
  uReconstructMeridional \
  uReconstructZonal \
)
set StandardStateVariables = ( \
  $StandardAnalysisVariables \
  theta \
  rho \
  u \
  qv \
  pressure \
  landmask \
  xice \
  snowc \
  skintemp \
  ivgtyp \
  isltyp \
  snowh \
  vegfra \
  u10 \
  v10 \
  lai \
  smois \
  tslb \
  pressure_p \
)

set MPASJEDIVariablesFiles = (\
  geovars.yaml \
  obsop_name_map.yaml \
)
