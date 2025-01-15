using Pkg
Pkg.activate(".")

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

using Random
using CSV
using DataFrames
using MLJ: unpack, partition
include("./lib/NN.jl"); using .NN
using Plots 	# Cargamos la librería de representación gráfica
plotly()		# Permite hacer un uso interactivo de la representación

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

# -----------------------------------------

# Lee DataFrame
df_crabs = CSV.read("./datasets/crabs.csv", DataFrame)
describe(df_crabs)

# Elimina columnas innecesarias
select!(df_crabs, Not([:rownames, :index]))

# Separa en objetivo y variables
y, X = unpack(df_crabs, ==(:sex))

# One-Hot
clases = unique(y)
y      = collect(onehot(y))

# Mapear B's y O's
transform!(X, :sp => ByRow(x -> ( (x == "B") ? 1.0 : 0.0 )) => :sp)

# Mapear columnas para normalizarlas
mapcols(c -> c .= escala(minimum(c),maximum(c),0,1).(c), X)
describe(X)

# Dividir en train/test
(Xtrain, Xtest), (ytrain, ytest) = partition((X,y), 0.8, rng=123, multi=true)

Xtrain = df_to_vectors(Xtrain)
Xtest = df_to_vectors(Xtest)

# Red
red_crabs = NN.Network([6,4,2])
NN.SGD(red_crabs, Xtrain, ytrain, 1000, 10, 0.4)

