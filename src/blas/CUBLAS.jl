module CUBLAS

import CUDAdrv: CUDAdrv, CuContext, CuStream_t, CuPtr, PtrOrCuPtr, CU_NULL
import CUDAapi

using ..CuArrays
using ..CuArrays: libcublas, active_context, unsafe_free!

using LinearAlgebra

include("libcublas_types.jl")
include("error.jl")

const _handles = Dict{CuContext,cublasHandle_t}()
const _xt_handles = Dict{CuContext,cublasXtHandle_t}()
const _handle = Ref{cublasHandle_t}(C_NULL)
const _xt_handle = Ref{cublasXtHandle_t}(C_NULL)

function handle()
    if _handle[] == C_NULL
        @assert isassigned(active_context) # some other call should have initialized CUDA
        _handle[] = get!(_handles, active_context[]) do
            context = active_context[]
            handle = cublasCreate_v2()

            # enable tensor math mode if our device supports it, and fast math is enabled
            dev = CUDAdrv.device(context)
            if Base.JLOptions().fast_math == 1 && CUDAdrv.capability(dev) >= v"7.0"
              cublasSetMathMode(CUBLAS_TENSOR_OP_MATH, handle)
            end

            atexit(()->CUDAdrv.isvalid(context) && cublasDestroy_v2(handle))
            handle
        end
    end

    return _handle[]
end

function xt_handle()
    if _xt_handle[] == C_NULL
        @assert isassigned(active_context) # some other call should have initialized CUDA
        _xt_handle[] = get!(_xt_handles, active_context[]) do
            context = active_context[]
            dev = CUDAdrv.device(context)
            handle = cublasXtCreate()
            cublasXtDeviceSelect(handle, 1, [dev.handle])
            #cublasXtSetBlockDim(handle, 64)

            atexit(()->CUDAdrv.isvalid(context) && cublasXtDestroy(handle))

            handle
        end
    end
    return _xt_handle[]
end

include("libcublas.jl")
include("util.jl")
include("wrappers.jl")
include("highlevel.jl")

version() = VersionNumber(cublasGetProperty(CUDAapi.MAJOR_VERSION),
                          cublasGetProperty(CUDAapi.MINOR_VERSION),
                          cublasGetProperty(CUDAapi.PATCH_LEVEL))

end
