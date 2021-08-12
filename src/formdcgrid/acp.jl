"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) + sum(pconvac[c] for c in bus_convs) - pd - gs*v^2
sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) + sum(qconvac[c] for c in bus_convs) - qd + bs*v^2
```
"""
function constraint_kcl_shunt(pm::_PM.AbstractACPModel, n::Int,  i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
    vm = _PM.var(pm, n,  :vm, i)
    p = _PM.var(pm, n,  :p)
    q = _PM.var(pm, n,  :q)
    pg = _PM.var(pm, n,  :pg)
    qg = _PM.var(pm, n,  :qg)
    pconv_grid_ac = _PM.var(pm, n,  :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n,  :qconv_tf_fr)
    # display("constraint_kcl_shunt for ac bus $i")
    (JuMP.@NLconstraint(pm.model, sum(p[a] for a in bus_arcs) + sum(sum(pconv_grid_ac[c][d] for d in 1:length(_PM.var(pm, n,  :pconv_tf_fr, c))) for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens)   - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*vm^2))
    JuMP.@NLconstraint(pm.model, sum(q[a] for a in bus_arcs) + sum(sum(pconv_grid_ac[c][d] for d in 1:length(_PM.var(pm, n,  :pconv_tf_fr, c))) for c in bus_convs_ac)  == sum(qg[g] for g in bus_gens)  - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*vm^2)
end

#copied from dcp
# function constraint_kcl_shunt(pm::_PM.AbstractDCPModel, n::Int,  i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
#     p = _PM.var(pm, n, :p)
#     pg = _PM.var(pm, n, :pg)
#     pconv_ac = _PM.var(pm, n, :pconv_ac)
#     pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
#     v = 1
#     # display("constraint_kcl_shunt")
#     # display(p[a] for a in bus_arcs)
#     total_cond=length(bus_convs_ac)
#        JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(sum(pconv_grid_ac[c]) for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
#       # JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs)   == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
# end
"""
Creates Ohms constraints for DC branches

```
p[f_idx] == p * g[l] * vmdc[f_bus] * (vmdc[f_bus] - vmdc[t_bus])
```
"""
# function constraint_ohms_dc_branch(pm::_PM.AbstractACPModel, n::Int,  f_bus, t_bus, f_idx, t_idx, r, p, total_cond)
#     p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
#     p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
#     vmdc_fr = _PM.var(pm, n,  :vdcm, f_bus)
#     vmdc_to = _PM.var(pm, n,  :vdcm, t_bus)
#
#     bus_arcs_dcgrid_cond = _PM.ref(pm, n, :bus_arcs_dcgrid_cond)
#
#     # for c = 1: total_cond
#     #     if r[c] == 0
#     #         JuMP.@constraint(pm.model, p_dc_fr[c] + p_dc_to[c] == 0)
#     #     else
#             # g = 1 / r[c]
#             #doubt about p in following equation
#             for k=1:3
#                 for (line, d) in bus_arcs_dcgrid_cond[(f_bus, k)]
#                     if r[d] == 0
#                          JuMP.@constraint(pm.model, p_dc_fr[d] + p_dc_to[d] == 0)
#                     else
#                              g = 1 / r[d]
#                              display(JuMP.@NLconstraint(pm.model, p_dc_fr[d] ==  g * vmdc_fr[k] * (vmdc_fr[k] - vmdc_to[k])))
#                              display(JuMP.@NLconstraint(pm.model, p_dc_to[d] ==  g * vmdc_to[k] * (vmdc_to[k] - vmdc_fr[k])))
#                         end
#                      end
#                 # end
#
#                 # for (line, d) in bus_arcs_dcgrid_cond[(t_bus, k)]
#                 #     # JuMP.@NLconstraint(pm.model, p_dc_to[d] ==  g * vmdc_to[k] * (vmdc_to[k] - vmdc_fr[k]))
#                 # end
#             end
#
#             # JuMP.@NLconstraint(pm.model, p_dc_fr[c] ==  g * vmdc_fr[c] * (vmdc_fr[c] - vmdc_to[c]))
#             # JuMP.@NLconstraint(pm.model, p_dc_to[c] ==  g * vmdc_to[c] * (vmdc_to[c] - vmdc_fr[c]))
#         # end
#     # end
# end

function constraint_ohms_dc_branch(pm::_PM.AbstractACPModel, n::Int,  f_bus, t_bus, f_idx, t_idx, r, p, total_cond)
    i_dc_fr = _PM.var(pm, n,  :i_dcgrid, f_idx)
    i_dc_to = _PM.var(pm, n,  :i_dcgrid, t_idx)
    vmdc_fr = _PM.var(pm, n,  :vdcm, f_bus)
    vmdc_to = _PM.var(pm, n,  :vdcm, t_bus)

    bus_arcs_dcgrid_cond = _PM.ref(pm, n, :bus_arcs_dcgrid_cond)

    # for c = 1: total_cond
    #     if r[c] == 0
    #         JuMP.@constraint(pm.model, p_dc_fr[c] + p_dc_to[c] == 0)
    #     else
            # g = 1 / r[c]
            #doubt about p in following equation
            for k=1:3
                for (line, d) in bus_arcs_dcgrid_cond[(f_bus, k)]
                    if r[d] == 0
                         JuMP.@constraint(pm.model, i_dc_fr[d] + i_dc_to[d] == 0)
                    else
                             g = 1 / r[d]
                             (JuMP.@NLconstraint(pm.model, i_dc_fr[d] ==  g * (vmdc_fr[k] - vmdc_to[k])))
                             (JuMP.@NLconstraint(pm.model, i_dc_to[d] ==  g * (vmdc_to[k] - vmdc_fr[k])))
                        end
                     end
            end

            # JuMP.@NLconstraint(pm.model, p_dc_fr[c] ==  g * vmdc_fr[c] * (vmdc_fr[c] - vmdc_to[c]))
            # JuMP.@NLconstraint(pm.model, p_dc_to[c] ==  g * vmdc_to[c] * (vmdc_to[c] - vmdc_fr[c]))
        # end
    # end
end




"`vdc[i] == vdcm`"
function constraint_dc_voltage_magnitude_setpoint(pm::_PM.AbstractACPModel, n::Int,  i)

         conv = _PM.ref(pm, n, :convdc, i)
         dc_bus=_PM.ref(pm, n, :convdc,i)["busdc_i"]
         v = _PM.var(pm, n,  :vdcm, dc_bus)

        bus_convs_dc_cond =  _PM.ref(pm, n, :bus_convs_dc_cond)
        # total_cond = _PM.ref(pm, n, :busdc,i)["conductors"]
        # following loop, only for k in 1:2, because k=3's voltage can not be set #(no more valid)
         for k in 1:2
            for (c,d) in bus_convs_dc_cond[(dc_bus, k)]
                if c==i
                    # display(conv["Vdcset"])
                    # display("values of d is $d ")
                    (JuMP.@constraint(pm.model, v[k] == conv["Vdcset"][d]))
                    # display(JuMP.@constraint(pm.model, pconv_dc[c][d]==iconv_dc[c][d]*vdcm))
                end
            end
        end

end

function constraint_dc_branch_current(pm::_PM.AbstractACPModel, n::Int,  f_bus, f_idx, ccm_max, p)
# do nothing
end

############## TNEP constraints ###############
"""
```
sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne) == sum(pg[g] for g in bus_gens)  - pd - gs*v^2
sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac) + sum(qconv_grid_ac_ne[c] for c in bus_convs_ac_ne) == sum(qg[g] for g in bus_gens)  - qd + bs*v^2
```
"""
function constraint_kcl_shunt_ne(pm::_PM.AbstractACPModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, pd, qd, gs, bs)
    vm = _PM.var(pm, n, :vm, i)
    p = _PM.var(pm, n, :p)
    q = _PM.var(pm, n, :q)
    pg = _PM.var(pm, n, :pg)
    qg = _PM.var(pm, n, :qg)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n, :qconv_tf_fr)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    qconv_grid_ac_ne = _PM.var(pm, n, :qconv_tf_fr_ne)
    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens)  - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*vm^2)
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac) + sum(qconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(qg[g] for g in bus_gens)  - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*vm^2)
end
"""
Creates Ohms constraints for DC branches

```
p[f_idx] == p * g[l] * vmdc[f_bus] * (vmdc[f_bus] - vmdc[t_bus])
```
"""
function constraint_ohms_dc_branch_ne(pm::_PM.AbstractACPModel, n::Int,  f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n, :p_dcgrid_ne, f_idx)
    p_dc_to = _PM.var(pm, n, :p_dcgrid_ne, t_idx)
    vmdc_fr = []
    vmdc_to = []
    z = _PM.var(pm, n, :branch_ne, f_idx[1])
    vmdc_to, vmdc_fr = contraint_ohms_dc_branch_busvoltage_structure(pm, n, f_bus, t_bus, vmdc_to, vmdc_fr)
    if r == 0
        JuMP.@constraint(pm.model, p_dc_fr + p_dc_to == 0)
    else
        g = 1 / r

        JuMP.@NLconstraint(pm.model, p_dc_fr == z * p * g * vmdc_fr * (vmdc_fr - vmdc_to))
        JuMP.@NLconstraint(pm.model, p_dc_to == z * p * g * vmdc_to * (vmdc_to - vmdc_fr))
    end
end
