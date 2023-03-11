using JuMP
using CPLEX
using Graphs

include("./instances/exemple-lecture-graphe.jl")
"""
include("./tp2/exercice3.jl")
readGraph("./tp2/instances/benders-graphe-hexagone.txt")
linksBendersDijkstra("benders-graphe-hexagone")
"""

function linksBendersDijkstra(inputFile::String="benders-graphe-hexagone"; showResult::Bool= false,
     timeLimit::Float64=-1.0, bnd::Int64=1)::Any
    start = time()
    readGraph("./tp2/instances/"*inputFile*".txt")

    # Build graph
    graph = Graph(n)

    for i in 1:n
        for j in (i + 1):n
            if adj[i,j] > 0.0
                add_edge!(graph, i, j)
            end
        end
    end
    # Get shortests paths
    source_paths = dijkstra_shortest_paths(graph, 1)
    paths= enumerate_paths(source_paths)

    return sum([demande[i]*(length(paths[i]) - 1) for i in 2:n]), time() - start
end