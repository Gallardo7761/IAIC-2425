# Estructura que define un juego genérico con funciones como campos
struct JuegoGenerico
    acc_disponibles::Function   # s   -> colección de acciones aplicables a `s`
    aplica_acc::Function        # s,a -> estado resultante de aplicar `a` a `s`
    es_terminal::Function       # s   -> true/false decide si `s` es terminal
    resultado::Function         # s,p -> Ganancia de `p` en el estado `s`
end

# Definición del Nodo de MCTS
mutable struct Nodo
    estado                      # Estado del juego en este nodo
    padre::Union{Nodo, Nothing} # Nodo padre
    hijos::Vector{Nodo}         # Hijos del nodo
    visitas::Int64              # Número de veces que se visitó este nodo
    recompensa::Float64         # Recompensa acumulada en este nodo
    jugador::Int                # Jugador que ha provocado este nodo

    # Método de creación de nodos
    function Nodo(estado, padre, jugador)
        new(estado, padre, Nodo[], 0, 0.0, jugador)
    end
end

# Función principal MCTS
#   s0,g,n,p -> Mejor acción para el jugador p aplicando n pasos de MCTS en el 
#               juego g, y comenzando desde el estado s0
function mcts(s0, g::JuegoGenerico, n_iter::Int64, jugador_actual)
    # Nodo inicial, con sus nodos hijo
    n0 = Nodo(s0, nothing, jugador_actual)

    # Bucle principal
    for _ in 1:n_iter
        # 1. Selección del nodo a explorar a partir de n0
        n = seleccionaUCB1(n0)

        # 2. Expansión del nodo seleccionado
        expande(n, g)

        # 3. Simulación
        if !isempty(n.hijos)
            n = rand(n.hijos)  # Elige un hijo aleatoriamente para simular
        end
        r = simula(n.estado, g, n.jugador)

        # 4. Retropropagación
        retropropaga(n, r)
    end

    # Elegir la mejor acción (hijo con más visitas)
    mejor_hijo = argmax(n -> n.visitas, n0.hijos)
    return mejor_hijo.estado  # Retorna el mejor estado siguiente
end


# Función UCB1 (Upper Confidence Bound) para la selección del nodo
function ucb1(n::Nodo, exp_p::Float64 = 1.414)
    if n.visitas == 0
        return Inf
    else
        return (n.recompensa / n.visitas) + exp_p * sqrt(log(n.padre.visitas) / n.visitas)
    end
end

# Selección: Escoge el mejor nodo en base a UCB1. Si hay un árbol ya de 
#           descendientes, profundiza en el árbol usando UCB1 para seleccionar
#           qué hoja desarrollar
function seleccionaUCB1(n::Nodo)
    while !isempty(n.hijos)
        n = argmax(n1 -> ucb1(n1), n.hijos)
    end
    return n
end

# Expansión: Añade todos los nodos hijos de n usando las acciones disponibles
#           del juego. Si el nodo a expandir es terminal, no hace nada
function expande(n::Nodo, g::JuegoGenerico)
    if !g.es_terminal(n.estado)
        for a in g.acc_disponibles(n.estado)        # Recorre las acciones
            s = g.aplica_acc(n.estado, a)           #   las aplica
            push!(n.hijos, Nodo(s, n, n.jugador))   #   y crea el nodo hijo
        end
    end
end

# Simulación: Simula el resto del juego de manera aleatoria hasta llegar a un 
#           nodo terminal. Devuelve el resultado del estado terminal para el 
#           jugador que ha lanzado la exploración. 
#       Nota: Observa que no usa nodos, solo estados, porque es información
#             que no queremos almacenar. Corresponde a un muestreo aleatorio
function simula(s, g::JuegoGenerico, p)
    while !g.es_terminal(s)
        a = rand(g.acc_disponibles(s))  # Selección aleatoria de acción
        s = g.aplica_acc(s, a)          # cálculo del estado obtenido
    end
    return g.resultado(s, p) # Devuelve la ganancia del jugador en s
end

# Retropropagación: Actualiza las estadísticas de los nodos desde el nodo hoja 
#               hasta la raíz
function retropropaga(n::Nodo, result::Number)
    while n !== nothing
        n.visitas += 1
        n.recompensa += result
        result = 1 - result     # Esto vale para el caso 0/0.5/1
        n = n.padre
    end
end

println("Carga de la librería MCTS realizada con éxito")
