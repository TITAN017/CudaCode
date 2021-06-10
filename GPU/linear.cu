#include "linear.h"
#include "../utils/utils.h"


__global__
void linear_forward(float *inp, float *weights, float *bias, float *out, int bs, int n_in, int n_out){
    int row = blockDim.y*blockIdx.y + threadIdx.y, col = blockDim.x*blockIdx.x + threadIdx.x;
    int ind_inp, ind_weights, ind_out;

    if ((row < bs) && (col < n_out)){
        ind_out = row*n_out + col;
        out[ind_out] = bias[col];

        for (int i=0; i<n_in; i++){
            ind_inp = row*n_in + i;
            ind_weights = i*n_out + col;
            
            out[ind_out] += inp[ind_inp]*weights[ind_weights];
        }
    }
}


__global__
void linear_backward(float *inp, float *weights, float *out, int bs, int n_in, int n_out){
    int row = blockDim.y*blockIdx.y + threadIdx.y, col = blockDim.x*blockIdx.x + threadIdx.x;
    int ind_inp, ind_weights, ind_out;

    if ((row < bs) && (col < n_out)){
        ind_out = row*n_out + col;

        for (int i=0; i<n_in; i++){
            ind_inp = row*n_in + i;
            ind_weights = i*n_out + col;

            inp[ind_inp] += weights[ind_weights]*out[ind_out];
        }
    }
}


__global__
void linear_update(float *inp, float *weights, float *bias, float *out, int bs, int n_in, int n_out, float lr){
    int row = blockDim.y*blockIdx.y + threadIdx.y, col = blockDim.x*blockIdx.x + threadIdx.x;
    int ind_inp, ind_weights, ind_out;

    if ((row < bs) && (col < n_out)){
        ind_out = row*n_out + col;
	    atomicAdd(&bias[col], -lr*out[ind_out]);

        for (int i=0; i<n_in; i++){
            ind_inp = row*n_in + i;
            ind_weights = i*n_out + col;

            weights[ind_weights] -= lr*(inp[ind_inp]*out[ind_out]);
        }
    }
}


Linear_GPU::Linear_GPU(int _bs, int _n_in, int _n_out){
    bs = _bs;
    n_in = _n_in;
    n_out = _n_out;
    sz_out = bs*n_out;
    n_block_rows = (bs + block_size - 1) / block_size;
    n_block_cols = (n_out + block_size - 1) / block_size;

    int sz_weights = n_in*n_out;
    cudaMallocManaged(&weights, sz_weights*sizeof(float));
    cudaMallocManaged(&bias, n_out*sizeof(float));

    kaiming_init(weights, n_in, n_out);
    init_zero(bias, n_out);
}


void Linear_GPU::forward(float *_inp, float *_out){
    inp = _inp;
    out = _out;

    dim3 n_blocks(n_block_cols, n_block_rows);
    dim3 n_threads(block_size, block_size);

    linear_forward<<<n_blocks, n_threads>>>(inp, weights, bias, out, bs, n_in, n_out);
    cudaDeviceSynchronize();
}


void Linear_GPU::backward(){
    init_zero(inp, bs*n_in);

    dim3 n_blocks(n_block_cols, n_block_rows);
    dim3 n_threads(block_size, block_size);

    linear_backward<<<n_blocks, n_threads>>>(inp, cp_weights, out, bs, n_in, n_out);
    cudaDeviceSynchronize();

    cudaFree(cp_weights);
}


void Linear_GPU::update(){
    cudaMallocManaged(&cp_weights, n_in*n_out*sizeof(float));
    set_eq(cp_weights, weights, n_in*n_out);

    dim3 n_blocks(n_block_cols, n_block_rows);
    dim3 n_threads(block_size, block_size);

    linear_update<<<n_blocks, n_threads>>>(inp, weights, bias, out, bs, n_in, n_out, 0.1f);
    cudaDeviceSynchronize();
}
