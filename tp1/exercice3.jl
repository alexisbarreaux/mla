using JuMP
using CPLEX

"""
include("./tp1/exercice3.jl")
moviesCPLEX(100)
"""

function loadData(n::Int)
    d = div( n, 2 )
    f = zeros(Int,n)
    c =zeros(Int,n)
    f[1] = 7
    c[1] = 8
    for i in 2:n
        f[i] = f[i-1]*f[1] % 159
        c[i] = c[i-1]*c[1] % 61
    end
    return n, d, f, c
end

function moviesCPLEX(n::Int64=-1; showResult::Bool= false, silent::Bool=true, timeLimit::Float64=-1.0)::Any
    if n < 0
        n=5 # Nb vars
        f =[7 , 2 , 2 , 7 , 7]
        c=[1000, 5 , 4 , 3 , 2]
        d =3
    else
        n,d,f,c = loadData(n)
    end

    # Creating the model
    model = Model(CPLEX.Optimizer)
    if silent
        set_silent(model)
    end
    if timeLimit >= 0
        set_time_limit_sec(model, timeLimit)
    end

    ##### Variables #####
    @variable(model, y[i in 1:n], Bin)
    @variable(model, x[i in 1:n] >= 0.)
    set_optimizer_attribute(model, "CPXPARAM_Benders_Strategy", 3)

    ##### Objective #####
    @objective(model, Min, sum(f[i]*y[i] + c[i]*x[i] for i in 1:n))
    
    ##### Constraints #####
    # Constraint on y
    @constraint(model, y[1] >= y[2])
    @constraint(model, y[1] >= y[3])
    @constraint(model, [i in 1:n], x[i] <= y[i])
    @constraint(model, sum(x[i] for i in 1:n) == d)

    
    ### Display the solution
    optimize!(model)
    feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(model) == MOI.OPTIMAL
    if feasibleSolutionFound
        # Il faut checker si on a encore des plans non valides
        value = JuMP.objective_value(model)
        # Solve sub problems with current optimum
        x_val = JuMP.value.(x)
        y_val = JuMP.value.(y)

        if showResult
            println()
            println("Results : ")
            println("Value : ", value, " Time ", time, "s.")
        end
        time = round(JuMP.solve_time(model), digits= 5)
        """
        println(JuMP.relative_gap(model))
        println(JuMP.objective_bound(model))
        println(value)
        """
        return value, time
    else
        println("Not feasible!!")
        return
    end


end