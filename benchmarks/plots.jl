# using PlotlyJS
using JLD2
using BenchmarkTools
using Distributions
using StatsPlots

data_dir = pwd() * "/benchmarks/data/"
classical_data = load(data_dir * "benchmark_5_50.jld2")["benchmark_data"]
ddpg_data = load(data_dir * "benchmark_RL_5_37.jld2")["benchmark_data"]

# load Benchmark data from JLD2
# classical_data = load("benchmark_5_50.jld2")["benchmark_data"]

# plot classical data and ddpg data
nodes = collect(5:5:50)
times_classical = [(b.times * 1e-9) for b in classical_data]
times_ddpg = [(b.times * 1e-9) for b in ddpg_data[1:end-1]]

# constant time for real time at 1
real_time = [1 for b in classical_data]

StatsPlots.plot(nodes[1:6], 
    mean.(times_classical[1:6]), 
    label="classical", 
    title="Benchmark of Simulation for 1s (with Δt = 1ms)", 
    xlabel="Number of nodes [equally distributed sources and loads]", 
    ylabel="Time averaged over 3 benchmarks (s)")

StatsPlots.plot!(
    nodes[1:6],
    mean.(times_ddpg),
    label="ddpg")
# plot realtime

StatsPlots.plot!(
    nodes[1:6],
    real_time[1:6],
    label="realtime")

# try with plotlyS
using PlotlyJS

# plot classical data and ddpg data
traces = []
push!(traces, PlotlyJS.scatter(x=nodes, y=mean.(times_classical), mode="lines", name="classical"))
push!(traces, PlotlyJS.scatter(x=nodes[1:7], y=mean.(times_ddpg), mode="lines", name="ddpg"))
push!(traces, PlotlyJS.scatter(x=nodes, y=real_time, mode="lines", name="realtime"))

# plot
PlotlyBase.Plot(traces,
    config=PlotConfig(scrollZoom=true))