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

#################################
### Optimización de Funciones ###
#################################

#= 
Carga de librerías
------------------

Para este tema se ha preparado un módulo propio llamado `Opt` ("Opt.jl") que
tiene definidas las estructuras y funciones necesarias para los algoritmos de
Optimización vistos en clase::
* Templado Simulado (`SA`)
* Optimización por Enjambres de Partículas (`PSO`)
=#

using Plots # Para representación de funciones
include("./lib/Opt.jl")

#################
### Ejemplos  ###
#################

#=
## Ejemplo 1. Optimización de funciones reales
##############################################
El primer ejemplo que se propone es el más directo, la optimización de funciones 
reales (ponemos ejemplos de 1 y 2 variables). En ellos también podemos ver los 
problemas que, en general, tienen los métodos de optimización de bloqueo en 
óptimos locales.
=#


# Función real: f: R -> R
#------------------------

f(x) = 1 + cos(x)^2 - sin(x)
vecino(x) = x + rand([-0.01, 0.01])

x1, y1 = SA(f, 0, 100, vecino, 0.001, 1.0, true)
x2, y2 = SA(f, -2.5, 100, vecino, 0.001, 1.0, false) 

# Representación gráfica
In = -2π:0.1:2π
plot(In, map(f, In), label="f(x)")
plot!([x1,x2], [y1,y2], seriestype=:scatter, color = [:red, :green], markersize = 5, label = "SA")



# Función de Himmelblau: f:R^2 -> R
#----------------------------------

himmelblau(x, y) = (x^2 + y - 11)^2 + (x + y^2 - 7)^2
himmelblau(z) = himmelblau(z...) # uso vectorial de himmelblau

# Cálculo de un vecino en el entorno
vecino(z) = [z[1]+rand([-.01, .01]), z[2]+rand([-.01, .01])]

# Cálculo de mínimos con Simulated Annealing
xm1, ym1 = SA(himmelblau, [-5,-5], 10, vecino, 0.001, 1.0, true)
xm2, ym2 = SA(himmelblau, [-5,5], 10, vecino, 0.001, 1.0, true)
xm3, ym3 = SA(himmelblau, [5,5], 10, vecino, 0.001, 1.0, true)
xm4, ym4 = SA(himmelblau, [5,-5], 10, vecino, 0.001, 1.0, true)

# Representación de la Función de Himmelblau (contornos en 2D)
x = y = range(-6, 6; length=100)
z = himmelblau.(x, y)
contour(x, y, himmelblau, levels=50)
minimos_x = [xm1[1], xm2[1], xm3[1], xm4[1]]
minimos_y = [xm1[2], xm2[2], xm3[2], xm4[2]]
plot!(minimos_x, minimos_y, seriestype=:scatter, color = :red, markersize = 5, label = "SA")



# Función de Rosenbrock: f:R^2 -> R
#----------------------------------

rosenbrock(x, y) = (1 - x)^2 + 100(y - x^2)^2
rosenbrock(z) = rosenbrock(z...)
# Cálculo de un vecino en el entorno
vecino(z) = [z[1] + rand([-.01, .01]), z[2] + rand([-.01, .01])]

# Cálculo del mínimo con Simulated Annealing
xb5, yb5 = SA(rosenbrock, [0,0], 10, vecino, 0.001, 1.0, true)
println("Mínimo: ", xb5, " : ",yb5)

# Representación Gráfica de la Función de Rosenbrock (3D)
xs = -4:0.1:4
ys = -4:0.1:4
zs = [rosenbrock(x,y) for x in xs, y in ys]
surface(xs, ys, zs, camera=(40,20))
plot!([xb5[1]], [xb5[2]], [yb5],seriestype=:scatter, color = :red, markersize = 5, label = "SA", camera=(40,20))


#=
## Ejemplo 2. Cartas 36/360
###########################
Tenemos un conjunto de cartas que van numeradas del 1 al 10. Nuestro objetivo es
dividir el conjunto en 2 montones de forma que la suma de las cartas del primer 
monton sea 36 y el producto de las cartas del segundo montón sea 360 (o lo más 
cerca posible).
=#

# Representación: [ m1, m2] 
# 				  m1 ∪ m2 = [1..10], m1 ∩ m2 = ∅
# Objetivo: sum(m1) ~ 36, prod(m2) ~ 360

# Función auxiliar que elimina un elemento de una colección
function remove!(a, item)
    deleteat!(a, findall(x -> x==item, a))
end

# Cálculo de vecino: intercambia al azar un elemento entre los dos montones
function cambia_monton(s)
    m1, m2 = s
    m1copy = copy(m1)
    m2copy = copy(m2)
    i = rand(1:10)
    if i in m1copy
        return (remove!(m1copy, i), push!(m2copy, i))
    else
        return (push!(m1copy, i), remove!(m2copy, i))
    end
end

# Energía: Similaridad a (suma = 36, producto = 360)
function Energia(s)
    m1, m2 = s
    suma = isempty(m1) ? 0 : sum(m1)
    pr   = isempty(m2) ? 0 : prod(m2)
    return (abs(suma - 36) + abs(pr - 360))
end

# Inicialización
# 		distribución aleatoria de 2 montones de 5 cartas 
# 		(podría ser cualquier otro inicio)
using Random
s = shuffle(1:10);
s_0 = (s[1:5], s[6:10])

sol, en = SA(Energia, s_0, 10, cambia_monton, 0.001, 1.0, true)
m1, m2 = sol;
println("Montón 1 = ",m1, " : Montón 2 = ", m2)
println("sum(m1) = ", sum(m1)," : prod(m2) = ", prod(m2))

#=
## Ejemplo 3. TSP: Problema del viajante
########################################

Dado un conjunto de $N$ ciudades conectadas entre sí (en una primera versión, 
podemos suponer que todas están conectadas con todas), encontrar una ruta que 
pase por todas y cada una de ellas una sola vez, y con recorrido total mínimo. 

Puedes probar a cambiar el número de ciudades, en cada caso, generará aleatoria-
mente las ciudades en [0,1]^2 y ejecutará el algoritmo de Templado Simulado para 
encontrar una ruta mínima.
=#


# Estructura representando un tour que visita todas las ciudades:
# - `orden::Vector{Int}`: orden en el que se visita cada ciudad.
# - `D::Matrix`: Matriz de distancias. Se almacena para no tener que recalcular-
#       la cada vez (se podría haber puesto como una variable de acceso global, 
#       pero hubiera quedado más artifical el uso en el algoritmo). 

struct Ruta
    orden::Vector{Int}
    D::Matrix{Float64}
end

# RandomRuta(D::Matrix): Crea un tour con un orden aleatorio de las ciudades. 
#       La matriz de distancias permanece igual.
RandomRuta(D::Matrix) = Ruta(randcycle(size(D, 1)), D)

# cost(tour::Tour): Calcula la energía (coste total) de un tour sumando las 
#       distancias entre ciudades sucesivas.
function coste(ruta::Ruta)
    c = 0.0
    for (k, c1) in enumerate(ruta.orden)
        c2 = ruta.orden[mod1(k + 1, length(ruta.orden))]
        c += ruta.D[c1, c2]
    end
    return c
end

# cambia_tour(tour::Tour): Propone un nuevo tour candidato a partir de otro 
#       invirtiendo el orden de las ciudades entre dos índices aleatorios.
function cambia_tour(ruta::Ruta)
    n = length(ruta.orden)
    orden = copy(ruta.orden)
    # El orden se invertirá entre los índices i1 e i2 (incluidos)
    i1 = rand(1:n)
    i2 = mod1(rand(1:n-1) + i1, n)  # Debe asegurarse que i1 != i2
    # y que i1 < i2
    if i1 > i2
        i1, i2 = i2, i1
    end
    if i1 == 1 && i2 == n
        return Ruta(orden, ruta.D)
    end
    orden[i1:i2] = reverse(orden[i1:i2]) 
    return Ruta(orden, ruta.D)
end

# Inicialización

# Conjunto de ciudades aleatorio. Coste mínimo desconocido
num_ciudades = 50
ciudades = [transpose(rand(num_ciudades)); transpose(rand(num_ciudades))]
    
# Matriz de distancias (no cambia a lo largo del experimento)
D = sqrt.((ciudades[1, :] .- ciudades[1, :]').^2 +
            (ciudades[2, :] .- ciudades[2, :]').^2)

s0=RandomRuta(D)
coste_s0 = coste(s0)

# Ejecuta Templado Simulado
sol_ruta, sol_coste = SA(coste, s0, 1000, cambia_tour, 0.0001, .1, true)

# Mostramos el resultado gráficamente

# Reordenamos las ciudades según el orden encontrado en la solución
ciu_orden = map(o -> ciudades[:,o], sol_ruta.orden)
# Copiamos la última ciudad y la ponemos en primer lugar
ciu_orden = pushfirst!(ciu_orden,ciu_orden[num_ciudades])
# Añadimos las ciudades originales como puntos
scatter(ciudades[1,:], ciudades[2,:], color=:red, markersize=5)
# Las numeramos según el orden inicial
annotate!(ciudades[1,:], ciudades[2,:], [text(i,:bottom) for i in 1:num_ciudades])
# Dibujamos la ruta solución
plot!(map(c -> c[1], ciu_orden),map(c -> c[2], ciu_orden),color=:blue)
# Devolvemos la figura


#=
## Ejemplo 4. N Reinas
########################

En un tablero de ajedrez de tamaño N×N, situar N reinas de manera que ninguna 
amenace a otra (recordamos que una reina amenaza a cualquier figura que esté en 
su misma fila, columna, o diagonales).
=#

# Una propuesta de representación sencilla consiste en un vector de N 
# posiciones donde la posición i indica la fila de la reina i-ésima 
# (es decir, por defecto, cada reina ocupa una columna distinta).

# Una propuesta de vecino es modificar al azar uno de los valores (también 
# elegido al azar) del vector de N posiciones 
function vecino(s)
    N = length(s)
    s1 = copy(s)
    i = rand(1:N)
    s1[i]=rand(1:N)
    return s1
end

# Función auxiliar, indica si hay una amenaza entre la reina que ocupa la 
# columna i y la que ocupa la j
function amenaza(i,j,s)
    eli = s[i]
    elj = s[j]
    return (eli == elj || abs(elj - eli) == abs(j - i)) ? 1 : 0
end

# El número total de amenaza (que será nuestra función de energía), es 
# simplemente contar el número total de amenazas en el estado
function amenazas(s)
    N = length(s)
    res = 0
    for i in 1:N
        for j in (i+1):N
            res += amenaza(i,j,s)
        end
    end
    return res
end

# Estado inicial aleatorio
N = 100
s0 = map(x -> rand(1:N), 1:N)

# Ejecutamos Templado simulado a partir del estado anterior
solReinas, amReinas = SA(amenazas, s0, 1000, vecino, 0.0001, 1.0, true)
dibuja_reinas(solReinas)

# Dibujamos la solución en el tablero
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

#=
## Ejemplo 5. Subconjuntos de Suma Nula
#######################################
Dado un conjunto I ⊂ Z, encontrar un subconjunto suyo de suma nula. Es decir,
S ⊂ I tal que:
                    \sum_{c ∈ S} c = 0
=#

# Generamos al azar un conjunto I de enteros (entre -50 y 50) de tanaño ≤ 100. 
# Lo representamos como un vector, del tamaño que corresponda, formado por sus 
# elementos.

I = map(x -> rand(-50:50), 1:rand(1:100))

# Un sbconjunto suyo se puede dar por la asignación al azar de valores 0/1 a los 
# elementos de I. De forma que 
#                       S = { I[i] ∈ I: s[i]=1 }

# Generamos un primer subconjunto/estado al azar

s2 = map(x -> rand(0:1), I)

# Un vecino del estado s es, simplemente, un subconjunto formado a partir de s 
# añadiendo o quitando un elemento al azar de I (si estaba ya en s, se quita, y 
# si no está, se pone). Se traduce por seleccionar al azar un índice, y modifi-
# car su valor 0 ↔ 1

function cambia_set(s)
    s1 = copy(s)
    i = rand(1:length(s))
    s1[i] = 1 - s1[i]
    return s1
end

# El peso de un estado es el valor absoluto de sus elementos
function peso(s)
    return (s .* I) |> sum |> abs
end

# Ejecutamos Templado Simulado comenzando por ese estado inicial al azar
sol_sum_nula, suma = SA(peso, s2, 10, cambia_set, 0.001, 1.0, true)
# Construimos el subconjunto de I que se ha encontrado como solución
solsum = filter(x-> x != 0, (sol_sum_nula .* I))

#=
## Ejemplo 6. Coloreado de Mapas
################################
Fijado un grafo, G, con una función arista?(x,y) que indica si los nodos x e y 
están conectados por una arista del grafo, determina (y en caso positivo, 
proporciona) si existe un coloreado válido de G haciendo uso de K colores. 

Un coloreado es una asignación de colores a nodos, y es válido si nodos 
conectados están coloreados con colores distintos.
=#

using Random

# N: Número de nodos
# M: Número de aristas
# K: Número de colores
# Generamos un grafo N-M al azar
N =rand(10:20)
M = rand(2:(N*(N-1)÷2))
K=rand(3:5)

todas_aristas = [(i,j) for i in 1:N for j in (i+1):N];
aristas = (shuffle(todas_aristas))[1:M]

print("N = ",N, " nodos, K = ", K, " colores, M = ", M, " aristas\nAristas: ", aristas)

# los estados son N asignaciones de valores de 1:K
# s=[s1,...sN], si ∈ 1:K

# Un posible estado sucesor se consigue alterando al azar el color de uno de los 
# nodos
function vecino_col(s)
    s1 = copy(s)
    i = rand(1:N)
    k1 = rand(1:K)
    s1[i] = k1
    return s1
end

# Calculamos el número de errores de una coloración: Energia
function errores(s)
    total_err = 0
    for i in 1:M
        n1, n2 = aristas[i]
        if s[n1] == s[n2] 
            total_err += 1
        end
    end
    total_err
end

K=6
s0 = rand((1:K),N)
sol_col, er= SA(errores, s0, 100, vecino_col, 0.001, 1.0, true)
print("\nColoreado: ", sol_col, "\nNº Errores: ", er )

#=
## Ejemplo 7. Cuadrados Mágicos
###############################
Un cuadrado mágico consiste en una distribución de números en filas y columnas, 
formando un cuadrado, de forma que los números de cada fila, columna y diagonal 
suman lo mismo. Aunque es posible recrear diferentes tipos de cuadrados mágicos, 
tradicionalmente se forman con los números naturales desde el 1 hasta n^2, donde 
n es el lado del cuadrado.
=#

# Tamaño del cuadrado
N = 4

# Un estado es una distribución de 1:N^2 en una matriz de N×N

# Un vecino se consigue intercambiando 2 elementos cualesquiera de la matriz

function vecino_mag(s)
    s1 = copy(s)
    i1,j1,i2,j2 = rand(1:N,4)
    s1[i1,j1], s1[i2,j2] = s1[i2,j2], s1[i1,j1]
    s1
end

# La energía se calcula como la suma de los errores en todas las filas, columnas, etc
function err_mag(s)
    obj = sum(1:N^2)/N
    total_err =  0
    for i in 1:N
        total_err += (abs(sum(s[:,i]) - obj) + abs(sum(s[i,:]) - obj))
    end
    d1 = abs(sum([s[i,i] for i in 1:N]) - obj)
    d2 = abs(sum([s[i,N-i+1] for i in 1:N]) - obj)
    total_err += (d1 + d2)
end

s0 = reshape(1:N^2, (N,N))
sol, er = SA(err_mag, s0, 100, vecino_mag, 0.001, 1.0, true)
display(sol)

#=
## Ejemplo 8. Ganadero
######################
Un ganadero tiene un rebaño de ovejas. Cada oveja tiene un peso y se vende por 
un precio prefijado. El ganadero dispone de un camión que es capaz de cargar un 
peso máximo. Su problema es seleccionar una colección de ovejas para llevarlas 
al mercado de ganado en el camión, de manera que se maximice el precio total de 
las ovejas transportadas, sin superar el peso total soportado por el camión.
=#

# Número de ovejas y tara del camión
N = rand(1:50)
T = rand(500:1000)
# Pesos y precios de las N ovejas
pesos = rand(20:80, N)
precios = rand(50:300, N)
println("$N ovejas, Tara = $T\n  Pesos: $pesos\n  Precios: $precios")

# Un estado es una lista binaria de longitud N indicando qué oveja se vende o no

# Un estado vecino consiste en cambiar el estado de una oveja al azar
function vecino_ovj(s)
    s1 = copy(s)
    i = rand(1:N)
    s1[i] = 1 - s[i]
    s1
end

# La energía (bondad) de un estado depende de si nos pasamos o no del peso 
# total, y del precio total conseguido:
function energia_ovj(s)
    peso_total = sum(s .* pesos)
    precio_total = sum(s .* precios)
    penalizacion = peso_total > T ? (peso_total- T) : 0
    return -precio_total + 100 * penalizacion
end

s0 = rand(0:1,N);
sol, en = SA(energia_ovj, s0, 10, vecino_ovj, 0.001, 1.0, true)	
print("\nPeso final: $(sum(sol .* pesos))")
print("\nPrecio final: $(sum(sol .* precios))")

#=
## Ejemplo 9. Particiones de un grafo. Problema max-cut. Problema min-cut. 
##########################################################################
Dado un grafo G=(V,E) sin ciclos, donde cada arista lleva asociado un peso 
entero positivo, se trata de encontrar una partición de V en dos conjuntos 
disjuntos, V_0 y V_1 de tal manera que la suma de los pesos de las aristas
que tienen un extremo en V_0 y el otro extremo en V_1, sea máxima (problema 
max-cut) o mínima (problema min-cut, en este caso hay que poner restricciones 
para que no sea válido tomar alguno de los dos conjuntos muy pequeño).
=#

# N: Número de nodos
# M: Número de aristas
# K: Número de colores
# Generamos un grafo N-M al azar
N =rand(3:20)
M = rand(2:(N*(N-1)÷2))
nodos = collect(1:N);

todas_aristas = [(i,j) for i in 1:(N-1) for j in (i+1):N]
aristas = (shuffle(todas_aristas))[1:M]
Pesos_aristas = rand(1:100,M)

println("Grafo: N = $N nodos, M = $M aristas")
println("   Aristas:  $aristas")
println("   Pesos Aristas: $Pesos_aristas")

# Un estado es un vector binario de longitud N que indica si el nodo 
# está en V0 o en V1

# Un estado sucesor se consigue cambiando un nodo al azar de V0 a V1, 
# y viceversa
function vecino_cut(s)
    s1 = copy(s)
    i = rand(1:N)
    s1[i] = 1 - s[i]
    s1
end

# La energía de la solución se calcula como la suma de las aristas entre 
# V0 y V1
function energia_cut(s)
    total_en = 0
    for i in 1:M
        n1, n2 = aristas[i]
        if s[n1] != s[n2]
            total_en += Pesos_aristas[i]
        end
    end
    return -total_en
end

# A partir de un estado (vector 0/1), extrae los nodos de V0 y V1
function extraer_Vs(s)
    # Combinamos los índices y el estado
    R = zip(nodos,s)
    # A partir del estado, filtramos los índices que nos interesan
    V0 = [x[1] for x in R if x[2] != 0]
    V1 = [x[1] for x in R if x[2] == 0]
    # Mostramos los resultados
    println("\nEstado: $s")
    println("   V0 = $V0")
    println("   V1 = $V1")
    println("   Peso Corte =  $(-energia_cut(s))")		
    return V0, V1
end

s0 = rand(0:1,N)
extraer_Vs(s0)

sol, en = SA(energia_cut, s0, 10, vecino_cut, 0.001, 1.0, true)
extraer_Vs(sol)

#=
## Ejemplo 10. PSO
##################
# Usa PSO para encontrar soluciones óptimas de la función de himmelblau:
    himmelblau(x, y) = (x^2 + y - 11)^2 + (x + y^2 - 7)^2
=#

# Proyección del espacio de parámetros de PSO en el espacio de búsqueda 
# de la función:
#  			x ∈ [0,1] -> 10x-5 ∈ [-5,5]
proy(z) = 10z .- 5

himmelblau(x, y) = (x^2 + y - 11)^2 + (x + y^2 - 7)^2
fh(x)=himmelblau((proy(x)...))

# Ejecutamos los experimentos:
nExp = 100
xs = Array{Float64}(undef, nExp)
ys = zeros(nExp)
for i in 1:nExp
    # Almacenamos las soluciones encontradas por cada experimento
    sgi, sf1 = swarmFit(fh, 2, nParticle=100, nIter=100, nNeighbor=10)
    xs[i], ys[i] = proy(sgi)
end
xs, ys

# Representamos la Función (contornos en 2D) con las soluciones encontradas
x = y = range(-6, 6; length=100)
z = himmelblau.(x, y')
contour(x, y, himmelblau, levels=50)
scatter!(xs, ys, label="", color=:red, markersize=2)

#=
## Ejemplo 11. Empaquetamiento de esferas
#########################################

Usa PSO para resolver el problema de empaquetamiento de esferas: Tenemos una
caja de dimensiones A×B×C y queremos meter dentro el mayor número posible de 
esferas de radio 1. Las esferas no se pueden salir de la caja, no son comprimi-
bles, y no pueden encajar ni atraversarse entre sí.

Da un modelado general, y después particulariza para valores concretos de A, B y 
C.
=#

#=
## Ejemplo 12. Ahorro de patrones
#################################

Usa PSO para resolver el problema de ahorro de tela en los sistemas de patrones. 
Dado un conjunto de superficies, S1,...Sn, el objetivo es distribuirlas en una 
superficie (sin que se superpongan) con el fin de minimizar el área que ocupan.

Da un modelado general, y después particulariza para valores una familia de
superficies prefijada (por ejemplo, N rectángulo prefijados).
=#


#=
## Ejemplo 13. Grafo Tripartito
###############################

Aplica el algoritmo de Templado Simulado para resolver el siguiente problema:

Dado un grafo G=(V,E) con pesos positivos en las aristas, encontrar una parti-
ción de V en tres conjuntos, V1, V2 y V3, de tal manera que la suma de los pesos 
de las aristas que conectan V1 y V2, y la suma de los pesos de las aristas que 
conectan V1 y V3, sea lo más parecida posible.
=#


#=
## Ejemplo 14. División de Población
####################################

Tenemos una lista que representa los pesos de una población (todos los pesos 
están entre 0 y 100). Queremos encontrar 3 números (0 < a1 < a2 < a3 < 100) que 
sirvan para dividir el conjunto anterior en 4 secciones: 
                [0, a1), [a1, a2), [a2, a3), [a3, 100), 
de forma que las sumas de los pesos que hay en cada sección sean lo más 
parecidas posibles.

¿Qué cambios harías para encontrar una división similar en K secciones?
=#

#=
## Ejemplo 15. Problema de asignación de tareas
###############################################

Disponemos de un conjunto de agentes (A={ai:1≤i≤n}) y un número de tareas a 
realizar (T={tj:1≤j≤m}). Cualquier agente puede ser asignado para desarrollar 
cualquier tarea, cuya ejecución supone un coste (cij) que puede variar depen-
diendo del agente, ai, y la tarea, tj, asignada.

Es necesario para desarrollar todas las tareas asignar un solo agente a cada 
tarea para que el coste total de la asignación sea minimizado, aunque un mismo 
agente podría realizar más de una tarea, pero ha de tenerse en cuenta que la 
realización de la tarea tj por el agente ai conlleva el uso de una serie de 
recursos (rij) del agente, y estos están acotados por una cantidad fija, bi, 
para cada agente.

Encuentra una asignación de tareas factible y de coste mínimo.
=#