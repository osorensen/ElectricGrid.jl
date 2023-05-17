using ElectricGrid
using BenchmarkTools

nc = NodeConstructor(
    num_sources = 2,
    num_loads = 2,
)

@show nc.parameters["source"][1]["control_type"]

# replace control type to RL and mode to ddpg
for i in 1:nc.num_sources
    nc.parameters["source"][i]["control_type"] = "RL"
    nc.parameters["source"][i]["mode"] = "ddpg"
end


temp_env = ElectricGridEnv(
    CM=nc.CM,
    action_delay=0,
    t_end = 1.0, 
    parameters = nc.parameters,
    )

@show temp_env.nc.parameters["source"][1]["mode"]
@show temp_env.agent_dict


@benchmark Simulate($controller, $env) 