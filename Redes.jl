using Pkg
Pkg.activate(".")
#Pkg.instantiate()

using Random
using CSV
using DataFrames
using MLJ: unpack, partition
include("./lib/NN.jl"); using .NN
using Plots 	# Cargamos la librería de representación gráfica
plotly()		# Permite hacer un uso interactivo de la representación

#########################
# Funciones de Activación
#########################

## Ejercicio 1
#=
Haciendo uso de la librería `Plots` vamos a representar gráficamente la función 
sigmoide junto a su derivada en un intervalo adecuado.

Algunas notas
    * La función sigmoide está definida en la librería `NN` como parte de la 
	función de activación `sigmoid`. Recuerda que:
			* el campo `f` tiene la definición de la función, y 
			* el campo `d` el de su derivada.
    * Para representar una función real, f(x), con la librería `Plots`, lo más 
	sencillo es usar: `plot(xs, ys)`, donde `xs` es un vector de valores de 
	entrada, e `ys` son las imágenes por f, es decir, `ys = f.(xs)`.
    * Para representar varias funciones reales, f1(x),...,fk(x), con la librería 
	`Plots`, lo más sencillo es usar: `plot(xs, [y1,...yk])`, donde `xs` es el 
	vector de valores de entrada, y cada `yj` son las imágenes por la 
	correspondiente función fj, es decir, `y = fj.(xs)`.
=#

xs = range(-10, 10, length = 100)
σ  = NN.sigmoid.f
dσ = NN.sigmoid.d
plot(xs, [σ.(xs), dσ.(xs)], labels = ["σ" "σ '"])

## Ejercicio 2

# Implementa y representa algunas de las otras funciones de activación vistas en 
# clase (en la tabla de teoría), junto con sus derivadas utilizando Julia. 
# Además, encuentra los límites lim_{𝑥→±∞} σ_𝑖(𝑥) para todas ellas (si no 
# recuerdas cómo hacerlo formalmente, hazlo experimentalmente).

### Función ReLu
reluf(x) = max(x,0)
relud(x) = (x<0) ? 0 : 1

# Si quisiéramos definir la función de activación para NN:
const sigmarelu = NN.Activation(reluf, relud)

xs = range(-5, 5, length=1000)
plot(xs, [reluf.(xs), relud.(xs)], labels=["ReLu" "ReLu'"])

### Función tanh
tanhf = tanh
tanhd(x) = 1-tanhf(x)^2

# Si quisiéramos definir la función de activación para NN:
const sigmatanh = NN.Activation(tanhf, tanhd)

xs = range(-10, 10, length=100)
plot(xs, [tanhf.(xs), tanhd.(xs)], labels=["tanh" "tanh'"])

#=
Nota
-----

Representación de superficies
	De forma parecida a la función `plot`, tenemos `surface(xs, ys, z)`, que
	representa la superficie z(x,y) en función de la malla en ℝ^2 dada por las
	divisiones `x` e `y` en los ejes.

	El siguiente ejemplo te muestra cómo podrías hacerlo.
=#

xs = ys = range(-2, 2, length = 20)
f(x,y) = sin(x)^2+cos(y)^2
surface(xs, ys, f)

###########################
# Aproximación de funciones
###########################

## Ejercicio 3

#=
Genera una red neuronal con activación sigmoide y con una sola capa oculta y 
representa la gráfica de la función que calcula (ten en cuenta que cada vez que 
generas una red, sus pesos/sesgos iniciales son aleatorios, así que la función 
cambiará).
=#

# 21 parámetros: 2*5 + 5*1 + 5+1
ANN = NN.Network([2,5,1])

for w in ANN.weights
	display(w)
end

for b in ANN.biases
	display(b)
end

# 16 parámetros: 1*5 + 5*1 + 5+1
ANN  = NN.Network([1, 5, 1])
xs   = range(-10, 10, length=100)
f(x) = NN.feed_forward(ANN, [x])[1]
plot(xs, f.(xs), label="ANN")

#=
1. ¿Puedes decir por qué siempre da resultados alredor del intervalo [0,1]?, 
¿qué podrías hacer si quieres aproximar una función que sus valores se salgan 
del intervalo [0,1]?

2. Crea una función `escala(a1, b1, a2, b2)` que devuelva la función que lleva 
línealmente el intervalo [a1,b1] al intervalo [a2,b2] (es decir, escala(a1)= a2, 
escala(b1)= b2, y los puntos intermedios los interpola linealmente).
=#

# escala linealmente un valor de [a1,b1] a [a2,b2]

function escala(a1,b1,a2,b2)
	function escala(x)
		x1 = (x - a1) / (b1 - a1)
		x2 = x1 * (b2 - a2) + a2
		x2
	end
	return escala
end

escala(0,1,3,4)(0.5)

#=
3. Explora cómo cambia la complejidad de la función obtenida a medida que 
cambias el tamaño de la capa oculta (es decir, el número de neuronas en  ella) 
o cuando añades nuevas capas.

4. Repite las pruebas cambiando la función de activación para ver qué 
diferencias introduce.
=#


## Ejercicio 4

#=
Genera y entrena redes neuronales adecuadas para aproximar las siguientes 
funciones. En las que puedas, haz una representación gráfica comparada de la 
función y de la aproximación obtenida para poder compararlas:
=#
  
# 1.  f1(x) = x^2 en [-1,1] (f1: ℝ → ℝ).

function aprox1(n)
	# Definimos la función
	f1(x) = x^2
	# Paso 1: crear los datasets X e Y
	xs = range(-1,1,length=20) 	# 20 puntos entre [-1,1]
	ys = f1.(xs)				# sus imágenes
	# Paso 2: Normalizar Y
	# 	Como f1(x) ∈ [0,1], no es necesario normalizar los datos

	# Paso 3: Convertir los datos en vectores de vectores
	v(x) = [x]
	xsnn = v.(xs)
	ysnn = v.(ys)

	# Paso 4: Crear la red inicial
	red_i = NN.Network([1, 10, 1])

	# Paso 5: Entrenar la red, obteniendo la red final
	red_f = NN.SGD(red_i, xsnn, ysnn, n, 10, 4.0)

	# Paso 6: Generar la función asociada a la red obtenida
	rnn(x) = first(NN.feed_forward(red_f, [x]))

	# Paso 7: Calcular Y según la función aproximada
	y2s = rnn.(xs)
	
	# Paso 8: Representar la función original, la aproximada y los datos usados
	plot(xs,[ys,y2s])
	plot!(xs, ys, seriestype=:scatter, label="data")
end

aprox1(100)
aprox1(1000)
aprox1(10000)
aprox1(100000)
aprox1(1000000)

# 2.  f2(x) = 1 + log(x^2 + 1) en [-1,1] (f2: ℝ → ℝ).

function aprox2(n)
	# Definimos la función
	f1(x) = 1+log(x^2+1)
	
	# Paso 1: crear los datasets X e Y
	xs = range(-1,1,length=20)
	ys = f1.(xs)
	
	# Paso 2: Normalizar Y
	miny = minimum(ys)
	maxy = maximum(ys)
	yts = escala(miny, maxy,0,1).(ys)
	
	# Paso 3: Convertir los rangos en vectores de vectores
	v(x) = [x]
	xsnn = v.(xs)
	ysnn = v.(yts)
	
	# Paso 4: Crear la red incial
	red_i = NN.Network([1, 15, 1])
	
	# Paso 5: Entrenar la red, obteniendo la red final
	red_f = NN.SGD(red_i, xsnn, ysnn, n, 10, 3.0)
	
	# Paso 6: Generar la función asociada a la red obtenida
	rnn(x) = first(NN.feed_forward(red_f, [x]))

	# Paso 7: Calcular Y según la función aproximada
	y2s = rnn.(xs)
	y2s = escala(0,1,miny,maxy).(y2s)

	# Paso 8: Representar todo
	plot(xs,[ys,y2s])
	#plot!(xs, ys, seriestype=:scatter, label="data")
end

aprox2(1000)

# 3.  f3(x,y) = x^2 + y^2 en [-1,1]×[-1,1] (f3: ℝ^2 → ℝ)

function aprox3(n)
	# Definimos la función
	f3(x) = x[1]^2 + x[2]^2
	
	# Paso 1: crear los datasets X e Y
	
	x1s = range(-1,1,length=10)
	x2s = range(-1,1,length=10)
	xs = [[x1,x2] for x1 in x1s for x2 in x2s]
	ys = f3.(xs)
	
	# Paso 2: Normalizar Y
	miny = minimum(ys)
	maxy = maximum(ys)
	yts = escala(miny, maxy, 0, 2).(ys)
	
	# Paso 3: Convertir los rangos en vectores de vectores
	v(x) = [x]
	xsnn = xs
	ysnn = v.(yts)
	
	# Paso 4: Crear la red incial
	red_i = NN.Network([2, 3, 1])
	
	# Paso 5: Entrenar la red, obteniendo la red final
	red_f = NN.SGD(red_i, xsnn, ysnn, n, 10, 3.0)
	
	# Paso 6: Generar la función asociada a la red obtenida
	rnn(x) = first(NN.feed_forward(red_f, x))

	# Paso 7: Calcular Y según la función aproximada
	y2s = rnn.(xs)
	y2s = escala(0, 2, miny,maxy).(y2s)
	
	# Paso 8: Representamos la función aproximada
	surface(x1s,x2s,(x,y)->rnn([x,y]))
end
aprox3(10000)

# 4.  f4(x,y,z)=(x^2+y^2, e^y-e^x) en [-1,1]×[-1,1]×[-1,1] (f4: ℝ^3 → ℝ^2).

# 5.         { 1, si x ∈ [0,1]
#      f5(x)={
#            { 0, e.o.c 


###################
# Cálculo del error
###################

## Ejercicio 5
#=
Define funciones para calcular los errores medios (absolutos y cuadráticos) 
cometidos en las aproximaciones anteriores:

err_1 = 1/N  ∑_{x∈ D} |f(x) - y(x)|
err_2 = 1/N √(∑_{x∈ D} ||f(x) - y(x)||_2^2)

donde f es la función que estamos aproximando, y(x) es la aproximación, y D es 
el conjunto de datos sobre el que estamos calculando el error.
=#


#############################################
#               Predicción                  #
#############################################

# Ejercicio 6: MNIST
####################

#=
Vamos a trabajar con el dataset MNIST que puedes bajar desde la página de la 
asignatura. Ten en cuenta que el dataset se distribuye ya dividido en dos 
conjuntos, uno de entrenamiento (con 60K ejemplos) y otro de test (con 10K 
ejemplos). Si la carga de trabajo es excesiva para tu máquina, haz todo con el 
de test y vuelve a dividirlo, aunque obtendrás resultados peores.

MNIST es un dataset que tiene como objetivo reconocer dígitos escritos a mano. 
Cada ejemplo del dataset es un vector de 785 componentes, donde:

	* la 1ª componente indica el dígito que representa (entre 0 y 9, así que hay 
	10 clases).
	* Las 784 restantes dan una representación lineal de la imagen del dígito de 
	tamaño 28×28, donde cada pixel toma una valor entre 0 y 255.

En esta primera aproximación tenemos como objetivo principal aprender a 
clasificar (predecir) la clase del dígito a partir de la imagen.
=#

###
### Funciones Auxiliares generales
###

# onehot(i,n) devuelve el elemento i-ésimo de la base n-dimensional estándar. Es
# decir, codifica en lo que se llama one-hot el dato de salida.
# Si tuviéramos 3 clases {0,1,2}, entonces: onehot(1,3) = [0, 1, 0]

function onehot(i::Integer, n::Integer)
    local result = zeros(n)
    result[i+1] = 1
    result
end

# Vamos a usar una versión especial de esta función que usa 10 dígitos
onehot(i::Integer) = onehot(i,10)

onehot(0)
onehot(7)

# Aunque vamos a manipular los datasets como dataframes, nuestra librería NN
# usa vectores para el cálculo de entrada/salida, así que definimos una función
# para convertir un dataframe en un vector de vectores:
function df_to_vectors(df)
    [collect(row) for row in eachrow(df)]
end

###
### Carga y preprocesamiento de los datos
###

# Por cuestiones de tamaño y tiempo de ejecución, vamos a trabajar con el 
# dataset mnist_test.csv (10K ejemplos), pero basta cambiar el nombre en la 
# carga para trabajar con mnist_train.csv (60K ejemplos):

# Carga y análisis básico del CSV (no tiene cabecera)
df_mnist = CSV.read("./datasets/mnist_test.csv", DataFrame, header=false)
#		la ruta es relativa desde el directorio de ejecución de Julia
#		usa pwd() para saber cuál es este directorio
propertynames(df_mnist)
describe(df_mnist)

# Muestra el dígito n del dataframe df
function show_digito(n, df)
    # Leemos la fila j-ésima del dataset
    # y nos quedamos con la imagen: 2:end
    # e invertimos la escala de grises
    pixels = [255-j for j in df[n,2:end]]

    # Convertimos el vector en una matriz de 28x28
    # Necesita ser traspuesta y rotada
    img_matrix = rotr90(reshape(pixels, 28, 28)')

	img_matrix = reshape(pixels, 28, 28)'

	# Crea la imagen usando Plots

	plot(Gray.(img_matrix./255), size=(200,200))
end

show_digito(16,df_mnist)

# Separación de Características/Objetivo: Usamos `unpack` de MLJ
y, X = unpack(df_mnist, ==(:Column1))

# División del dataframe en 80% train, 20% test: Usamos `partition` de MLJ
(Xtrain, Xtest), (ytrain, ytest) = partition((X, y), 0.8, rng=123, multi=true)

# Vectorización y normalización de las características
Xtrain = df_to_vectors(Xtrain)
Xtrain = [x ./ 255  for x in Xtrain]

Xtest = df_to_vectors(Xtest)
Xtest = [x ./ 255  for x in Xtest]

# Codificación Onehot del Objetivo
ytrain = onehot.(ytrain)
ytest = onehot.(ytest)

###
### Creación de la Red y Entrenamiento
###

Random.seed!(123)

# Crea una red 764 x 30 x 10
NN_mnist = NN.Network([28 * 28, 30, 10])

# Entrena la red con los 
NN.SGD(NN_mnist, Xtrain, ytrain, 100, 10, 0.4)

# Toma una fila del dataframe y compara el resultado de la red entrenada
# con el resultado real (muestra la imagen asociada)
function inspecciona(i)
    y_real = df_mnist[i,1]
    x = collect(df_mnist[i,2:end])
    o_red = NN.feed_forward(NN_mnist,x)
    y_red = argmax(o_red) - 1
    print((y_real, y_red, o_red))
    show_digito(i,df_mnist)
end

inspecciona(3)
inspecciona(8753)

###
### Cálculo de errores
###

# Calcula el % error que se comete en un dataset (X,Y)
function calcula_Error(X_d, Y_d)
    er = 0
    for (x,y) in zip(X_d,Y_d)
        o_red = NN.feed_forward(NN_mnist,x)
        y_red = argmax(o_red) - 1
        y_real = argmax(y) - 1
        if y_red != y_real 
            er = er + 1
        end
    end
    return er/length(Y_d)
end

calcula_Error(Xtrain,ytrain)
calcula_Error(Xtest,ytest)

# Calcula la matriz de confusión y muestra el mapa de calor
function calcula_MatrizConfusion(X_d, Y_d)
    M = zeros(10,10)
    for (x,y) in zip(X_d,Y_d)
        o_red = NN.feed_forward(NN_mnist,x)
        y_red = argmax(o_red) - 1
        y_real = argmax(y) - 1
        if y_red != y_real 
            M[y_real + 1, y_red +1] = M[y_real + 1, y_red +1] + 1
        end
    end
	p = heatmap(0:9,0:9,M,color=:greys)
	display(p)
    return M
end

calcula_MatrizConfusion(Xtrain,ytrain)
calcula_MatrizConfusion(Xtest,ytest)



# Ejercicio 7: Iris
####################

#=
Vamos a trabajar con el famoso conjunto de datos `Iris`, que contiene 150 datos 
de flores de la familia iris (*iridaceae*) con mediciones en longitud y anchura 
de sus pétalos y sépalos. Además, cada muestra tiene la especie a la que 
pertenece la muestra (*Setosa*, *Versicolor* o *Virgínica*).

Vamos a usar una combinación de las librerías `CSV` y `Dataframes` para cargar 
los datos en memoria, que tendremos que preparar para, posteriormente, entrenar 
una red neuronal que sea capaz de dar una clasificación de la especie de una 
muestra a partir de las dimensiones anotadas.
=#

#=
Tarea 1: Codificación one-hot
-----------------------------

Escribe una función, `onehot`, que reciba una lista de entrada, y devuelva la 
codificación onehot de sus elementos. Por ejemplo:

	onehot([1,2,1,3]) = [[1,0,0], [0,1,0], [1,0,0], [0,0,1]]
	onehot([a,b,a])   = [[1,0], [0,1], [1,0]]

El objetivo de esta función es convertir un dato de clasificación en un vector 
de salidas unitarias que pueda ser usado como salida para una red neuronal de 
clasificación multiclase. 

Por ejemplo, en el dataset `Iris` tenemos 3 posibles clasificaciones, por lo que 
la configuración de la capa de salida estará formada por 3 neuronas, de manera 
que la neurona de salida que mayor activación muestre indicará la clasificación 
resultante:

	Iris-setosa     -> [1, 0, 0]
	Iris-versicolor -> [0, 1, 0]
	Iris-virginica  -> [0, 0, 1]

Para ello, comencemos por dar una versión en la que se da la codificación de 
val en v:
	onehot(1,[1,2,3]) = [1.0, 0.0, 0.0]
	onehot(2,[1,2,3]) = [0.0, 1.0, 0.0]

La diferencia con la función one-hot que escribimos en el ejercicio anterior es
que ahora construye la codificación a partir del vector de valores de la clase,
no necesariamente numérico.
=#

function onehot(val, v)
	i = findfirst( x -> x == val,v)
	res = zeros(length(v))
	res[i] = 1
	res
end

# Ahora ya podemos escribir la función que devuelve la codificación de todos los 
# elementos del vector de entrada:
#   Ej: onehot([1,2,1,3]) = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], 
#			  				[1.0, 0.0, 0.0], [0.0, 0.0, 1.0]]
function onehot(vals)
	labels = unique(vals)
	map(x -> onehot(x,labels), vals)
end

onehot([1,2,1,3])
onehot(["a","b","a","c"])

#=
Tarea 2: Preparación Dataset
----------------------------

Como antes, vamos a explorar el dataset de trabajo, y vamos a separar la columna
que tiene el valor objetivo (a predecir), y preparar los conjuntos de train y 
test.
=#

iris = CSV.read("./datasets/iris.csv", DataFrame)
describe(iris)

# Separación de Características/Objetivo
y, X = unpack(iris, ==(:class))

# Codificación Onehot del Objetivo (lo hacemos ahora para que sea uniforme)
clases = unique(y)
y=collect(onehot(y))

# División del dataframe en 80% train + 20% test
(Xtrain, Xtest), (ytrain, ytest) = partition((X, y), 0.8, rng=123, multi=true)

# Vectorización y normalización de las características
Xtrain = df_to_vectors(Xtrain)
Xtrain = [x ./ 8  for x in Xtrain]

Xtest = df_to_vectors(Xtest)
Xtest = [x ./ 8  for x in Xtest]

#=
Tarea 3: Entrenamiento
----------------------

Observa que no hay ningunos valores predefinidos para la arquitectura de la red,
salvo que tiene 4 datos de entrada y 3 de salida (por la codificación onehot).
=#

red_iris = NN.Network([4, 4, 3])
NN.SGD(red_iris, Xtrain, ytrain, 1000, 10, 0.4)
# datos, conjunto entrenar, conjunto comprobar error, epoch, batch, aprox

# Calculamos el error cometido

function error_iris(X,y)	
	err2 = 0
	for (x1, y1) in zip(X, y)
		class_real = argmax(y1)
		y2 = NN.feed_forward(red_iris, x1)
		class_red = argmax(y2)
		marca=""
		if class_red != class_real 
			err2 = err2 + 1
			marca="*"
		end
		println("class = $class_real (r(x) = $class_red)$marca")
	end
	println("Error: $(err2/length(y))")
end

error_iris(Xtrain,ytrain)
error_iris(Xtest,ytest)

# Calcula la matriz de confusión y muestra el mapa de calor
function calcula_MatrizConfusion(X_d, Y_d)
    M = zeros(length(clases),length(clases))
    for (x,y) in zip(X_d,Y_d)
        o_red = NN.feed_forward(red_iris,x)
        y_red = argmax(o_red) - 1
        y_real = argmax(y) - 1
        if y_red != y_real 
            M[y_real + 1, y_red +1] = M[y_real + 1, y_red +1] + 1
        end
    end
	p = heatmap(clases,clases,M,color=:greys, clim=(0,5))
	display(p)
    return M
end

calcula_MatrizConfusion(Xtrain,ytrain)
calcula_MatrizConfusion(Xtest,ytest)


# Ejercicio 8: Aprendizaje de la Representación
################################################

#=
Vamos a usar ahora la red neuronal como un método para Aprendizaje de la 
Representación. 

Para ello, usaremos únicamente las entradas del dataset (no la clasificación), 
y vamos a entrenar una red que calcule la función identidad sobre estos datos 
(es decir, la red debe aprender a devolver el mismo vector que ha recibido como
entrada).

El objetivo habitual del Aprendizaje de la Representación es obtener una 
representación vectorial de los datos de entrada con una dimensionalidad 
distinta (normalmente, más baja, pero no es obligatorio) y que sean útiles 
como representantes de los datos originales (esa utilidad viene dada por el uso
que se vaya a hacer posteriormente). 

Una forma común para ello es usar una red simétrica que use en su capa media un 
número inferior de neuronas que en la entrada. Por ejemplo, si la entrada tiene
dimensión n, una red [n,k,n] que sea capaz de calcular la identidad podemos 
interpretar que ha conseguido almacenar en la capa intermedia la información que
necesita para recuperar todo el dato original (de n dimensiones), pero usando k 
dimensiones.

Si la red completa es capaz de calcular la función identidad, sabremos que el 
vector que sale de la capa media contiene toda la información importante del 
dato de entrada (porque a partir de esa información, la red es capaz de 
reconstruir la entrada completa).

Así pues, comenzaremos preparando el experimento con la construcción y 
entrenamiento de una red que podamos interpretar (vamos a usar el dataset iris):
=#

# Como ahora estamos interesados en la representación, podemos usar el conjunto
# total de datos (no lo separamos en train y test)

Xt = df_to_vectors(X)
Xt = [x ./ 8  for x in Xt]

# Creamos una red simétrica 4×10×2×10×4 y entrenamos la identidad con ella
red2  = NN.Network([4, 10, 2, 10, 4])
NN.SGD(red2, Xt, Xt, 3000, 10, 1.0)

# Vamos a mostrar cómo se comporta la red sobre los datos de entrada, debería 
# dar salidas muy similares a la entrada (hemos reducido la precisión a 2 
# dígitos para facilitar la comparación):
for x1 in Xt
	y2 = NN.feed_forward(red2, x1)
	x1 = map(x -> round(x, digits = 2), x1)
	y2 = map(x -> round(x, digits = 2), y2)
	println("x = $x1 -> r(x) = $y2")
end

#=
Tarea 1: Redes Codificadoras/Decodificadoras
--------------------------------------------

Define una función, `codDecod`, que reciba una red neuronal R de N capas y
una capa de corte, 1≤ n≤ N, y devuelva las dos redes, `cod` y `decod` que se 
construyen a partir de la anterior:
* `cod` es la subred que tiene en cuenta desde la capa 1 hasta la n.
* `decod` es la subred que tiene en cuenta desde la capa n hasta la última.

Lo vamos a representar de la siguiente forma:

			R = [ cod |n decod ]
=#

function codDecod(R, n)
	# Creamos dos copias (completas) de la red original
	cod = deepcopy(R)
	decod  = deepcopy(R)
	# Redefinmos el número de capas de las subredes
	cod.n_layers   = n
	decod.n_layers = R.n_layers - n + 1		
	# ... y sus tamaños
	cod.sizes      = cod.sizes[1:n]
	decod.sizes    = decod.sizes[n:end]
	# Restringimos en cada caso los pesos y sesgos que corresponden
	cod.weights    = cod.weights[1:n-1]
	decod.weights  = decod.weights[n:end]
	cod.biases     = cod.biases[1:n-1]
	decod.biases  = decod.biases[n:end]
	# Devolvemos el par de subredes
	cod, decod
end

# Comprueba que la división anterior funciona con la red anterior, es decir:
#			R = [ cod |n decod ] ⇒ R = decod ∘ cod

cod, decod = codDecod(red2, 3)
fr(r,x) = NN.feed_forward(r, x)
# Hacemos unas cuantas pruebas al azar
for i in 1:10
	x = rand(4)
	println(fr(decod, fr(cod, x)) == fr(red2, x))
end

#=
Tarea 2: Representación Gráfica
-------------------------------

Vamos a hacer una representación gráfica (de tipo scatter, de puntos) de una 
codificación en ℝ^2 del dataset `Iris`. Para ver si tiene sentido, vamos a 
aprovechar la clase de cada muestra como color, asi comprobaremos visualmente si 
hay una correspondencia entre la representación aprendida y la clase asociada.

¡Atención!
    1. Observa que, para cada ejecución de la Tarea 5, se genera una codificación 
	distinta, y podría haber aprendizajes que no proporcionasen representaciones 
	interesantes.
	2. Si usamos para la codificación la red que calcula la identidad, no es 
	obligatorio que haya una relación entre la codificación obtenida y la clase
	asociada, ya que son tareas independientes. Pero podemos hacer lo mismo con 
	una red específica para esa tarea.
=#

# Función asociada a la codificación
fcod(x) =  fr(cod,x)

# Vector de representaciones de las entradas
fX2 = fcod.(Xt)

# Separamos el vector de salidas en coordenadas x e y
X2_coorx = first.(fX2)
X2_coory = last.(fX2)
colors = [:red, :green, :blue]
markcolors = [ colors[ argmax(v) ] for v in y ]
scatter(X2_coorx, X2_coory, mc=markcolors)