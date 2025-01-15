using Pkg
Pkg.activate(".")

using Random
using CSV
using DataFrames
using MLJ: unpack, partition
include("./lib/NN.jl"); using .NN
using Plots 	
plotly()

# Auxiliares ------------------------------

function df_to_vectors(df)
    [collect(row) for row in eachrow(df)]
end

function onehot(val, v)
    i      = findfirst(x -> x == val, v)
    res    = zeros(length(v))
    res[i] = 1
    res
end

function onehot(vals)
    labels = unique(vals)
    map(x -> onehot(x, labels), vals)
end

function escala(a1, b1, a2, b2)
    function escala(x)
        x1 = (x - a1) / (b1 - a1)
        x2 = x1 * (b2 - a2) + a2
        x2
    end
    return escala
end

# ------------- REDES -----------------

df_iris = CSV.read("./datasets/iris.csv", DataFrame)

y, X = unpack(df_iris, ==(:class))
clases = unique(y)

transform!(df_iris, :class => ByRow( x -> onehot(x,clases)) => :class)

y, X = unpack(df_iris, ==(:class))
clases = unique(y)

(Xtrain, Xtest), (ytrain, ytest) = partition((X,y), 0.8, rng=123, multi=true)
Xtrain = df_to_vectors(Xtrain)
Xtest = df_to_vectors(Xtest)

ytrain = [Vector{Float64}(onehot(y, clases)) for y in ytrain]
ytest = [Vector{Float64}(onehot(y, clases)) for y in ytest]

red = NN.Network([4,6,3])
NN.SGD(red, Xtrain, ytrain, 1000, 10, 0.4)

function error_iris(X,y)	
	err2 = 0
	for (x1, y1) in zip(X, y)
		class_real = argmax(y1)
		y2 = NN.feed_forward(red, x1)
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

# ------------- CLUSTERING -----------------

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

# ------------- ID3 -----------------

include("./lib/ID3.jl")

data = CSV.read("./datasets/Golf.csv", DataFrame, header=true)
describe(data)

atributos = propertynames(data)[1:4]
objetivo = propertynames(data)[end]

train, test = train_test_split(data)

id3 = id3_train(data, atributos, objetivo)

println(show_arbol(id3))

true_labels = test[:, objetivo]
prediccion = ID3_predict(id3, test)

evaluacion = evalua_modelo(true_labels, prediccion)

begin
    println("\nMetricas de Evaluación:")
    println("Accuracy: ", round(evaluacion.accuracy, digits=4))

    println("\nMétricas por Clase:")
    for (label, metrica) in evaluacion.class_metricas
        println("Clase $label:")
        println("  Precisión:  ", round(metrica.precision, digits=4))
        println("  Recall:     ", round(metrica.recall, digits=4))
        println("  F1 Score:   ", round(metrica.f1_score, digits=4))
    end

    println("\nMatriz de Confusión:")
    display(evaluacion.MC)
end

display(plot_MC(evaluacion))
