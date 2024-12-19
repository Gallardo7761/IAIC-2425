using DataStructures

# ----------------------------------------------------------------------------------------------------------
# Estructuras y algoritmos para Búsquedas No Informadas
# ----------------------------------------------------------------------------------------------------------

# "Estructura del Resultado en Búsquedas No Informadas (UnInformedSearch)"
struct UISResult{TState}
  status::Symbol          # :success, :timeout, :nopath
  path::Vector{TState}    # Vector de estados que forman el camino devuelto
  closedsetsize::Int64    # Número de estados que han sido testeados como objetivo
  opensetsize::Int64      # Número de estados construidos que quedan por verificar
end

# "Estructura del nodo en Búsquedas No Informadas"
struct UISNode{TState}
  data::TState                              # Contenido del estado/nodo 
  depth::Int64                              # Profundidad a la que se encuentra en el árbol de búsqueda
  parent::Union{UISNode{TState}, Nothing}   # Padre del estado (otro estado, o Nothing)
end

# "Estructura para el proceso de Búsquedas DFS"
mutable struct DFSProcess{TState, THash}      
  openset::Stack{UISNode{TState}}   # Pila de estados abiertos
  closedset::Set{THash}             # Conjunto de estados cerrados (almacenados como hash)
  start_time::Float64               # Instante de comienzo (para acotar el timeout)
end

# "Estructura para el proceso de Búsquedas BFS"
mutable struct BFSProcess{TState, THash}
  openset::Deque{UISNode{TState}}   # Cola de estados abiertos
  closedset::Set{THash}             # Conjunto de estados cerrados (almacenados como hash)
  start_time::Float64               # Instante de comienzo (para acotar el timeout)
end

# ----------------------------------------------------------------------------------------------------------
# Funciones para DFS
# ----------------------------------------------------------------------------------------------------------

"""
    _DFS!(search_state::DFSState{TState, THash}, neighbours, start, goal, isgoal, hashfn, timeout, maxdepth, enable_closedset) where {TState, THash}

Función que realmente ejecuta el algoritmo que conocemos por DFS, se usa por DFS y por iterative_DFS
"""
function _DFS!(search_state::DFSProcess{TState, THash}, neighbours, start, goal, isgoal, hashfn, timeout, maxdepth, enable_closedset,) where {TState, THash}
  while !isempty(search_state.openset)  # Mientras haya estados en la pila de estados abiertos
    node = pop!(search_state.openset)       # extraer el primero de la pila
    node_data = node.data                   # leer su contenido
    if isgoal(node_data, goal)              # Si el contenido verifica las propiedades de ser final
      return UISResult(:success, reconstructpath(node), length(search_state.closedset), length(search_state.openset), )
    end
    if timeout < Inf && time() - search_state.start_time >= timeout    # El procedimiento también puede parar por exceso de tiempo de ejecución
      return UISResult(:timeout, reconstructpath(node), length(search_state.closedset), length(search_state.openset), )
    end
    # Si no hay razones para parar
    neighbours_data = collect(neighbours(node_data))  # creamos un array con los vecinos del estado actual
    reverse!(neighbours_data)                         # invertimoa su orden para recorrerlos en el orden que necesita DFS
    for neighbour in neighbours_data                  # Para cada vecino (hijo):
      new_depth = node.depth + 1                            # Aumentamos su profundidad en 1
      if (enable_closedset && hashfn(neighbour) in search_state.closedset) || new_depth > maxdepth # Si hemos activado comprobar cerrados y el nodo ya fue visitado, o hemos superado la profundidad máxima
        continue                                                # cortamos la evaluación de este nodo
      end                                                                                          
      neighbour_node = UISNode(neighbour, new_depth, node)   # Creamos un nuevo estado con el vecino actual
      push!(search_state.openset, neighbour_node)                         # y lo metemos en la pila de nodos abiertos
    end
    if enable_closedset    # Si hemos activado comprobar cerrados
      push!(search_state.closedset, hashfn(node_data))  # Meter el contenido del nodo actual al conjunto de estados cerrados
    end
  end
  # Si hemos llegado aquí, es que ya no quedan estados que evaluar en la lista de estados abiertos
  return UISResult(:nopath, [start], length(search_state.closedset), length(search_state.openset), )
end

"""
Ejecuta el algoritmo DFS para obtener el mejor camino que conecta el estado inicial con un objetivo. Hace uso de `_DFS!`.

# Salida
Devuelve una estructura con los siguientes campos:
- `status`: un Symbol que indica el tipo de resultado en la búsqueda. Puede ser:
    - `:success`: el algoritmo ha encontrado un camino del nodo inicial al objetivo.
    - `:timeout`: el algoritmo ha agotado el tiempo y ha obtenido solo un camino parcial (que se devuelve en el campo `path`).
    - `:nopath`: el algoritmo no ha encontrado un camino al objetivo, en `path` se devuelve el camino al mejor estado encontrado.
- `path`: un array de estados desde el estado inicial al objetivo (o al mejor estado encontrado).
- `closedsetsize`: sobre cuántos estados ha probado el algoritmo si son el objetivo (tamaño del conjunto de estados cerrados).
- `opensetsize`: cuántos estados permanecen en el conjunto de estados abiertos cuando el algoritmo ha acabado.

# Argumentos (solo son obligatorios los 3 primeros argumentos, los demás son opcionales):
- `neighbours`: una función que toma un estado y devuelve los estados vecinos como un array (o un iterable).
- `start`: el estado inicial, el tipo del estado es completamente libre.
- `goal`: el estado objetivo, el tipo es libre, normalmente suele ser el mismo tipo que el inicial.
- `isgoal`: una función que toma un estado y el objetivo y evalúa si se ha alcanzado (por defecto, ==).
- `hashfn`: una función que toma un estado y devuelve una representación compacta para ser usada como clave de un diccionario (normalmente, un UInt, Int, String), por defecto es la función hash base. Es un campo muy importante para componer estados con el fin de evitar duplicados. *CUIDADO*: estados que contienen arrays como campos pueden devolver un hash diferente cada vez que se ejecuta. Si este es el caso, debe pasarse una función hashfn que siempre devuelve el mismo valor para el mismo estado.
- `timeout`: tiempo máximo (en segundos) tras los que el algoritmo para y devuelve el mejor camino parcial obtenido (al estado con menor heurística). Por defecto, no está limitado. Ten en cuenta que el algoritmo se ejecutará *al menos* durante el tiempo especificado. Por defecto es Inf.
- `maxdepth`: cota máxima para la profundidad alcanzada dentro del árbol de búsqueda. La búsqueda puede dar como resultado :nopath incluso aunque exista un camino al objetivo (si está a una profundidad mayor). Por defecto, es el valor máximo del tipo de dato Int64.
- `enable_closedset`: guarda una traza de los nodos visitados para evitar visitarlos de nuevo. Por defecto, tiene un valor de `true`. Puede ser interesante desactivarlo si se sabe a priori que no hay ciclos en el grafo que representa el espacio de estados (y, por tanto, no se pueden repetir estados).
"""
function DFS(neighbours, start, goal; isgoal = defaultisgoal, hashfn = hash, timeout = Inf, maxdepth = typemax(Int64), enable_closedset = true, kwargs..., )
  start_time = time()             # Situamos el tiempo de inicio como tiempo actual del sistema
  start_hash = hashfn(start)      # codificamos el contenido del estado inicial
  start_node = UISNode(start, 0, nothing)                      # Construimos el Estado actual
  stack = Stack{typeof(start_node)}()                                       # 
  push!(stack, start_node)                                                  # Pila inicial, solo con el estado inicial
  search_state = DFSProcess(stack, Set{typeof(start_hash)}(), start_time)   # Estructura de proceso DFS inicial (con conjunto inicial de cerrados vacío)
  # Llamamos a _DFS! para ejecutar el problema construido
  return _DFS!(search_state, neighbours, start, goal, isgoal, hashfn, timeout, maxdepth, enable_closedset, )
end

"""
Ejecuta el algoritmo iterative_DFS para obtener el mejor camino que conecta el estado inicial con un objetivo. Hace uso de `_BFS!`.

# Salida
Devuelve una estructura con los siguientes campos:
- `status`: un Symbol que indica el tipo de resultado en la búsqueda. Puede ser:
    - `:success`: el algoritmo ha encontrado un camino del nodo inicial al objetivo
    - `:timeout`: el algoritmo ha agotado el tiempo y ha obtenido solo un camino parcial (que se devuelve en el campo `path`)
    - `:nopath`: el algoritmo no ha encontrado un camino al objetivo, en `path` se devuelve el camino al mejor estado encontrado
- `path`: un array de estados desde el estado inicial al objetivo (o al mejor estado encontrado)
- `closedsetsize`: sobre cuántos estados ha probado el algoritmo si son el objetivo (tamaño del conjunto de estados cerrados)
- `opensetsize`: cuántos estados permanecen en el conjunto de estados abiertos cuando el algoritmo ha acabado

# Argumentos (solo son obligatorios los 3 primeros argumentos, los demás son opcionales):
- `neighbours`: una función que toma un estado y devuelve los estados vecinos como un array (o un iterable)
- `start`: el estado inicial, el tipo del estado es completamente libre
- `goal`: el estado objetivo, el tipo es libre, normalmente suele ser el mismo tipo que el inicial
- `isgoal`: una función que toma un estado y el objetivo y evalúa si se ha alcanzado (por defecto, ==)
- `hashfn`: una función que toma un estado y devuelve una representación compacta para ser usada como clave de un diccionario (normalmente, un UInt, Int, String), por defecto es la función hash base. Es un campo muy importante para componer estados con el fin de evitar duplicados. *CUIDADO*: estados que contiene arrays como campos pueden devolver un hash diferente  cada vez! Si este es el caso, has de pasar una función hashfn que siempre devuelve el mismo valor para el mismo estado!
- `timeout`: tiempo máximo (en segundos) tras los que el algoritmo para y devuelve el mejor camino parcial obtenido (al estado con menor heurística). Por defecto, no está limitado. Ten en cuenta que el algoritmo se ejecutará *al menos* durante el tiempo especificado. Por defecto es Inf.
- `maxdepth`: cota máxima para la profundidad alcanzada dentro del árbol de búsqueda. Puede dar como resultado un :nopath incluso aunque exista un camino al objetivo (si está a una profundidad mayor). Por defecto, es el valor máximo almacenable en el tipo Int64.
- `enable_closedset`: guarda una traza de los nodos visitados para evitar visitarlos de nuevo. Puedes querer desactivar esta opción si sabes a priori que no hay ciclos en el grafo que representa el espacio de estados. Por defecto, tiene un valor de `true`.
"""
function iterative_DFS(neighbours, start, goal; isgoal = defaultisgoal, hashfn = hash, timeout = Inf, maxdepth = typemax(Int64), enable_closedset = true, kwargs..., )
  start_time = time()
  end_time = start_time + timeout
  closedsetsize = 0
  opensetsize = 0
  for depth = 0:maxdepth
    depth_first_timeout = max(end_time - time(), 0.0)
    res = DFS(neighbours, start, goal; isgoal, hashfn, enable_closedset, maxdepth = depth, timeout = depth_first_timeout)
    if res.status in (:success, :timeout)
      return res
    end
    closedsetsize = res.closedsetsize
    opensetsize = res.opensetsize
  end
  return UISResult(:nopath, [start], closedsetsize, opensetsize)
end

# ----------------------------------------------------------------------------------------------------------
# Funciones para BFS
# ----------------------------------------------------------------------------------------------------------

"""
    _BFS!(search_state::BFSProcess{TState, THash}, neighbours, start, goal, isgoal, hashfn, timeout, maxdepth, enable_closedset) where {TState, THash}

Función que realmente ejecuta el algoritmo que conocemos por BFS
"""
function _BFS!(search_state::BFSProcess{TState, THash}, neighbours, start, goal, isgoal, hashfn, timeout, maxdepth, enable_closedset,) where {TState, THash}
  while !isempty(search_state.openset)
    node = popfirst!(search_state.openset)      # Los nodos abiertos son una Cola ahora
    node_data = node.data
    if isgoal(node_data, goal)
      return UISResult(:success, reconstructpath(node), length(search_state.closedset), length(search_state.openset), )
    end
    if timeout < Inf && time() - search_state.start_time >= timeout
      return UISResult(:timeout, reconstructpath(node), length(search_state.closedset), length(search_state.openset), )
    end
    # No tenemos que invertir el orden de los vecinos
    for neighbour in neighbours(node_data)
      new_depth = node.depth + 1
      if (enable_closedset && hashfn(neighbour) in search_state.closedset) || new_depth > maxdepth
        continue
      end
      neighbour_node = UISNode(neighbour, new_depth, node)
      push!(search_state.openset, neighbour_node)
    end
    if enable_closedset
      push!(search_state.closedset, hashfn(node_data))
    end
  end

  return UISResult(:nopath, [start], length(search_state.closedset), length(search_state.openset), )
end

"""
Ejecuta el algoritmo BFS para obtener el mejor camino que conecta el estado inicial con un objetivo. Hace uso de `_BFS!`.

# Salida
Devuelve una estructura con los siguientes campos:
- `status`: un Symbol que indica el tipo de resultado en la búsqueda. Puede ser:
    - `:success`: el algoritmo ha encontrado un camino del nodo inicial al objetivo
    - `:timeout`: el algoritmo ha agotado el tiempo y ha obtenido solo un camino parcial (que se devuelve en el campo `path`)
    - `:nopath`: el algoritmo no ha encontrado un camino al objetivo, en `path` se devuelve el camino al mejor estado encontrado
- `path`: un array de estados desde el estado inicial al objetivo (o al mejor estado encontrado)
- `closedsetsize`: sobre cuántos estados ha probado el algoritmo si son el objetivo (tamaño del conjunto de estados cerrados)
- `opensetsize`: cuántos estados permanecen en el conjunto de estados abiertos cuando el algoritmo ha acabado

# Argumentos (solo son obligatorios los 3 primeros argumentos, los demás son opcionales)
- `neighbours`: una función que toma un estado y devuelve los estados vecinos como un array (o un iterable)
- `start`: el estado inicial, el tipo del estado es completamente libre
- `goal`: el estado objetivo, el tipo es libre, normalmente suele ser el mismo tipo que el inicial
- `isgoal`: una función que toma un estado y el objetivo y evalúa si se ha alcanzado (por defecto, ==)
- `hashfn`: una función que toma un estado y devuelve una representación compacta para ser usada como clave de un diccionario (normalmente, un UInt, Int, String), por defecto es la función hash base. Es un campo muy importante para componer estados con el fin de evitar duplicados. *CUIDADO*: estados que contiene arrays como campos pueden devolver un hash diferente  cada vez! Si este es el caso, has de pasar una función hashfn que siempre devuelve el mismo valor para el mismo estado!
- `timeout`: tiempo máximo (en segundos) tras los que el algoritmo para y devuelve el mejor camino parcial obtenido (al estado con menor heurística). Por defecto, no está limitado. Ten en cuenta que el algoritmo se ejecutará *al menos* durante el tiempo especificado. Por defecto es Inf.
- `maxdepth`: una cota máxima para la profundidad alcanzada dentro del árbol de búsqueda. Puede dar como resultado un :nopath incluso aunque exista un camino al objetivo (si está a una profundidad mayor). Por defecto, es el valor máximo almacenable en la variable.
- `enable_closedset`: guarda una traza de los nodos visitados para evitar visitarlos de nuevo. Puedes querer desactivar esta opción si sabes a priori que no hay ciclos en el grafo que representa el espacio de estados. Por defecto, tiene un valor de `true`.
"""
function BFS(neighbours, start, goal; isgoal = defaultisgoal, hashfn = hash, timeout = Inf, maxdepth = typemax(Int64), enable_closedset = true, kwargs...,)
  start_time = time()
  start_hash = hashfn(start)
  start_node = UISNode(start, 0, nothing)
  deque = Deque{typeof(start_node)}()
  push!(deque, start_node)
  search_state = BFSProcess(deque, Set{typeof(start_hash)}(), start_time)

  return _BFS!(search_state, neighbours, start, goal, isgoal, hashfn, timeout, maxdepth, enable_closedset, )
end

# ----------------------------------------------------------------------------------------------------------
# Estructuras y Funciones para A*
# ----------------------------------------------------------------------------------------------------------

"Estructura del Resultado en Búsquedas A*"
struct AStarResult{TState, TCost <: Number}
  status::Symbol          # :success, :timeout, :nopath
  path::Vector{TState}    # Vector de estados que forman el camino devuelto
  cost::TCost             # Coste del camino construido
  closedsetsize::Int64    # Número de estados que han sido testeados como objetivo
  opensetsize::Int64      # Número de estados construidos que quedan por verificar
end

"""Nodo del árbol de estados a explorar para A*"""
mutable struct AStarNode{TState, TCost <: Number}
  data::TState                                      # Contenido del estado/nodo 
  g::TCost                                          # Función g de A*
  f::TCost                                          # Función f de A*
  parent::Union{AStarNode{TState, TCost}, Nothing}  # Padre del estado (otro estado, o Nothing)
end

"Ordenación de lo nodos por medio de sus valores f = g + h"
Base.isless(n1::AStarNode, n2::AStarNode) = Base.isless(n1.f, n2.f)


"Estructura para el proceso de búsqueda con A*. Y su inicializador"
mutable struct AStarProcess{TState, TCost <: Number, THash}
  openheap::Vector{AStarNode{TState, TCost}}            # Array de estados abiertos
  opennodedict::Dict{THash, AStarNode{TState, TCost}}   # Mapeo de hash a estados 
  closedset::Set{THash}                                 # Conjunto de estados cerrados
  start_time::Float64                                   # Tiempo de inicio del proceso
  best_node::AStarNode{TState, TCost}                   # Mejor estado alcanzado
  best_heuristic::TCost                                 # Mejor heurística alcanzada

  function AStarProcess(start_node::AStarNode{TState, TCost}, start_hash::THash, start_heuristic::TCost, ) where {TState, TCost, THash}
    start_time = time()                                 # Tiempo de inicio = Tiempo actual
    closedset = Set{THash}()                            # Conjunto estados cerrados = ∅
    openheap = [start_node]                             # Array de estados abiertos = Estado inicial
    opennodedict = Dict(start_hash => start_node)       # Mapeo inicial
    return new{TState, TCost, THash}(openheap, opennodedict, closedset, start_time, start_node, start_heuristic, )
  end
end

"""
    _astar!(astar_state::AStarProcess{TState, TCost, THash}, neighbours, goal, heuristic,
          cost, isgoal, hashfn, timeout, maxcost, enable_closedset) where {TState, TCost <: Number, THash}

Función que realmente ejecuta el algoritmo que conocemos por A*, se usa por Astar
"""
function _astar!(astar_state::AStarProcess{TState, TCost, THash}, neighbours, goal, heuristic, cost, isgoal, hashfn, timeout, maxcost, enable_closedset,) where {TState, TCost <: Number, THash}
  # Mientras haya estados en la pila de estados abiertos
  while !isempty(astar_state.openheap)
    node = heappop!(astar_state.openheap)       # Tomamos el menor elemento del montón abiertos
    # Vamos a extender el nodo mejor
    if isgoal(node.data, goal)                  # Si su contenido es el objetivo
      return AStarResult{TState, TCost}(:success, reconstructpath(node), node.g, length(astar_state.closedset), length(astar_state.openheap), )
    end
    # Si no es un estado final
    nodehash = hashfn(node.data)                    # tomamos el hash del estado
    delete!(astar_state.opennodedict, nodehash)     # y lo eliminamos del Mapeo
    # El procedimiento también puede parar por exceso de tiempo de ejecución
    if timeout < Inf && time() - astar_state.start_time >= timeout
      return AStarResult{TState, TCost}(:timeout, reconstructpath(astar_state.best_node), astar_state.best_node.g, length(astar_state.closedset), length(astar_state.openheap), )
    end
    # Si hemos activado comprobar cerrados
    if enable_closedset
      push!(astar_state.closedset, nodehash)    # Añadimos el estado actual al conjunto de cerrados
    end
    # Si no hay razones para parar
    nodeheuristic = node.f - node.g               # Calculamos la heurística del nodo actual (a partir de la información almacenada, no recalculando la heurística)
    if nodeheuristic < astar_state.best_heuristic # Si es menor que la mejor almacenada
      astar_state.best_heuristic = nodeheuristic      # Se almacena la actual como la mejor
      astar_state.best_node = node                    # y el nodo como el mejor
    end
    neighbour_states = neighbours(node.data)      # Calculamos los vecinos del nodo actual
    for neighbour in neighbour_states             # Para cada vecino (aquí llega el proceso de extensión)
      neighbourhash = hashfn(neighbour)                   # Calculamos su hash. Si hemos activado comprobar cerrados y el nodo ya fue visitado
      if enable_closedset && neighbourhash in astar_state.closedset
        continue                                              # cortamos la evaluación de este nodo
      end
      gfromthisnode = node.g + cost(node.data, neighbour) # Calculamos el coste del vecino actual
      if gfromthisnode > maxcost                          # Si el coste del vecino supera el máximo admitido
        continue                                                # Ignoramos el nodo y continuamos con el siguiente
      end
      if neighbourhash in keys(astar_state.opennodedict)  # Si el nodo debe ser evaluado y ya tenemos su hash (lo hemos generado antes y sigue abierto)
        neighbournode = astar_state.opennodedict[neighbourhash]   # Recuperamos el estado asociado que nos da información acerca del coste por un camino anterior
        if gfromthisnode < neighbournode.g                        # Si el coste actual es menor que el anterior
          neighbourheuristic = neighbournode.f - neighbournode.g    # Recuperamos la heurística a partir del camino anterior
          neighbournode.g = gfromthisnode                           # Cambiamos el coste por el del nuevo camino
          neighbournode.f = gfromthisnode + neighbourheuristic      # Cambiamos la f por el del nuevo camino
          neighbournode.parent = node                               # Cambiamos el padre de este vecino por el nuevo vecino
          heapify!(astar_state.openheap)                            # Convertimos los abiertos en un montón ordenado
        end
      else                                                # Si no tenemos su hash (es completamente nuevo)
        neighbourheuristic = heuristic(neighbour, goal)           # Calculamos su heurística
        neighbournode = AStarNode{TState, TCost}(neighbour, gfromthisnode, gfromthisnode + neighbourheuristic, node, )
        heappush!(astar_state.openheap, neighbournode)            # Lo añadimos al montón de nodos abiertos
        push!(astar_state.opennodedict, neighbourhash => neighbournode) # y al mapeo de hash
      end
    end
  end
  return AStarResult{TState, TCost}(:nopath, reconstructpath(astar_state.best_node), astar_state.best_node.g, length(astar_state.closedset), length(astar_state.openheap), )
end

"""
astar(neighbours, start, goal;
        heuristic=defaultheuristic, cost=defaultcost, isgoal=defaultisgoal, hashfn=hash, timeout=Inf, maxcost=Inf)

Ejecuta el algoritmo A* para obtener el mejor camino que conecta el estado inicial con un objetivo.

Devuelve una estructura con los siguientes campos:
- `status`: un Symbol que indica el tipo de resultado en la búsqueda. Puede ser:
    - `:success`: el algoritmo ha encontrado un camino del nodo inicial al objetivo
    - `:timeout`: el algoritmo ha agotado el tiempo y ha obtenido solo un camino parcial (que se devuelve en el campo `path`)
    - `:nopath`: el algoritmo no ha encontrado un camino al objetivo, en `path` se devuelve el camino al mejor estado encontrado
- `path`: un array de estados desde el estado inicial al objetivo (o al mejor estado encontrado)
- `cost`: el coste del camino devuelto
- `closedsetsize`: sobre cuántos estados ha probado el algoritmo si son el objetivo (tamaño del conjunto de estados cerrados)
- `opensetsize`: cuántos estados permanecen en el conjunto de estados abiertos cuando el algoritmo ha acabado

# Argumentos (solo son obligatorios los 3 primeros argumentos, los demás son opcionales)
- `neighbours`: una función que toma un estado y devuelve los estados vecinos como un array (o un iterable)
- `start`: el estado inicial, el tipo del estado es completamente libre
- `goal`: el estado objetivo, el tipo es libre, normalmente suele ser el mismo tipo que el inicial
- `heuristic`: una función que dado un estado y el objetivo devuelve una estimación del coste de llegar hasta él. Esta estimación debe ser optimista si quieres estar seguro de obtener el mejor camino. Observa que el mejor camino puede ser muy caro de obtener, por lo que si quieres un buen camino pero no necesariamente óptimo, puedes multiplicar la heurística por una constante, el algoritmo normalmente se acelerará a coste de no dar el óptimo
- `cost`: una función que toma el estado actual y un vecino y devuelve el coste de realizar esa transición. Por defecto, todas las transiciones tienen coste 1
- `isgoal`: una función que toma un estado y el objetivo y evalúa si se ha alcanzado (por defecto, ==)
- `hashfn`: una función que toma un estado y devuelve una representación compacta para ser usada como clave de un diccionario (normalmente, un UInt, Int, String), por defecto es la función hash base. Es un campo muy importante para componer estados con el fin de evitar duplicados. *CUIDADO*: estados que contiene arrays como campos pueden devolver un hash diferente  cada vez! Si este es el caso, has de pasar una función hashfn que siempre devuelve el mismo valor para el mismo estado!
- `timeout`: tiempo máximo (en segundos) tras los que el algoritmo para y devuelve el mejor camino parcial obtenido (al estado con menor heurística). Por defecto, no está limitado. Ten en cuenta que el algoritmo se ejecutará *al menos* durante el tiempo especificado.
- `maxcost`: una cota máxima para el coste acumulado del camino. Puede dar como resultado un :nopath incluso aunque exista un camino al objetivo (con un coste mayor). Por defecto, es Inf
- `enable_closedset`: guarda una traza de los nodos visitados para evitar visitarlos de nuevo. Puedes querer desactivar esta opción si sabes a priori que no hay ciclos en el grafo que representa el espacio de estados. Por defecto, tiene un valor de `true`.
"""
function astar(neighbours, start, goal; heuristic = defaultheuristic, cost = defaultcost, isgoal = defaultisgoal, hashfn = hash, timeout = Inf, maxcost = Inf, enable_closedset = true, kwargs...,)
  start_heuristic = heuristic(start, goal)                              # heurística del estado inicial 
  start_cost = zero(start_heuristic)                                    # coste del estado inicial (0)
  start_node = AStarNode(start, start_cost, start_heuristic, nothing)   # Nodo asociado al estado (sin padre = nothing)
  start_hash = hashfn(start)                                            # hash asociado
  astar_state = AStarProcess(start_node, start_hash, start_heuristic)   # Creamos el proceso inicial para A* (usando el constructor)
  return _astar!(astar_state, neighbours, goal, heuristic, cost, isgoal, hashfn, timeout, maxcost, enable_closedset, )
end

# -----------------------------------------------------
# Funciones generales auxiliares
# -----------------------------------------------------

#=
Como es habitual usar costes (c=1), heurísticas (h=0) y comprobación de objetivos por defecto (==),
en esta sección se definen las funciones que se usarán en caso de que el usuario no asigne ninguna
función específica para el problema que quiere resolver.

Además, se ofrece una función que, a partir de un nodo, reconstruye el camino de nodos por los que
ha pasado desde el nodo inicial. En el caso particular de ejecutarlo sobre el nodo objetivo alcanzado
por el algoritmo, devolverá el camino solución (planificación).

=#

"Por defecto, cualquier transición de un estado a otro vecino tiene coste 1"
defaultcost(s1, s2) = one(Int64)

"Por defecto, la heurística devuelve 0 (BFS)"
defaultheuristic(state, goal) = zero(Int64)

"Por defecto, alcanzar el objetivo se determina con =="
defaultisgoal(state, goal) = state == goal

"Reconstrucción del camino de estados que llegan al nodo objetivo. El estado inicial se reconoce
por tener `parent = nothing`"
function reconstructpath(n)
  res = [n.data]
  while !isnothing(n.parent)
    n = n.parent
    push!(res, n.data)
  end
  return reverse!(res)
end