function readGraph(file)
    if (!isfile(file))
        println("Je ne trouve pas le fichier")
        return
    end
    myFile=open(file)
    data=readlines(myFile)
    global n=parse(Int,data[1])
    global m=parse(Int,data[2])
    global adj=zeros(n,n)       #matrice d'adjacene
    global demande=zeros(n)     #demande
    for i in 3:3+m-1
        line=split(data[i]," ")
        u=parse(Int,line[1])
        #println("u : ",u+1)
        v=parse(Int,line[2])
        #println("v : ", v+1)
        adj[u+1,v+1]=1
        adj[v+1,u+1]=1
    end
    for i in 3+m:3+m+n-1
        line=split(data[i]," ")
        u=parse(Int,line[1])
        #println("u : ",u+1)
        d=parse(Int,line[2])
        #println("d: ",d)
        demande[u+1]=d
    end
end
readGraph("benders2.txt")
