using Pkg
Pkg.activate(".")
# Pkg.instantiate()

using CSV
using DataFrames
using Plots
plotly()

############
# K Medias #
############

#= 
En este ejercicio vamos a implementar y probar el algoritmo K-medias a partir
de algunas tareas predefinidas básicas:

## Tarea 1: Funciones básicas

Define las siguientes funciones:
1. `centroide(D)`: recibe una colección de vectores de la misma dimensión, y 
	devuelve el punto medio (centroide) de ellos.
2. `eucl(p₁, p₂)`: recibe 2 vectores de la misma dimensión, y devuelve la 
	distancia euclídea entre ellos. Define también `eucl2`, que es el cuadrado 
	de la distancia.
3. `manh(p₁, p₂)`: recibe 2 vectores de la misma dimensión, y devuelve la 
	distancia de manhattan entre ellos.

Y pruébalos sobre vectores de distinta dimensión para comproar que funcionan 
correctamente.
=#

# Centroide de un conjunto de puntos/vectores
function centroide(D)
	sum(D)/length(D)
end

# Distancia euclídea2 (euclídea al cuadrado)
function eucl2(x, y)
	# ∑ (xᵢ - yᵢ)²
	sum((x .- y).^2)
	# sum( (xi - yi)^2 for (xi, yi) in zip(x, y) )
	
end

# distancia euclídea
function eucl(x, y)
	sqrt(eucl2(x, y))
end

# distancia manhattan
function manh(x, y)
	# ∑ |xᵢ - yᵢ|
	sum(abs.(x .- y))
	# sum( abs(xi - yi) for (xi, yi) in zip(x, y) )
end

#=
## Tarea 2: Implementación del algoritmo

Define la función `k_medias` que recibe:

* `D`           : Vector de puntos de muestra.
* `K`           : Número de clusters a buscar.
* `T = 100`     : Número de pasos a ejecutar del algoritmo.
* `dist = eucl2`: distancia que se usará en `D`.

Devuelve un par `(Cls, C)`, donde:
1.  C = [c₁, ..., cₖ] es un vector de los K centroides para los clusters.
2.  Cls es la colección de K clusters asociados a los centroides de C.

Una solución es asignar a cada 1 ≤ i ≤ K el vector de índices de D que forman
el cluster de cᵢ. Es decir, si ci está formado por {D[j₁], ..., D[jₙ]}, entonces 
en el diccionario se asocia la clave i con el conjunto de índices [j₁, ..., jₙ]
=#

# D: Dataset de Puntos
# C: Centroides
# K: |C|
# T: Num. iteraciones
# dist: distancia en D (por defecto, eucl2)

function k_medias(D, K ; T = 100, dist = eucl2)
	# Inicialmente, los centroides se situan en K puntos al azar de D
	C   = rand(D, K)
	N   = length(D)
	Cls = Dict()
	# El algoritmo se ejecuta un número prefijado de pasos
	for _ in 1:T
		# Cl es un diccionario de K clusters, inicialmente, vacíos
		Cls = Dict( [k => [] for k in 1:K] )
		# Decidimos el cluster en el que meter cada elemento de D (el índice)
		for i in 1:N
			push!( Cls[argmin([dist(D[i], c) for c in C])], i)
		end
		# Calculamos los nuevos centroides por el contenido de los clusters
		for k in 1:K
			if !isempty( Cls[k] )
				C[k] = centroide( D[i] for i in Cls[k] )
			end
		end
	end
	# Devolvemos Clusters y centroides
	return (Cls, C)
end

# Definimos una función para comprobar k_medias en D ⊆ ℝ², y representar 
# gráficamente los K clusters encontrados

function testKmedias(D, K)
	(Cls, C) = k_medias(D, K)
	pl = plot()
	for k in 1:K
		cl_k = [ D[i] for i in Cls[k] ]
		pl = plot!(first.(cl_k), last.(cl_k), seriestype="scatter")
	end
	return pl
end

# Ejemplo

D = [ round.(10 .* rand(2), digits = 1) for _ in 1:300 ]
println(D)
pl  = plot(first.(D), last.(D), seriestype = "scatter", mc = :white)
testKmedias(D, 4)

## Tarea 3: Función Potencial
#=
Define una función `potencial(D, Cl, C, dist)` que calcule el potencial del 
conjunto `D` para el clustering `(Cl, C)` haciendo uso de la distancia `dist`.

	Función Potencial
    Se recuerda que si tenemos una partición de D en clusters Cl₁, ..., Clₖ, 
	donde cᵢ es el centroide de Clᵢ, entonces la función potencial es:
     
    ∑ᵢ ∑_{x∈ Clᵢ} d(x, cᵢ)^2

	[Partición: D = Cl₁ ⋃ ... ⋃ Clₖ, y si i ≠ j entonces Clᵢ ∩ Clⱼ=∅]
=#

function potencial(D, Cls, C, dist)
	pot = 0
	for i in keys(Cls)
		if !isempty(Cls[i]) 
			pot = pot + sum( [ dist(D[j], C[i])^2 for j in Cls[i] ] )
		end
	end
	pot
end

# Podemos medir el potencial de la clusterización calculada anteriormente:
(Cls, C) = k_medias(D, 4)
potencial(D, Cls, C, eucl)

## Tarea 4: Método del Codo
#=
Usando las funciones definidas en las tareas anteriores, vamos a dar un 
procedimiento (no muy bueno) para decidir el número de clusters que podríamos 
considerar adecuado para un conjunto de datos. Para ello:

Crea una función que reciba como entrada D y calcule para cada valor de K 
(1 ≤ K ≤ |D|) el potencial de una clusterización de D por medio de K-medias. 
Como el algoritmo de K-medias puede dar distintos resultados dependiendo de la 
elección inicial de centroides, puede ser interesante que esta función no haga 
una sola ejecución para cada valor de K, sino unas cuantas y se quede con la 
media de los potenciales obtenidos.

Antes de continuar, intenta responder a las siguientes cuestiones de forma 
razonada:
1. ¿Cuánto vale el potencial si K=|D|?
2. ¿Qué puedes decir del comportamiento respecto a K (crece, decrece,...)?

Representa los de valores del potencial respecto a K para ver el comportamiento 
de la evolución del número de clusters en el ejemplo `blob_data.csv`.
=#

# D  : Dataset de puntos
# N  : Los potenciales se van a calcular de 1 a N clusters (N ≤ |D|)
# rep: Nº de repeticiones para cada valor de K

function Codo(D, N, rep)
	pots = zeros(N)
	for k in 1:N
		pk = 0
		for _ in 1:rep
			(Cls, C) = k_medias(D, k)
			pk  = pk + potencial(D, Cls, C, eucl)
		end
		pots[k] = pk / rep
	end
	plot(pots)
end

df = CSV.read("./datasets/blob.csv", DataFrame, header = false)
D  = [ collect(df[j, 2:3]) for j in 1:size(df, 1) ]
Codo(D, 10, 20)

##########
# DBSCAN #
##########

## Tarea 1: Algoritmo DBSCAN
#=
A continuación se define la función `dbscan(D, ϵ, min_pts, dist)` que aplica
el algoritmo DBSCAN sobre el conjunto de datos D, usando dist como función de 
distancia, ϵ como tamaño de los entornos a comprobar, y `min_pts` como número 
de puntos mínimo para que un elemento no esté aislado.

Lee detenidamente el código para asegurarte de que entiendes cómo se ha 
programado. Ten en cuenta que, en esta versión, todo el tratamiento se hace 
por medio de los índices de los puntos de D (que se considera que es una 
colección indexada).
=#

function dbscan(D, ϵ, min_pts, dist)
	Vs  = Set()			# Conjunto de puntos visitados
	Cls = [] 			# Conjunto de Clusters encontrados	
	for p in D
		if p in Vs continue end 	# Si p ha sido visitado,pasamos al siguiente
		Ps   = [p] 					# Puntos pendientes para el cluster actual
		Cl_p = [] 					# Cluster a partir de p
		while !isempty(Ps)
			p2 = popfirst!(Ps)    		# Tomamos 1er elemento pendiente
			if (p2 in Vs) continue end	# Si ya ha sido visitado, pasamos
			push!(Vs, p2)      			# Si no, marcamos como visitado
			E = [ p for p in D if dist(p, p2) < ϵ ]	# E = ϵ-entorno de p2
			if length(E) >= min_pts  	# Si hay suficientes puntos en E
				push!(Cl_p, p2)
				append!( Ps, [ p for p in E if !(p in Vs) ] )
			end
		end
		if min_pts ≤ length(Cl_p) 	# Si Cl_p es suficientemente grande
			push!(Cls, Cl_p)		# lo añadimos
		end
	end
	return Cls
end	


## Tarea 2: Prueba y Representación
#=
Comprueba, cambiando los parámetros del algoritmo DBSCAN, las propiedades de 
clusterización que presenta (por ejemplo, sobre los conjuntos de datos que 
usaste con K-medias), y compara sus resultados con los que obtuvimos en el 
ejercicio anterior.
=#

# Ejemplo 1: Solo para ver cómo se puede usar, ningún interés más

D   = [ 10 .* rand(2) for _ in 1:4000 ]
cls = dbscan(D, .25, 5, eucl)
pl  = plot(first.(D), last.(D), seriestype="scatter", mc=:white, markersize=2)
for cl in cls
	pl = plot!(first.(cl), last.(cl), seriestype="scatter", markersize=2)
end
pl

# Ejemplo 2

df = CSV.read("./datasets/blob.csv", DataFrame, header=false)
D  = [ collect(df[j, 2:3]) for j in 1:size(df, 1) ]
pl = plot(first.(D), last.(D), seriestype="scatter", mc=:white, markersize=2)

# Función de test para DBSCAN
function testDBSCAN(D,ϵ,min_pts)
	cls = dbscan(D, ϵ, min_pts, eucl)
	for cl in cls
		pl  = plot!(first.(cl), last.(cl), seriestype="scatter",markersize=2)
	end
	pl
end

testDBSCAN(D, 0.15, 10)
testDBSCAN(D, 0.30, 15)

#########
# AGNES #
#########
#=
En los siguientes pasos vamos a dar una implementación del algoritmo de 
Clustering Jerárquico AGNES. Para ello, vamos a partir de un conjunto de datos 
indexado, D (todos como vectores de un mismo espacio vectorial), y vamos a 
trabajar con los clusteres como conjuntos (colecciones) de índices (de los 
elementos que contienen de D).

## Tarea 1: Distancia entre clusters

Define la función `d_cl(c₁, c₂, D)` que recibe una colección de vectores de la 
misma dimensión, D, y una función de distancia, d, y devuelve la distancia entre 
los clusters.

	Sobre distancias entre conjuntos

    Se pueden introducir variantes en este algoritmo cambiando la forma de medir 
	la distancia entre clusters. Es lo que se conoce como "Métodos de Conexión": 
	supuesto que tenemos una distancia, d, definida en D, las distancias entre 
	clusters más habituales son:
    * Conexión completa:  d_max(C₁,C₂)  = max{d(x₁,x₂): x₁ ∈ C₁, x₂ ∈ C₂}
    * Conexión simple:    d_min(C₁,C₂)  = min{d(x₁,x₂): x₁ ∈ C₁, x₂ ∈ C₂}
    * Conexión media:     d_mean(C₁,C₂) = mean{d(x₁,x₂): x₁ ∈ C₁, x₂ ∈ C₂}
    * Conexión centroide: d_cent(C₁,C₂) = d(c₁,c₂), donde cᵢ = centroide(Cᵢ)
=#

# Función de distancia entre clusters 
#   aquí usamos la minimización de la distancia euclídea

function d_cl(c1, c2, D)
	if c1 == c2
		return Inf # No queremos que estas salgan como mínimos
	else
		return minimum( [ eucl(D[i], D[j]) for i in c1 for j in c2 ] )
	end
end

#=
## Tarea 2: Algoritmo AGNES

Haciendo uso de la Tarea 1, define la función `agnes(D, K)` que ejecuta el 
algoritmo AGNES sobre $D$ hasta quedarse con K clusters.
=#

# Función de Clustering Jerárquico
#    Trabajamos con los clusters como conjuntos de índices
#    El objetivo es llegar a tener K clusters

function agnes(D, K; debug=true)
	# Inicialmente, cada cluster contiene un único punto de D
	Cls = [ [i] for i in 1:length(D) ]
	i = 0
	debug && println("Etapa 0: $Cls")
	# El siguiente proceso se itera hasta obtener el nº de clusters deseados
	#   (en cada iteración se reduce en 1 el nº de clusters)
	while length(Cls) > K
		i = i + 1
		# Calculamos las distancias entre todos los clusters
		Distancias = Dict( [(x, y) => d_cl(x, y, D) for x in Cls for y in Cls if y != x] )
		# Y seleccionamos los clusters más cercanos
		(c1, c2) = argmin(Distancias)
		debug && println("   Clusters más cercanos: $c1 -- $c2\n")
		# Construimos el cluster con la unión de los más cercanos
		#   (lo ordenamos para que sea más fácil la lectura)
		c12 = sort( vcat(c1, c2) )
		# Añadimos esta unión y eliminamos los originales
		push!(Cls, c12)
		remove!(Cls, c1)
		remove!(Cls, c2)
		debug && println("Etapa $i: $Cls")
	end
	return	[ [D[i] for i in c] for c in Cls ]
end

# Se proporciona una función, `remove(a, item)`que elimina todas las apariciones 
# del elemento `item` de la colección `a`:

# Elimina item de la colección a
function remove!(a, item)
	deleteat!(a, findall(x -> x == item, a))
end

# Prueba del algoritmo sobre un conjunto de datos artificial para comprobar cómo 
# funciona:

Ds = [ round.(10 .* rand(2), digits=1) for _ in 1:5 ]
println("D = $Ds \n")
agnes(Ds, 2)
agnes(Ds, 2, debug=false)

################
# Aplicaciones #
################

## Tarea 1: Iris
#=
1. Usa el conjunto `Iris` que vimos en la práctica anterior para comprobar si 
	alguno de los métodos anteriores hace una clusterización de los datos que 
	sea coherente con la clasificación de los mismos.
2. Haz lo mismo, con las codificaciones que obteníamos del mismo conjunto de 
	datos usando las redes neuronales como auto-codificador.
3. Como sabes, `Iris` usa 4 medidas para cada muestra de flor (`sl`, `sw`, `pl` 
	y `pw)`, dos de ellas para las dimensiones de los sépalos y dos para los 
	pétalos. Encuentra para cada medida una clusterización que discretice el 
	dataset, pasando de un conjunto de muestras con 4 valores continuos a uno de 
	muestras con 4 valores discretos (para cada medida, el cluster al que 
	pertenece).
4. Construye una red neuronal adecuada que aproxime la clasificación de `Iris` a 
	partir de las discretizaciones anteriore (es decir, el dato de entrada ya no 
	serán las 4 dimensiones anteriores, sino los 4 clusters a los que pertenecen 
	las dimensiones).
5. Repite los pasos 3 y 4 anteriores pero clusterizando bidimensionalmente, es 
	decir, encontrar un clustering para las dimensiones de los sépalos, y otro 
	para los pétalos. De esta forma, en vez de trabajar con 4 dimensiones 
	continuas convertidas en 4 dimensiones discretas, pasamos a 2 dimensiones 
	discretas.
=#


## Tarea 2: Vinos
# Repite los objetivos de la Tarea 1 pero trabajando sobre el dataset de vinos.

## Tarea 3: MNIST
# Repite los objetivos de la Tarea 1 pero trabajando sobre el dataset MNIST.