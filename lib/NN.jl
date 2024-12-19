module NN

import LinearAlgebra
import Printf
import Random

"""
Define funciones de activación con dos campos:
* f: Función de activación
* d: La derivada de f (f')
"""
struct Activation
    f::Function
    d::Function
end

function sigma(x)
    1/(1+exp(-x))
end

const sigmoid = Activation(
    sigma,
    x -> sigma(x)*(1-sigma(x))
    )

struct Cost
    f::Function
    delta::Function
end

function quadratic_cost(activation::Activation)::Cost
    Cost(
        (a, y)    -> 0.5 * LinearAlgebra.norm(a-y)^2,
        (z, a, y) -> (a-y) .* activation.d.(z))
end

const cross_entropy_cost = Cost(
        (a, y)    -> sum(- y .* log.(a)- - (1-y) .* log.(1-a)),
        (z, a, y) -> a-y
    ) 

"""
Crea una Red Neuronal con los datos:

`(sizes; activation = sigmoid, cost = quadratic_cost(activation), scale_weights = true)`

* `sizes` : vector de tamaños de las capas (p.e. [10,5,2])
* `activation`: función de activación
* `cost` : función de coste
* `scale_weights`: (boolean) indicando si se deben escalar los pesos iniciales
"""
mutable struct Network
    activation::Activation
    cost::Cost
    n_layers::Int
    sizes::Vector{Int}
    weights::Vector{Array{Float64,2}}
    biases::Vector{Vector{Float64}}

    function Network(sizes; activation = sigmoid, 
                    cost = quadratic_cost(activation)
                    )::Network
            new(activation, cost, length(sizes), sizes,
                [randn(i, j) for (i, j) in zip(sizes[2:end], sizes[1:end-1])],
                [randn(i) for i in sizes[2:end]]
                )
    end
end

"""
`feed_forward(nn::Network, input::Vector)::Vector`

Evalúa la red `nn` sobre `input` y devuelve la salida de la última capa.
"""
function feed_forward(nn::Network, input::Vector)::Vector
    local a = input
    for (W,b) in zip(nn.weights, nn.biases)
        a = nn.activation.f.(W*a + b)
    end

    a
end

"""
`SGD(nn::Network,
            training_data_x::Vector{Vector{Float64}},
            training_data_y::Vector{Vector{Float64}},
            epochs::Int, batch_size::Int, eta::Float64)`

Ejecuta `epochs` pasos de entrenamiento por **Desceso del Gradiente 
Estocástico** a partir de la red `nn` usando como datos de entrada/salida 
`training_data_x`/`training_data_y` y devuelve la red entrenada.
"""
function SGD(nn::Network,
            training_data_x::Vector{Vector{Float64}},
            training_data_y::Vector{Vector{Float64}},
            epochs::Int, batch_size::Int, eta::Float64
            )
    
    for epoch in 1:epochs
        local perm = Random.randperm(length(training_data_x))
        for k in 1:batch_size:length(training_data_x)
            update!(nn,
                    training_data_x[perm[k:min(k+batch_size-1,end)]],
                    training_data_y[perm[k:min(k+batch_size-1,end)]],
                    eta)
        end

        @info @Printf.sprintf("epoch %d terminada", epoch)
    end

    nn
end

"""
`update!(nn::Network,
                batch_x::Vector{Vector{Float64}},
                batch_y::Vector{Vector{Float64}},
                eta::Float64)::Network`

Ejecuta un paso de actualización de la red `nn` para un batch, y devuelve 
la red modificada.
"""
function update!(nn::Network,
                batch_x::Vector{Vector{Float64}},
                batch_y::Vector{Vector{Float64}},
                eta::Float64)::Network
    local grad_W = [fill(0.0, size(W)) for W in nn.weights]
    local grad_b = [fill(0.0, size(b)) for b in nn.biases]

    for (x,y) in zip(batch_x, batch_y)
        (delta_grad_W, delta_grad_b) = propagate_back(nn, x, y)
        grad_W += delta_grad_W
        grad_b += delta_grad_b
    end

    nn.weights = nn.weights - (eta/length(batch_x))*grad_W
    nn.biases -= (eta / length(batch_x)) * grad_b

    nn
end

"""
`propagate_back(nn::Network, x::Vector{Float64}, 
                        y::Vector{Float64})::Tuple`
            
Ejecuta el paso de back_propagation de `nn` sobre un par `(x,y)`
y devuelve el gradiente de los pesos y los sesgos.
"""
function propagate_back(nn::Network, x::Vector{Float64}, 
                        y::Vector{Float64})::Tuple
    local grad_W = [fill(0.0, size(W)) for W in nn.weights]
    local grad_b = [fill(0.0, size(b)) for b in nn.biases]

    local z = Vector(undef, nn.n_layers-1)
    local a = Vector(undef, nn.n_layers)

    a[1] = x
    for (i, (W,b)) in enumerate(zip(nn.weights, nn.biases))
        z[i] = W * a[i] + b
        a[i+1] = nn.activation.f.(z[i])
    end

    local delta = nn.cost.delta(z[end], a[end], y)
    grad_W[end] = delta* a[end-1]'
    grad_b[end] = delta

    for l in nn.n_layers-2:-1:1
        delta = (nn.weights[l+1]' * delta) .* nn.activation.d.(z[l])
        grad_W[l] = delta * a[l]'
        grad_b[l] = delta
    end

    (grad_W, grad_b)
end

end #module
