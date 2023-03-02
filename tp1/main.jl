using DataFrames
using CSV

include("./exercice1.jl")
include("./exercice2.jl")
include("./exercice3.jl")
include("./exercice4.jl")
include("./exercice5.jl")
include("./constants.jl")

"""
include("./tp1/main.jl")
solveAll()
"""

function runInstanceAndUpdateDataframe(currentResults::DataFrame, size::Int64, rowToReplace::Union{Int, Nothing}=nothing)::Bool
    println("Solving sze " * string(size))
    # Ex 1
    result = moviesBenders(size)
    if result == nothing
        println("NOT FEASIBLE for ex1!!")
        return false
    else
        cutsOptimal, cutsValue, cutsTime = result
    end

    # Ex 2
    result = moviesBase(size)
    if result == nothing
        println("NOT FEASIBLE for ex2!!")
        return false
    else
        baseValue, baseTime = result
    end

    # Ex 3
    result = moviesCPLEX(size)
    if result == nothing
        println("NOT FEASIBLE for ex3!!")
        return false
    else
        cplexValue, cplexTime = result
    end

    # Ex 4
    result = moviesBendersDValue(size)
    if result == nothing
        println("NOT FEASIBLE for ex4!!")
        return false
    else
        cutsWithDValue, cutsWithDTime = result
    end

    # Ex 5
    if size > 10000
        result = moviesBendersDValueGurobi(size)
        if result == nothing
            println("NOT FEASIBLE for ex5!!")
            return false
        else
            gurobiCutsWithDValue, gurobiCutsWithDTime = result
        end
    else
        gurobiCutsWithDTime = -1.
    end
    # Modify dataframe
    if rowToReplace == nothing
        rowToReplace = findfirst(==(size), currentResults.size)
        if rowToReplace == nothing
            println("Pushing new row to results dataframe")
            push!(currentResults, [size cutsOptimal cutsValue cutsTime baseTime cplexTime cutsWithDTime gurobiCutsWithDTime])
            return true
        else
            currentRow= currentResults[rowToReplace,:]
            currentResults[rowToReplace,:] = [size cutsOptimal cutsValue cutsTime baseTime cplexTime cutsWithDTime gurobiCutsWithDTime]
            return true
        end
    else
        currentRow = currentResults[rowToReplace,:]
        println("Improved value for " * size)
        currentResults[rowToReplace,:] = [size cutsOptimal cutsValue cutsTime baseTime cplexTime cutsWithDTime gurobiCutsWithDTime]
        return true
    end
    return false
end

function solveAll(resultFile::String=RESULTS_FILE)::Nothing
    # Loading
    filePath =RESULTS_DIR_PATH * "\\" * resultFile * ".csv"
    # Get unoptimal instance
    if !isfile(filePath)
        currentResults = DataFrame(size=Int64[], optimal=Bool[], value_cuts =Float64[]
                        , cutsTime =Float64[], baseTime  =Float64[], cplexTime =Float64[],
                         cutsWithDTime =Float64[], gurobiCutsWithDTime =Float64[])
    else
        currentResults = DataFrame(CSV.File(filePath))
    end

    # Run
    for size in vcat([10, 100], [1000*i for i=1:5:50])
        updatedDf = runInstanceAndUpdateDataframe(currentResults, size)
        if updatedDf
            CSV.write(filePath, currentResults, delim=";")
        end
    end
    return 
end