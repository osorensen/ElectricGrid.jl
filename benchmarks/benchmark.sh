# create bash script to run each benchmarks and store with system names
# and benchmark names
#! bin/bash

# create a directory to store the results
mkdir -p results

# run benchmark scripts using julia
julia benchmarks/benchmark_classical.jl