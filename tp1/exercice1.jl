using JuMP
using CPLEX

"""
include("./tp1/exercice1.jl")
moviesBenders(1000)
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

function subProblem(y_val::Vector{Float64}, w_val::Float64, n::Int64, c::Vector{Int64}, d::Int64)::Tuple{Float64, Vector{Float64}, Float64, Float64}
    # Creating the model
    sub_model = Model(CPLEX.Optimizer)
    set_silent(sub_model)

    ##### Variables #####
    @variable(sub_model, v[i in 1:n,] >= 0.)
    @variable(sub_model, b)

    ##### Objective #####
    @objective(sub_model, Max, d*b - sum(y_val[i] * v[i] for i in 1:n))
    
    ##### Constraints #####
    for i in 1:n
        if y_val[i] == 0
             @constraint(sub_model, b - v[i] == c[i])
        else
             @constraint(sub_model, b - v[i] <= c[i])
        end
    end
    
    optimize!(sub_model)
    feasibleSolutionFound = primal_status(sub_model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(sub_model) == MOI.OPTIMAL
    if !(feasibleSolutionFound && isOptimal)
        println("Optimal not found in subproblem")
    end
    return JuMP.objective_value(sub_model), JuMP.value.(v), JuMP.value(b), JuMP.solve_time(sub_model)
end


function moviesBenders(n::Int64=-1, showResult::Bool= false, silent::Bool=true, timeLimit::Float64=-1.0)::Any
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
    @variable(model, w >= 0.)

    ##### Objective #####
    @objective(model, Min, sum(f[i]*y[i] for i in 1:n) + w)
    
    ##### Constraints #####
    # Constraint on y
    @constraint(model, y[1] >= y[2])
    @constraint(model, y[1] >= y[3])
    @constraint(model, (d - sum(y[i] for i in 1:n)) <= 0)

    hasAddedConstraint = true
    runTime = 0
    while hasAddedConstraint
        hasAddedConstraint = false
        # Solve current state

        # Benders
        optimize!(model)
        feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
        isOptimal = termination_status(model) == MOI.OPTIMAL
        runTime += JuMP.solve_time(model)

        if feasibleSolutionFound
            value = JuMP.objective_value(model)
            # Solve sub problems with current optimum
            w_val = JuMP.value.(w)
            y_val = JuMP.value.(y)
            if showResult && !silent
                println("Current value ", value, " w ", w_val, " y ", y_val)
            end
            subVal, v, b, subTime= subProblem(y_val, w_val, n, c, d)
            runTime += subTime
            if subVal > (w_val + 1e-5)
                if !silent
                    println("Subproblem value ", subVal)
                    println("Adding optimality cut")
                end
                @constraint(model, w >= d * b - sum(y[i] * v[i] for i in 1:n))
                hasAddedConstraint = true
            end
        else
            break
        end

    end

    ### Display the solution
    feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(model) == MOI.OPTIMAL
    if feasibleSolutionFound && isOptimal
        # Il faut checker si on a encore des plans non valides
        value = JuMP.objective_value(model)
        # Solve sub problems with current optimum
        w_val = JuMP.value.(w)
        y_val = JuMP.value.(y)
        if showResult
            println()
            println("Results : ")
            println("Value : ", value, " Time ", runTime, "s.")
        end

        return isOptimal, value, runTime
    else
        println("Not feasible!!")
        return
    end


end