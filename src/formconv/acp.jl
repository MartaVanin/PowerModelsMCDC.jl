"""
Links converter power & current
```
pconv_ac[i]^2 + pconv_dc[i]^2 == vmc[i]^2 * iconv_ac[i]^2
```
"""
function constraint_converter_current(pm::_PM.AbstractACPModel, n::Int, i::Int, Umax, Imax, cond)
    vmc = _PM.var(pm, n, :vmc, i)[cond]
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)[cond]
    qconv_ac = _PM.var(pm, n, :qconv_ac, i)[cond]
    iconv = _PM.var(pm, n, :iconv_ac, i)[cond]

    JuMP.@NLconstraint(pm.model, pconv_ac^2 + qconv_ac^2 == vmc^2 * iconv^2)
end

"""
Converter transformer constraints
```
p_tf_fr ==  g/(tm^2)*vm_fr^2 + -g/(tm)*vm_fr*vm_to * cos(va_fr-va_to) + -b/(tm)*vm_fr*vm_to*sin(va_fr-va_to)
q_tf_fr == -b/(tm^2)*vm_fr^2 +  b/(tm)*vm_fr*vm_to * cos(va_fr-va_to) + -g/(tm)*vm_fr*vm_to*sin(va_fr-va_to)
p_tf_to ==  g*vm_to^2 + -g/(tm)*vm_to*vm_fr  *    cos(va_to - va_fr)     + -b/(tm)*vm_to*vm_fr    *sin(va_to - va_fr)
q_tf_to == -b*vm_to^2 +  b/(tm)*vm_to*vm_fr  *    cos(va_to - va_fr)     + -g/(tm)*vm_to*vm_fr    *sin(va_to - va_fr)
```
"""
function constraint_conv_transformer(pm::_PM.AbstractACPModel, n::Int, i::Int, rtf, xtf, acbus, tm, transformer, cond)
    ptf_fr = _PM.var(pm, n, :pconv_tf_fr, i)[cond]
    qtf_fr = _PM.var(pm, n, :qconv_tf_fr, i)[cond]
    ptf_to = _PM.var(pm, n, :pconv_tf_to, i)[cond]
    qtf_to = _PM.var(pm, n, :qconv_tf_to, i)[cond]

    vm = _PM.var(pm, n, :vm, acbus)
    va = _PM.var(pm, n, :va, acbus)
    vmf = _PM.var(pm, n, :vmf, i)[cond]
    vaf = _PM.var(pm, n, :vaf, i)[cond]

    ztf = rtf + im * xtf
    if transformer
        ytf = 1 / (rtf + im * xtf)
        gtf = real(ytf)
        btf = imag(ytf)
        gtf_sh = 0
        ac_power_flow_constraints(pm, gtf, btf, gtf_sh, vm, vmf, va, vaf, ptf_fr, ptf_to, qtf_fr, qtf_to, tm)
    else
        JuMP.@constraint(pm.model, ptf_fr + ptf_to == 0)
        JuMP.@constraint(pm.model, qtf_fr + qtf_to == 0)
        JuMP.@constraint(pm.model, va == vaf)
        JuMP.@constraint(pm.model, vm == vmf)
    end
end
"constraints for a voltage magnitude transformer + series impedance"
function ac_power_flow_constraints(pm::_PM.AbstractACPModel, g, b, gsh_fr, vm_fr, vm_to, va_fr, va_to, p_fr, p_to, q_fr, q_to, tm)
    JuMP.@NLconstraint(pm.model, p_fr == g / (tm^2) * vm_fr^2 + -g / (tm) * vm_fr * vm_to * cos(va_fr - va_to) + -b / (tm) * vm_fr * vm_to * sin(va_fr - va_to))
    JuMP.@NLconstraint(pm.model, q_fr == -b / (tm^2) * vm_fr^2 + b / (tm) * vm_fr * vm_to * cos(va_fr - va_to) + -g / (tm) * vm_fr * vm_to * sin(va_fr - va_to))
    JuMP.@NLconstraint(pm.model, p_to == g * vm_to^2 + -g / (tm) * vm_to * vm_fr * cos(va_to - va_fr) + -b / (tm) * vm_to * vm_fr * sin(va_to - va_fr))
    JuMP.@NLconstraint(pm.model, q_to == -b * vm_to^2 + b / (tm) * vm_to * vm_fr * cos(va_to - va_fr) + -g / (tm) * vm_to * vm_fr * sin(va_to - va_fr))
end
"""
Converter reactor constraints
```
-pconv_ac == gc*vmc^2 + -gc*vmc*vmf*cos(vac-vaf) + -bc*vmc*vmf*sin(vac-vaf)
-qconv_ac ==-bc*vmc^2 +  bc*vmc*vmf*cos(vac-vaf) + -gc*vmc*vmf*sin(vac-vaf)
p_pr_fr ==  gc *vmf^2 + -gc *vmf*vmc*cos(vaf - vac) + -bc *vmf*vmc*sin(vaf - vac)
q_pr_fr == -bc *vmf^2 +  bc *vmf*vmc*cos(vaf - vac) + -gc *vmf*vmc*sin(vaf - vac)
```
"""
function constraint_conv_reactor(pm::_PM.AbstractACPModel, n::Int, i::Int, rc, xc, reactor, cond)
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)[cond]
    qconv_ac = _PM.var(pm, n, :qconv_ac, i)[cond]
    ppr_fr = _PM.var(pm, n, :pconv_pr_fr, i)[cond]
    qpr_fr = _PM.var(pm, n, :qconv_pr_fr, i)[cond]

    vmf = _PM.var(pm, n, :vmf, i)[cond]
    vaf = _PM.var(pm, n, :vaf, i)[cond]
    vmc = _PM.var(pm, n, :vmc, i)[cond]
    vac = _PM.var(pm, n, :vac, i)[cond]

    zc = rc + im * xc
    if reactor
        yc = 1 / (zc)
        gc = real(yc)
        bc = imag(yc)
        JuMP.@NLconstraint(pm.model, -pconv_ac == gc * vmc^2 + -gc * vmc * vmf * cos(vac - vaf) + -bc * vmc * vmf * sin(vac - vaf))
        JuMP.@NLconstraint(pm.model, -qconv_ac == -bc * vmc^2 + bc * vmc * vmf * cos(vac - vaf) + -gc * vmc * vmf * sin(vac - vaf))
        JuMP.@NLconstraint(pm.model, ppr_fr == gc * vmf^2 + -gc * vmf * vmc * cos(vaf - vac) + -bc * vmf * vmc * sin(vaf - vac))
        JuMP.@NLconstraint(pm.model, qpr_fr == -bc * vmf^2 + bc * vmf * vmc * cos(vaf - vac) + -gc * vmf * vmc * sin(vaf - vac))
    else
        ppr_to = -pconv_ac
        qpr_to = -qconv_ac
        JuMP.@constraint(pm.model, ppr_fr + ppr_to == 0)
        JuMP.@constraint(pm.model, qpr_fr + qpr_to == 0)
        JuMP.@constraint(pm.model, vac == vaf)
        JuMP.@constraint(pm.model, vmc == vmf)

    end
end
"""
Converter filter constraints
```
ppr_fr + ptf_to == 0
qpr_fr + qtf_to +  (-bv) * filter *vmf^2 == 0
```
"""
function constraint_conv_filter(pm::_PM.AbstractACPModel, n::Int, i::Int, bv, filter, cond)
    ppr_fr = _PM.var(pm, n, :pconv_pr_fr, i)[cond]
    qpr_fr = _PM.var(pm, n, :qconv_pr_fr, i)[cond]
    ptf_to = _PM.var(pm, n, :pconv_tf_to, i)[cond]
    qtf_to = _PM.var(pm, n, :qconv_tf_to, i)[cond]

    vmf = _PM.var(pm, n, :vmf, i)[cond]

    JuMP.@constraint(pm.model, ppr_fr + ptf_to == 0)
    JuMP.@NLconstraint(pm.model, qpr_fr + qtf_to + (-bv) * filter * vmf^2 == 0)
end