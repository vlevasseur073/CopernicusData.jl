using CopernicusData
using CairoMakie
using GeoMakie
using Downloads

const PRODUCT_PATH = "https://common.s3.sbg.perf.cloud.ovh.net/eoproducts"
const OLCEFR="S03OLCEFR_20230506T015316_0180_B117_T883.zarr.zip"
const SLSFRP="S03SLSFRP_20200908T182648_0179_A298_S883.zarr.zip"
const SLSLST="S03SLSLST_20191227T124111_0179_A109_T883.zarr.zip"