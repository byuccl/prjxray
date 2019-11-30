export XRAY_DATABASE="pynq"
export XRAY_PART="xc7z020clg400-1"

# Bigger region with 8 tiles
# SLICE_X55Y0     CLBLM_R_X37Y0  97,155   * Need an extra tile to the right for the interconnect
# SLICE_X69Y49    CLBLL_L_X44Y49 112,105  * Need an extra tile to the left for the interconnect
# Need an extra tile column to the left
export XRAY_ROI="SLICE_X54Y0:SLICE_X69Y49"
export XRAY_ROI_GRID_X1="96"
export XRAY_ROI_GRID_X2="113"
export XRAY_ROI_GRID_Y1="104"
export XRAY_ROI_GRID_Y2="156"
export XRAY_ROI_FRAMES="0x00000000:0xfffffff"
export XRAY_PIN_00="U7"
export XRAY_PIN_01="V7"
export XRAY_PIN_02="T9"
export XRAY_PIN_03="U10"
export XRAY_PIN_04="Y7"
export XRAY_PIN_05="Y6"
export XRAY_PIN_06="Y9"

source $(dirname ${BASH_SOURCE[0]})/../../utils/environment.sh
