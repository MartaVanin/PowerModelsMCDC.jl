using LinearAlgebra
using LinearAlgebra: I
import PowerModels
const _PM = PowerModels
using PowerModelsMCDC
const _PMMCDC= PowerModelsMCDC
# import PowerModelsDistribution
# const _PD = PowerModelsDistribution
using PowerModelsACDC
const _PMACDC= PowerModelsACDC

using InfrastructureModels
const _IM=InfrastructureModels
using JuMP
using Ipopt
using Memento
using Gurobi


ipopt_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=1)
gurobi_solver = JuMP.with_optimizer(Gurobi.Optimizer)


function build_mc_data!(base_data)
    mp_data = PowerModels.parse_file(base_data)
    #changing the connection point
       for (c,bn) in mp_data["branchdc"]
           # if bn["line_confi"]==1
           #     bn["connect_at"]=2
           #     # bn["line_confi"]=2
           # end
       end
       for (c,conv) in mp_data["convdc"]
           # display("configuration of $c is")
           # display(conv["conv_confi"])
           # if conv["conv_confi"]==1
           #     conv["connect_at"]=2
           #     # conv["conv_confi"]=2
           #     # conv["ground_type"]=0
           # end
           if conv["ground_type"]== 1 #or 0
               conv["ground_z"]=0.5
           end
             # conv["ground_type"]=0
       end

       #making lossless conv paramteres
     for (c,conv) in mp_data["convdc"]
        # conv["transformer"]=0
        # conv["filter"]=0
        # conv["reactor"]=0
        # conv["LossA"]=0
        # conv["LossB"]=0
        # conv["LossCrec"]=0
        # conv["LossCinv"]=0
    end

    PowerModelsMCDC.process_additional_data!(mp_data)
    PowerModelsMCDC._make_multiconductor_new!(mp_data)
    # Adjusting line limits
    for (c,bn) in mp_data["branchdc"]
        if bn["line_confi"]==2
            bn["rateA"]=bn["rateA"]/2
            bn["rateB"]=bn["rateB"]/2
            bn["rateC"]=bn["rateC"]/2
            bn["r"]=bn["r"]/2
        end
        metalic_cond_number= bn["conductors"]
        # bn["rateA"][metalic_cond_number]=bn["rateA"][metalic_cond_number]*0.1
        # bn["rateB"][metalic_cond_number]=bn["rateB"][metalic_cond_number]*0.1
        # bn["rateC"][metalic_cond_number]=bn["rateC"][metalic_cond_number]*0.1

        bn["return_z"]=0.5 # adjust metallic resistance
        bn["r"][metalic_cond_number]=bn["return_z"]
    end

      # Adjusting conveter limits
      for (c,conv) in mp_data["convdc"]
         if conv["conv_confi"]==2
             conv["Pacmax"]=conv["Pacmax"]/2
             conv["Pacmin"]=conv["Pacmin"]/2
             conv["Pacrated"]=conv["Pacrated"]/2
         end
      end
      # Adjusting metallic return bus voltage limits
      for (i,busdc) in mp_data["busdc"]
         busdc["Vdcmax"][3]=0.1
         busdc["Vdcmin"][3]=-0.1
         busdc["Vdcmax"][2]=-0.9
         busdc["Vdcmin"][2]=-1.1
      end
    return mp_data
end

datadc_new = build_mc_data!("./test/data/matacdc_scripts/case5_2grids_MC.m")
# datadc_new = build_mc_data!("./test/data/matacdc_scripts/3grids_MC.m")
# datadc_new = build_mc_data!("./test/data/matacdc_scripts/4_case5_2grids_MC.m")


s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result_mcdc = PowerModelsMCDC.run_mcdcopf(datadc_new, _PM.ACPPowerModel, ipopt_solver, setting = s)

#--------------------------------------------------------------------------------------------------------
# result_acdc = _PMACDC.run_acdcopf(dc_data, _PM.ACPPowerModel, ipopt_solver, setting = s)
#
# for i in 1:5
#     display(result_acdc["solution"]["gen"]["$i"]["pg"])
# end



#############

println("#######ACgrid side#######")
println("generation")
for (i,gen) in result_mcdc["solution"]["gen"]
    g=gen["pg"]
    display("$i, $g")
end
println("AC Bus Va and Vm")
for (i,bus) in result_mcdc["solution"]["bus"]
    a=bus["va"]
    b=bus["vm"]
    display("$i, $a, $b")
    # display(a b)
end

println("AC branch flows")
for (i,branch) in result_mcdc["solution"]["branch"]
    flow_from=branch["pf"]
    flow_to=branch["pt"]
    display("$i, $flow_from, $flow_to")
end



println("###DC grid side###")
println("DC bus Vm")
for (i,dcbus) in result_mcdc["solution"]["busdc"]
    b=dcbus["vm"]
    display("$i, $b")
end


println(".....conv....")
println(".....pgrid....")
for (i,conv) in result_mcdc["solution"]["convdc"]
     # display("power from grid to dc at converter $i")
     a= conv["pgrid"]
    display("$i, $a")
end

println(".....pdc....")
for (i,conv) in result_mcdc["solution"]["convdc"]
     a= conv["pdc"]
    display("$i, $a")
end

println(".....pdcg....")
for (i,conv) in result_mcdc["solution"]["convdc"]
     a= conv["pdcg"]
    display("$i, $a")
end

println(".....pdcg_shunt....")
for (i,conv) in result_mcdc["solution"]["convdc"]
     a= conv["pdcg_shunt"]
    display("$i, $a")
end

println(".....iconv_dc....")
for (i,conv) in result_mcdc["solution"]["convdc"]
     a= conv["iconv_dc"]
     display("$i, $a")
end

println(".....iconv_dcg_shunt....")
for (i,conv) in result_mcdc["solution"]["convdc"]
     a= conv["iconv_dcg_shunt"]
     display("$i, $a")
end
println(".....conv ground status....")
for (i,conv) in datadc_new["convdc"]
        a=conv["ground_type"]
        b=conv["ground_z"]
        display("$a, $b")
end

println(".....DC branch flows....")
for (i,branch) in result_mcdc["solution"]["branchdc"]
    flow_from=branch["pf"]
    flow_to=branch["pt"]
    display("$i, $flow_from, $flow_to")
end

# for (i,branch) in datadc_new["branchdc"]
#     r=branch["r"]
#     display("$i,$r")
# end

println(".....DC branch losses....")
for (i,branch) in result_mcdc["solution"]["branchdc"]
    flow_from=branch["pf"]
    flow_to=branch["pt"]
    c=flow_from+flow_to
    # display("$i, $flow_from, $flow_to, $c")
    display("$i, $c")
end

println("termination status of the pf is:", result_mcdc["termination_status"])
