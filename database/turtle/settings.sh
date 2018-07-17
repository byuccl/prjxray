export XRAY_DATABASE="turtle"
export XRAY_PART="xc7a200tsbg484-1"
# This is used for PBLOCK attribute and also for the attribute
# in fuzzer 5 to move the slice around. Bitstreams are generated
# based on this region. The slices should span the full clock region
# in Y direction.
#
# For fuzzers 018 and 019 you need to ahve the first set of slices
# fall into CLBLM tiles.
#
# SLICE_X24Y200  CLBLL_L_X18Y200  (50,51)
# SLICE_X35Y249  CLBLL_R_X23Y249  (61,1)
export XRAY_ROI="SLICE_X24Y200:SLICE_X35Y249"
# This is used for the tile printing and should overlap the
# slice region mentioned above. Note that the Y coordinates should
# be one hibher and lower than the slice region. Also, make sure
# you include an extra column if the interconnect tile is outside
# of the region.
export XRAY_ROI_GRID_X1="50"
export XRAY_ROI_GRID_X2="61"
export XRAY_ROI_GRID_Y1="0"
export XRAY_ROI_GRID_Y2="52"
export XRAY_ROI_FRAMES="0x00000000:0xffffffff"
#export XRAY_ROI_FRAMES="0x00020500:0x000208ff"
export XRAY_PIN_00="Y17"
export XRAY_PIN_01="Y16"
export XRAY_PIN_02="AA16"
export XRAY_PIN_03="AB16"
export XRAY_PIN_04="AB17"
export XRAY_PIN_05="AA13"
export XRAY_PIN_06="AB13"

source $(dirname ${BASH_SOURCE[0]})/../../utils/environment.sh
