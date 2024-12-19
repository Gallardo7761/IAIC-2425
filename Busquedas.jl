using Pkg
Pkg.activate(".")
#Pkg.instantiate()

# Función auxiliar para borrar la terminal REPL
function clc()
    if Sys.iswindows()
        return read(run(`powershell cls`), String)
    elseif Sys.isunix()
        return read(run(`clear`), String)
    elseif Sys.islinux()
        return read(run(`printf "\033c"`), String)
    end
end

# Búsquedas en Espacios de Estados
# ================================

#= 
Carga de librerías

Para este tema se ha preparado un módulo propio llamado `Search` ("Search.jl")
que tiene definidas las estructuras y funciones necesarias para las Búsque-
das en Espacios de Estados. Concretamente, el módulo ofrece 4 algoritmos de 
búsqueda:
* BFS (`BFS`)
* DFS (`DFS`)
* DFS iterado (`iterative_DFS`)
* A* (`astar`)
y varias utilidades y funciones adicionales (para heurísticas, por ejemplo).
=#

using Plots # Para representación de funciones
include("./lib/Search.jl")

#=
#################################
Problema Básico
#################################

Usando solo las operaciones específicas: 
- multiplicar por 3, 
- sumar 7, o 
- restar 2, 

queremos encontrar una forma de alcanzar un número objetivo prefijado comenzando 
por un número inicial. Solo se permite trabajar con números positivos.

Es un ejemplo sencillo, podemos definir todo lo que necesitamos (estados, suce-
sores) en un bloque.

Los estados son simplemente números por lo que no tenemos que definir una es-
tructura específica para ellos (en otros casos, hemos de prepararla explícita-
mente).

No queda claro cuál podría ser una heurística, así que vamos a usar BFS y DFS 
iterado, no A* (ni DFS, que fácilmente nos llevaría a caminos infinitos). 
=#

sucesores(n) = n > 2 ? [3n, n+7, n-2] : [3n, n+7]

# Vamos a hacer una prueba acotando el número de pasos a 10 e intentando llegar 
# del 2 al 159:

solBFS = BFS(sucesores, 2, 159)
solIDFS = iterative_DFS(sucesores, 2, 159)
solDFS = DFS(sucesores, 2, 159; maxdepth=5)

#=
Las tres funciones anteriores devuelven el mismo tipo de estructura:
struct UISResult{TState}
    status::Symbol          # :success, :timeout, :nopath
    path::Vector{TState}    # Camino de estados devuelto
    closedsetsize::Int64    # Nº de estados que han sido comprobados
    opensetsize::Int64      # Nº de estados construidos pero sin comprobar
end

Vamos a preparar una función para sacarle partido:
=#

function ResumeSol(sol, metodo)
    if sol.status == :success
        println("-----------------------------------")
        println("La búsqueda con $metodo ha sido exitosa. El camino encontrado es\n")
        println("$(sol.path), con $(length(sol.path)) estados.\n")
        println("Durante la búsqueda, se han visitado $(sol.closedsetsize) nodos, que se han cerrado,\ny otros $(sol.opensetsize) que se han quedado abiertos.")
        println("-----------------------------------")
    else
        println("La búsqueda con $metodo no ha dado resultado")
    end
end

ResumeSol(solBFS, "BFS")
ResumeSol(solIDFS, "DFS Iterado")
ResumeSol(solDFS, "DFS")

#=
#################################
Collatz
#################################

Un pequeño puzzle inspirado en la conjetura de Collatz: llegar hasta el 1 usando 
las operaciones n÷2 o 3n+1 de forma iterada (la diferencia con la verdadera con-
jetura es que podremos usar la operación 3n+1 para cualquier número, indepen-
dientemente de que sea par o impar).

Es un ejemplo sencillo, podemos definir todo lo que necesitamos (estados, suce-
sores, heurística) en un bloque:

Al igual que en el ejemplo anterior, los estados son simplemente números por lo 
que no tenemos que definir una estructura específica para ellos. 
=#

sucesoresCollatz(n) = n % 2 == 0 ? [n ÷ 2, 3n + 1] : [3n + 1]

#=
Para la heurística, hemos de tener que cuenta que el mejor caso se tiene cuan-
do el número inicial es una potencia de 2, porque de esa forma basta dar log2(n) 
pasos ya que podemos usar siempre la operación $n ÷ 2$. Si no estamos en ese ca-
so, log2(n) se convierte en una heurística muy optimista
=# 

heuristic(n, goal) = floor(Int64, log2(n))

# Test 1: Búsqueda Trivial
# Comenzamos haciendo algunas búsquedas sencillas con algunos empieces no muy 
# alejados.

solastar = astar(sucesoresCollatz, 12, 1; heuristic)
solBFS = BFS(sucesoresCollatz, 12, 1)

ResumeSol(solastar, "A*")
println("Coste del camino: $(solastar.cost)")
ResumeSol(solBFS,"BFS")
# Vamos a hacer una prueba acotando el número de pasos a 5, comenzando por 12.

solastar5 = astar(sucesoresCollatz, 12, 1; heuristic, maxcost=5)
ResumeSol(solastar5,"A*")

# Test 2: Comparativa del coste de A* y BFS
# Vamos a ver cómo varía el proceso de encontrar el camino para cada estado ini-
# cial por debajo de 100. Vamos a analizar dos valores asociados:
    # 1. Coste del camino encontrado.
    # 2. Cantidad de memoria utilizada (número de nodos abiertos+cerrados).

# ⚠ Ten cuidado, porque aunque los 100 primeros los calcula en unos pocos segun-
# dos, el tiempo de ejecución se incrementa rápidamente para algunos estados 
# iniciales, así que para calcular los 120 primeros el tiempo necesario se sitúa 
# ya en varios minutos.

# Vamos a usar la librería Plots para dar una representación gráfica de la evo-
# lución de estos valores. Observa que el cálculo de los caminos lo hacemos una 
# sola vez en `experimento`, y posteriormente usamos los datos almacenados en 
# los distintos campos de esa variable para mostrar el coste, y el número de es-
# tados.

x = 1:100
experimento_astar = @time [astar(sucesoresCollatz, i, 1;heuristic) for i in x];
experimento_bfs = @time [BFS(sucesoresCollatz, i, 1) for i in x];
# plot(
#       x,                  # 👀 x e y son vectores de datos
#       y,                  # (idealmente, del mismo tamaño)
#       title = "...",      # Título de la gráfica
#       xlabel = "...",     # Etiqueta en el eje X
#       ylabel = "...",     # Etiqueta en el eje Y
#       linewidth = k)      # Grosor de la línea de dibujado

# Podemos intentar analizar cómo evoluciona el coste del mejor camino en 
# función del dato de entrada
plot(
    x,
    getfield.(experimento_astar,:cost), # 👀 aplica cost a cada elemento de 
                                        # experimento_astar
    title = "Coste del camino encontrado", 
    label = "Coste",
    xlabel = "Valor inicial", 
    ylabel = "Coste", 
    linewidth = 2) 

# O cómo evoluciona la memoria total usada para calcular el mejor camino en 
# función del dato de entrada
y_star = [p.closedsetsize + p.opensetsize for p in experimento_astar]
y_bfs = (p -> (p.closedsetsize + p.opensetsize)).(experimento_bfs)
plot(
    x,
    [y_star y_bfs],
    title = "Nº nodos usados", 
    label = ["A*" "BFS"],
    xlabel = "Valor inicial", 
    ylabel = "Nº Nodos", 
    linewidth = 2)

#= 
#################################
Problema de las 2 Jarras
#################################

Se tienen dos jarras de agua, una de 3 litros y otra de 4 litros sin escala de 
medición. Se desea obtener 2 litros de agua en la jarra de 4 litros. Las opera-
ciones válidas son: 
- llenar completamente cada una de las jarras, 
- vacíar completamente una de las jarras, 
- pasar agua de una jarra a otra (hasta que la primera se vacía o la segunda se 
  llena). 
=#

# Los estados vendrán dados por un vector de componentes s = [j1,j2],
# donde j1 es el contenido de la Jarra 1, y j2 el de la Jarra 2

# La función sucesores calcula el conjunto de estados sucesores válidos
function sucesoresJarras(s)
    res = [
            [s[1],0],  # Vaciar J2
            [0,s[2]],  # Vaciar J1
            [s[1],4],  # Llenar J2
            [3,s[2]]   # LLenar J1
    ]
    if s[1] > 0 && s[2] < 4
        trasvase = min(s[1], 4-s[2])
        push!(res,[s[1]-trasvase, s[2]+trasvase]) # Pasar de J1 a J2
    end
    if s[2] > 0 && s[1] < 3
        trasvase = min(s[2], 3-s[1])
        push!(res,[s[1]+trasvase, s[2]-trasvase]) # Pasar de J2 a J1
    end
    return res
end

function final(s,g)
    s[2] == 2
end

solJarras = BFS(sucesoresJarras, [0,0], false; isgoal=final)
ResumeSol(solJarras, "BFS")

#= 
#################################
Misioneros y Caníbales
#################################

Hay 3 misioneros y 3 caníbales a la orilla de un río. Tienen una canoa con capa-
cidad para dos personas como máximo. Se desea que los seis crucen el río, pero 
hay que considerar que no debe haber más caníbales que misioneros en ningún si-
tio porque entonces los caníbales se comerían a los misioneros. Además, la canoa 
siempre debe ser conducida por alguien (no puede cruzar el río sola). =#

# Estados: (misioneros_izq, canibales_izq, pos_barca)
# 	misioneros_der = 3 - misioneros_izq
# 	misioneros_izq = 3 - misioneros_der
# 	pos_barca = -1 (izquierda) | 1 (derecha)

function mover(s, mv)
    mi, ci, b = s
    m, c = mv
    return (mi + b * m, ci + b * c, -b)
end

function valido(s)
    m, c = s
    return (m >= c || m == 0) && (3 - m >= 3 - c || m == 3)
end

function sucesoresMisioneros(s)
    res = []
    # Posibles traslados (max 2 personas en la barca) en cualquier dirección
    moves = [(m, c) for m in 0:2 for c in 0:2 if 1 <= m + c <= 2]
    for mv in moves
        s1 = mover(s, mv)  # Aplicación del movimiento mv
        # Comprobación de que el estado es válido
        if valido(s1)
            push!(res, s1)
        end
    end
    return res
end
                    
solMis = BFS(sucesoresMisioneros, (3,3,-1), (0,0,1))
ResumeSol(solMis,"BFS")
#= 
#################################
El Granjero
#################################

Un granjero va al mercado y compra un lobo, una oveja y una col. Para volver a 
su casa tiene que cruzar un río. El granjero dispone de una barca para cruzar a 
la otra orilla, pero en la barca solo caben él y una de sus compras. Si el lobo 
se queda solo con la oveja, se la come, si la oveja se queda sola con la col, se 
la come. El reto del granjero es cruzar el río con todas sus compras. 

 	Estado: [p_granjero, p_lobo, p_oveja, p_col], posiciones de cada objeto
 		1  = derecha
 		-1 = izquierda
=#

# Pasar un objeto de un lado a otro
function mover_gr(s, obj) # obj ∈ 1:4
    s1 = copy(s)
    if s[obj] == s[1]
        s1[obj] = -s[obj]
        s1[1] = -s[1]
    end
    return s1	
end

function valido_gr(s)
    g, l, o, c = s
    return (l != o || g == l) && (o != c || g == o)
end

function sucesoresGranjero(s)
    res = []
    objs = 1:4
    for obj in objs
        s1 = mover_gr(s, obj)
        if valido_gr(s1)
            push!(res, s1)
        end
    end
    return res
end
                    
solGr = BFS(sucesoresGranjero, [-1,-1,-1,-1], [1,1,1,1])
ResumeSol(solGr,"BFS")

#= 
#################################
Cuadrados Mágicos
#################################

Un cuadrado mágico consiste en una distribución de números en filas y columnas, 
formando un cuadrado, de forma que los números de cada fila, columna y diagonal 
suman lo mismo. Aunque es posible recrear diferentes tipos de cuadrados mágicos, 
tradicionalmente se forman con los números naturales desde el 1 hasta n^2, donde 
$n$ es el lado del cuadrado. Representa el problema de generación automática de 
cuadrados mágicos de tamaño n como un problema de espacio de estados.

**Ayuda**: Ten en cuenta que en este problema el objetivo será navegar por esta-
dos que no son mágicos hasta llegar a uno que sí lo sea. No hay una única opción 
para representar este problema correctamente, pero sí hay representaciones que 
no facilitarían la generación de cuadrados mágicos (por lo que serían incorrec-
tas). A diferencia de los problemas anteriores, en este problema (y en otros que 
veremos a continuación) no hay transiciones naturales que van implícitas en el 
propio problema. 
=#

# Estados: Matrices NxN

# Las posibles sucesores se consiguen intercambiando 2 elementos cualesquiera 
# del estado
function sucesores_cm(s)
    res = []
    N = size(s)[1]
    intercambios = [(x,y,x1,y1) for x in 1:N for y in 1:N for x1 in (x+1):N for y1 in 1:N]
    for (x,y,x1,y1) in intercambios
        s1 = deepcopy(s)
        s1[x, y], s1[x1, y1] = s1[x1, y1], s1[x, y]
        push!(res,s1)
    end
    return res
end

# Predicado para determinar si s es un objetivo (filas, columnas y diagonales 
# suman lo mismo)
function isgoal(s,g)
    N = size(s)[1]
    correct = (sum(1:(N^2))) / N  # suma correcta de filas, columnas,...
    # Filas
    for f in 1:N
        if sum(s[f,:]) != correct
            return false
        end
    end
    # Columnas
    for c in 1:N
        if sum(s[:,c]) != correct
            return false
        end
    end
    # Diagonales
    if sum([s[i,i] for i in 1:N]) != correct || sum([s[i,N-i+1] for i in 1:N]) != correct
        return false
    end
    return true
end

# Definimos como heurística la media de los errores cometidos en filas y 
# columnas
function h(s, goal)
    N = size(s)[1]
    correct = (sum(1:(N^2))) / N
    sumas = []
    #filas
    for f in 1:N
        push!(sumas,abs(sum(s[f,:])-correct))
    end
    #columnas
    for c in 1:N
        push!(sumas,abs(sum(s[:,c])-correct))
    end
    sum(sumas)/length(sumas)
end

# Genera una matriz ordenada como estado inicial
function generaCuadrado(n)
    return Matrix(reshape(1:(n^2),(n,n)))
end

# Test 1: Para tamaño 3, se nota ya diferencia usando h=0
g = generaCuadrado(3)
sol1 = @time astar(sucesores_cm, g,[];isgoal=isgoal)
sol2 = @time astar(sucesores_cm, g,[];isgoal=isgoal, heuristic=h)
display(sol1.path[end])
display(sol2.path[end])

# Test 2: Para tamaño 4, la diferencia es mucho más apreciable
g = generaCuadrado(4)
sol1 = @time astar(sucesores_cm, g,[];isgoal=isgoal, timeout=10)
sol2 = @time astar(sucesores_cm, g,[];isgoal=isgoal, heuristic=h, timeout=10)
display(sol2.path[end])

# Cuidado con tamaños mayores!

#= 
#################################
Problema de las $N$ reinas
#################################

Sitúar N reinas en un tablero de ajedrez de tamaño N×N sin que se amenacen entre 
sí. Dos reinas se amenazan si están en la misma fila, columna o diagonal. El 
caso más común es el de N=8, el trablero de ajedrez estándar. 
=#

# Estados [n_1,...n_N]: n_i es la altura/fila de la reina que está en la columna 
#   i, así que se distribuye una reina en cada columna

# Los sucesores de un estado consisten en cambiar una de las reinas un paso 
# arriba o abajo

function sucesores_Nr(s)
    res = []
    N = size(s)[1]
    for i in 1:N
        for j in [-1,1]
            s1=copy(s)
            s1[i] = s1[i] + j
            if 1 <= s1[i] <= N
                push!(res,s1)
            end
        end
    end
    return res
end


# En el estado s, se amenazan las reinas i y j?
function amenaza(s, i, j)
    return (s[i] == s[j] || abs(s[i]-s[j]) == abs(i-j)) ? 1 : 0
end

# Número de amenazas de un estado (solo se cuenta una vez cada amenaza)
function num_amenazas(s)
    N = size(s)[1]
    return sum([amenaza(s,i,j) for i in 1:(N-1) for j in (i+1):N])
end



# Un estado es solución si no tiene amenazas
function isgoal_nr(s,g)
    return num_amenazas(s) == 0
end

# Podemos usar el número de amenazas como una heurística (aunque no sabemos si 
# es admisible ni consistente)
function h_Nr(s,g)
    return num_amenazas(s)
end

reinas4_1 = @time astar(sucesores_Nr,collect(1:4),false;isgoal=isgoal_nr)
reinas4_2 = @time astar(sucesores_Nr,collect(1:4),false;isgoal=isgoal_nr, heuristic=h_Nr)
ResumeSol(reinas4_1, "A*")
ResumeSol(reinas4_2, "A*")


reinas6_1 = @time astar(sucesores_Nr,collect(1:6),false;isgoal=isgoal_nr)
reinas6_2 = @time astar(sucesores_Nr,collect(1:6),false;isgoal=isgoal_nr, heuristic=h_Nr)
ResumeSol(reinas6_1, "A*")
ResumeSol(reinas6_2, "A*")

reinas6_IDFS = @time iterative_DFS(sucesores_Nr, collect(1:6), false; isgoal=isgoal_nr, maxdepth=30)
ResumeSol(reinas6_IDFS, "I_DFS")

reinas8_1 = @time astar(sucesores_Nr,collect(1:8),false;isgoal=isgoal_nr, timeout=10)
reinas8_2 = @time astar(sucesores_Nr,collect(1:8),false;isgoal=isgoal_nr, heuristic=h_Nr, timeout=20)
ResumeSol(reinas8_1, "A*")
ResumeSol(reinas8_2, "A*")

## Funciones para representar el tablero
# Función para generar una celda cuadrada en la posición (i, j)

function celda(i, j, w=1)
    x = [i, i+w, i+w, i, i]
    y = [j, j, j+w, j+w, j]
    Shape(x, y)
end

function dibuja_tablero(N)
    p = plot(aspect_ratio=:equal, legend=false, fillalpha=0.5)

    for i in 1:N
        for j in 1:N
            if mod(i + j, 2) == 0
                plot!(celda(i, j), fillcolor=:black, linecolor=:black)
            else
                plot!(celda(i, j), fillcolor=:white, linecolor=:black)
            end
        end
    end

    # Mostrar el gráfico
    p
end

function dibuja_reinas(pos)
    p = dibuja_tablero(length(pos))
    i = 1
    for j in pos
        annotate!(i+.5,j+.5,text("♛", :red, 20, :center))
        i = i + 1
    end
    return p
end

dibuja_reinas(reinas6_2.path[end])

#=
#################################
Laberinto
#################################

Tenemos un laberinto, representado por medio de una matriz de 0/1 (0: libre, 
1: obstáculo), y comenzando por una casilla de la matriz hemos de alcanzar otra
dando el menor número de pasos.
=#

lab = [
    0 1 0 0 0
    0 1 0 1 0
    0 0 0 1 0
    1 1 0 1 0
    0 0 0 1 0
]

## Funciones para representar el laberinto
# Función para generar una celda cuadrada en la posición (i, j)

function dibuja_lab(lab)
    # Graficar el laberinto
    p = plot(aspect_ratio=:equal, legend=false, fillalpha=0.5)

    for i in 1:size(lab)[1]
        for j in 1:size(lab)[2]
            if lab[i, j] == 1
                plot!(celda(i, j), fillcolor=:black, linecolor=:black)
            else
                plot!(celda(i, j), fillcolor=:white, linecolor=:black)
            end
        end
    end

    # Mostrar el gráfico
    p
end

dibuja_lab(lab)

# Función para generar vecinos válidos (arriba, abajo, izquierda, derecha)
function vecinos(pos)
    x, y = pos
    movs_posibles = [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]
    return [p for p in movs_posibles if valido(p)]
end

# Verifica si la posición es válida (dentro de los límites y no una pared)
function valido(pos)
    x, y = pos
    return 0 < x <= size(lab, 1) && 0 < y <= size(lab, 2) && lab[x, y] == 0
end

# Heurística de distancia Manhattan
function heur_manhattan(s, g)
    x1, y1 = s
    x2, y2 = g
    return abs(x1 - x2) + abs(y1 - y2)
end

# Coste uniforme de 1 por cada movimiento
function coste_mov(s1, s2)
    return 1
end

# Estado inicial y objetivo
inicio = (1, 1)   # Posición inicial
meta = (5, 5)    # Posición objetivo

# Llamada al algoritmo A*
sol = astar(vecinos, inicio, meta; heuristic = heur_manhattan, cost = coste_mov)

# Representación solución

function dibuja_sol(sol)
    # Se parte del laberinto sin resolver
    dibuja_lab(lab)
    # Se dibuja encima la celda de salida (anotada)
    i, j = sol.path[1]
    plot!(celda(i, j), fillcolor = :green, linecolor = :black)
    annotate!(i+.5,j+.5,text("Inicio", :black, 12, :center))
    # Se añaden las celdas interiores del camino solución
    k = 1
    for cel in sol.path[2:end-1]
        i, j = cel
        plot!(celda(i, j), fillcolor = :yellow, linecolor = :black)
        annotate!(i+.5,j+.5,text(k, :black, 12, :center))
        k = k + 1
    end
    # Se dibuja encima la celda de llegada (anotada)
    i, j = sol.path[end]
    plot!(celda(i, j), fillcolor = :red, linecolor = :black)
    annotate!(i+.5,j+.5,text("Fin", :black, 12, :center))
end

dibuja_sol(sol)

#=
######################################
Caminos mínimos en Grafos Geométricos
######################################

Dado un grafo ponderado (con pesos en las aristas), encontrar el camino mínimo
entre dos de sus vértices. Vamos a suponer que el grafo está inmerso en R^2.
=#

# Nodos del Grafo y aristas ponderadas. Se da como lista de adyacencias.

G = Dict(
    1 => [2, 3, 4],
    2 => [1, 3, 5],
    3 => [1, 2, 6],
    4 => [1, 6],
    5 => [2, 6],
    6 => [3, 4, 5]
)

# Coordenadas de cada vértice en R^2
coord = Dict(
    1 => (0, 0),
    2 => (3, 1),
    3 => (5, 0),
    4 => (1, -4),
    5 => (7, 0),
    6 => (7, -2)
)

# Función para generar vecinos
function vecinos(v)
    return G[v]
end

# Heurística basada en distancia euclídea
function heur_euclidea(v, obj)
    x1, y1 = coord[v]
    x2, y2 = coord[obj]
    return sqrt((x1 - x2)^2 + (y1 - y2)^2)
end

# Función de coste a partir del grafo
function coste(v1, v2)
    if v2 in vecinos(v1)
        return heur_euclidea(v1,v2)
    else
        return Inf  # Si no están conectadas, el coste es infinito
    end
end

# Estado inicial y objetivo
inicio = 1
meta = 6

# Llamada al algoritmo A*
sol = astar(vecinos, inicio, meta; heuristic = heur_euclidea, cost = coste)
ResumeSol(sol, "A*")

## Uso de GraphRecipes para representar el grafo anterior:
# La función to_graph recibe la lista de adyacencias, y las
# coordenadas, y representa el grafo.

using GraphRecipes

function to_graph(G,coord)
    vertices = sort(collect(keys(G)))
    xcoord = [coord[v][1] for v in vertices]
    ycoord = [coord[v][2] for v in vertices]
    N = length(vertices)

    Matriz_Adyacencias = zeros(N,N)
    for i in 1:N
        for j in 1:N
            Matriz_Adyacencias[i,j] = j in G[i] ? 1 : 0
        end
    end    

    aristas = Array{Float64}(undef, N, N)
    for i in 1:N
        for j in 1:N
            aristas[i, j] = round(coste(i,j);digits=2)
        end
    end

    graphplot(Matriz_Adyacencias, 
        nodeshape = :circle,
        x = xcoord,
        y = ycoord,
        nodesize = 1,
        markercolor = :lightgray,
        names = vertices, 
        edgelabel = aristas,
        curvature_scalar=0,
        edge_label_box = true,
        fontsize = 10)
end

to_graph(G,coord)



#=
######################################
$15$ Puzzle
######################################

Resolver el 15-puzzle, un juego solitario de piezas deslizantes que consiste 
en ordenar unas piezas numeradas del 1 al 15 dentro de una cuadrícula de 
tamaño 4×4. El hueco de la pieza faltante se usa como espacio para
deslizar las piezas adyacentes.

## Elección de los estados
Un estado representa la situación completa del 15-puzzle: las $16$ posiciones 
de los números como un array 2D de enteros (`Int8`).

Además, añadimos funciones para copiar, comparar y comprimir estados.
=#

struct Estado
    table::Array{Int8,2}
end

# Añadimos la capacidad de copiar y comparar estados
Base.copy(s::Estado) = Estado(copy(s.table))
Base.:(==)(s1::Estado, s2::Estado) = s1.table == s2.table

# Función para calcular el hash (identificador único) de un estado.
# Se almacenan los hash de los estados que se visitan para saber si 
# el estado actual ha sido ya visitado y no hace falta seguir con él.
function Base.hash(s::Estado)
    # Un estado puede ser comprimido en un UInt64 (16 valores x 4 bits el valor)
    h = UInt64(0)
    # Lo comprimimos por columnas
    for j = 1:4, i = 1:4
        h += s.table[i, j]
        h <<= 4
    end
    return h
end

#=
El estado objetivo que estamos buscando en este problema es una ordenación 
específica de los números 1 a 15 (el $0$ representa el hueco). Representa 
la solución del problema, porque el puzzle no es dar una solución, sino el 
conjunto de acciones que te llevan hasta él.
=#

OBJETIVO = Estado(Matrix(reshape(0:15,4,4))')
display(OBJETIVO.table)
#=
## Elección de las acciones (Transición)

Las acciones permitidas en el puzzle (cuyas ejecuciones conformarán una función 
de transición válida) vienen dadas por los movimientos del hueco (intercambios 
con otras fichas) en las 4 direcciones principales.

Vamos a hacer uso de una estructura que trae Julia denominada `CartesianIndex` 
que proporciona un índice multidimensional (en nuestro caso, 2D), que facilita 
trabajar con `arrays` como si fueran índices para otros arrays.
=#

UP    = CartesianIndex(-1, 0)
DOWN  = CartesianIndex(1, 0)
LEFT  = CartesianIndex(0, -1)
RIGHT = CartesianIndex(0, 1)
	
ACCCIONES = [UP, DOWN, LEFT, RIGHT] 

# Vamos a dar un conjunto de funciones que serán de utilidad para la aplicación 
# de una acción determinada sobre un estado.

# Posición del hueco (0) dentro de s
pos_0(s::Estado) = findfirst(x -> x == 0, s.table)

# Devuelve si el índice multidimensional c es válido dentro del puzzle
ind_valido(c) = (1 <= c[1] <= 4) && (1 <= c[2] <= 4)

# Movimientos válidos desde una posición e
acs_disp(e::CartesianIndex) =
    [a for a in ACCCIONES if ind_valido(e + a)]
    
# Movimientos válidos del hueco de s
acs_disp(s::Estado) = s |> pos_0 |> acs_disp
    
# Estados sucesores de s
sucesores(s::Estado) = map(a -> aplica(s, a), acs_disp(s))

# Aplica (devuelve una copia) el movimiento del hueco en direction a s
function aplica(s::Estado, a::CartesianIndex)
    sucesor = copy(s.table)
    h = pos_0(s)
    dest = h + a
    sucesor[h], sucesor[dest] = sucesor[dest], sucesor[h]
    return Estado(sucesor)
end

# Aplica (modifica s) el movimiento del hueco en direction a s
function aplica!(s::Estado, a::CartesianIndex)
    h = pos_0(s)
    dest = h + a
    s.table[h], s.table[dest] = s.table[dest], s.table[h]
    return nothing
end

## Heurísticas

# A continuación damos las funciones que nos pueden servir para el cálculo de la
# heurística (como distancia entre estados).

# Distancia de Manhattan entre dos índices multidimensionales
manhattan(c1::CartesianIndex, c2::CartesianIndex) = 
        c1 - c2 |> x -> (x.I .|> abs) |> sum

# Devuelve los índices de cada valor dentro del estado objetivo.
# Se usa en la heurística de Manhattan para comparar las posiciones actuales con 
# las que debe ocupar finalmente
INDICES_EN_OBJETIVO = [findfirst(x -> x == i, OBJETIVO.table) for i = 1:15]

# Heurística de Mahattan de un estado: suma de las distancias de Manhattan de la 
# posición de cada ficha a su posición final

heur_manhattan(s::Estado) =
    sum(manhattan(findfirst(x -> x == i, s.table), INDICES_EN_OBJETIVO[i]) for i = 1:15)

# Devuelve el número de intercambios directos que hay entre s y OBJETIVO
function n_intercambios(s::Estado)
    acc = 0
    for j = 1:3, i = 1:3
    # Intercambios horizontales
    if (s.table[i, j] == OBJETIVO.table[i+1, j]) &&
        (s.table[i+1, j] == OBJETIVO.table[i, j])
        acc += 1
    end
    # Intercambios verticales
    if (s.table[i, j] == OBJETIVO.table[i, j+1]) &&
        (s.table[i, j+1] == OBJETIVO.table[i, j])
        acc += 1
    end
    end
    return acc
end

# Devuelve heurística opcional

function heur2(s::Estado)
    return heur_manhattan(s) + 2n_intercambios(s)
end

# Como en este problema el objetivo es fijo, la heurística realmente solo 
# depende del estado actual

heuristica(s, goal) = heur2(s)

## Test 1: Búsqueda Trivial

#=
El caso más sencillo es en el que el estado inicial es ya el estado objetivo. 
En este caso, todos los algoritmos deben dar una salida directa de un solo 
estado, ya que no ha de ejecutar ninguna transición.
=#

I1 = OBJETIVO
sol = BFS(sucesores, I1, OBJETIVO)

function Jugada(sol)
    for s in sol.path
        display(s.table)
    end
end

Jugada(sol)

astar(sucesores, I1, OBJETIVO, heuristic=heuristica)

## Test 2: Tablero Aleatorio

# Ahora vamos a hacer ya una jugada cualquiera. Para estar seguros de que
# comenzamos con una configuración que tiene solución, creamos un procedimiento 
# que desordena la configuración objetivo al azar, y después intenta resolver 
# el puzzle.

# Genera un estado desde OBJETIVO ejecutando n movimientos al azar

function Inicio_Aleatorio(n)
    s = copy(OBJETIVO)
    for _ = 1:n
        a = rand(acs_disp(s))
        aplica!(s, a)
    end
    return s
end
    
I2 = Inicio_Aleatorio(40)

sol_p3 = @time astar(sucesores, I2, OBJETIVO, heuristic = heuristica)

Jugada(sol_p3)

## Funciones para representar el laberinto
# Función para generar una celda cuadrada en la posición (i, j)

function dibuja_puzzle(sol)
    # Graficar el laberinto
    p = plot(aspect_ratio=:equal, legend=false, fillalpha=0.5)

    for i in 1:size(sol)[1]
        for j in 1:size(sol)[2]
            plot!(celda(i-.5, j-.5), fillcolor=:white, linecolor=:black)
            annotate!(i,j,text(sol[i,j],:black,16,:center))
        end
    end
    # Mostrar el gráfico
    p
end

dibuja_puzzle((sol_p3.path[end]).table')

######################
# Problemas Propuestos
######################

#=
En la relación de problemas de clase hay muchos problemas propuestos que pueden
resolverse como una búsqueda en Espacios de Estados. Por ejemplo:
=#

#= 
#################################
Torres de Hanoi
#################################

Se tienen N discos (en el problema clásico, N=3) de distinto tamaño apilados 
sobre una base A de manera que cada disco se encuentra sobre uno de mayor radio. 
Existen otras dos bases vacías, B y C. Haciendo uso únicamente de las 3 bases, 
el objetivo es llevar todos los discos de la base A hasta la base C. Sólo se 
puede mover un disco a la vez, y cada disco puede descansar solamente en las 
bases o sobre otro disco de tamaño superior, pero no en el suelo. 
=#

#= 
#####################################
Juego de las Cifras (Cifras y Letras)
#####################################

Dada una colección de 6 números, C, y un número objetivo, O, encontrar la combi-
nación aritmética entre los elementos de C que se aproxima lo más posible a O. 
=#
