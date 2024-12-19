#############################################
## Templado Simulado (Simulated Annealing) ##
#############################################

"""
Implementación básica del Templado Simulado. Depende de:
- `Energia::Function`: Función de energía/fitness a minimizar (toma estados).
- `s0`: Estado inicial.
- `Rep:Int`: Número de intentos por ciclo (para cada valor de T).
- `vecino::Function`: Función que devuelve un vecino del estado actual.
- `T_min::Float64`: Valor mínimo de T.
- `tasa_T::Float64`: Tasa de enfriamiento (% de disminución de T).
- `ac_eq::Bool`: Indica si se acepta el cambio cuando ΔE=0.
"""
function SA(Energia::Function, s0, Rep::Int, vecino::Function, T_min::Float64,
            tasa_T::Float64, ac_eq::Bool)
    # Datos de partida
    T = 1.0
    sbest = s0 
    Ebest = E0 = Energia(s0)

    # El algoritmo itera hasta alcanzar la T_min
    while T > T_min

        # Hacemos Rep pruebas para un T fijo
        for _ in 1:Rep            
            s1 = vecino(s0)           # Tomamos un vecino (generador)
            E1 = Energia(s1)          # Calculamos su energía
            ΔE = E1 - E0              # y el incremento de energía

            # Si la energía disminuye, o es igual pero se acepta, o con prob∼T
            if ΔE ≤ 0 || (ac_eq && ΔE ==0) || rand() < T                      
                    s0 = s1                 # saltamos a ese estado
                    E0 = E1
                    # Si el nuevo estado es el mejor
                    if E0 < Ebest
                        sbest = s0              # lo almacenamos
                        Ebest = E0
                    end
            end
        end

        # Actualizamos T
        T = T * (1 - tasa_T / 100)  
    end

    # Devolvemos el mejor estado encontrado, y su energía
    return sbest, Ebest
end

#################################
## Particle Swarm Optimization ##
#################################

#=
Vamos a definir todas las estructuras y funciones auxiliares que son necesarias
para poder aplicar el modelado y solución por medio de PSO.

En general, recordemos que estamos intentando minimizar una función, f, que 
podemos evaluar puntualmente (pero no es necesario conocer su expresión).
=#

"""
- `nDim::Int`: dimensión del espacio de parámetros a explorar
- `pos::Array{Float64, 1}`: posición actual de la partícula
- `vel::Array{Float64, 1}`: velocidad actual de la partícula
- `pBest::Array{Float64, 1}`: posición en la que la partícula tiene el valor que
        mejor se ajusta a través de la historia de la partícula
- `gBest::Array{Float64, 1}`: posición en la que el grupo local tiene el valor 
        que mejor se ajusta a través de la historia del grupo local
- `fitValue::Float64`: valor de f en la posición actual
- `fitpBest::Float64`: valor de f en `pBest`
- `fitgBest::Float64`: valor de f en `gBest`
"""
mutable struct Particle
    nDim::Int
    pos::Array{Float64, 1}
    vel::Array{Float64, 1}
    pBest::Array{Float64, 1}
    gBest::Array{Float64, 1}
    fitValue::Float64
    fitpBest::Float64
    fitgBest::Float64
    
    # Constructor
    function Particle(nDim::Int)
        pos = rand(nDim)                     # Posición aleatoria (∈ [0,1]^n)
        vel = rand(nDim) - pos               # Velocidad aleatoria (∈ [-1,1]^n)
        pBest = gBest = pos                  # Memoria inicial
        fitValue = fitpBest = fitgBest = Inf # fitValue = fitpBest = fitgBest = ∞
        new(nDim, pos, vel, pBest, gBest, fitValue, fitpBest, fitgBest)
    end       
end
# p = Particle(4)

"""
Actualiza `fitValue` de `p` utilizando la función `fitFunc`.
"""
function initFitValue!(fitFunc::Function, p::Particle)
    p.fitValue = fitFunc(p.pos)
    nothing
end

"""
Actualiza posición y `fitValue` de la partícula `p` en la nueva posición.
"""
function updatePosAndFitValue!(fitFunc::Function, p::Particle)
    p.pos += p.vel
    # si la posición está fuera del espacio de parámetros, [0,1]^n, 
    #   establecemos fitValue = Inf
    for x in p.pos
        if (x < 0 || x > 1)
            p.fitValue = Inf
            return
        end
    end
    # actualiza valor
    p.fitValue = fitFunc(p.pos)
    nothing
end

"""
Actualiza `pBest` y `fitpBest` para la partícula `p`.
"""
function updatepBestAndFitpBest!(p::Particle)
    if p.fitValue < p.fitpBest 
        p.fitpBest  = p.fitValue
        p.pBest = p.pos
    end
    nothing
end

"""
Actualiza `vel` de la partícula `p`.
"""
function updateVel!(p::Particle, w::Float64, c1::Float64, c2::Float64)
    p.vel = w * p.vel + 
            c1 * rand() * (p.pBest - p.pos) + 
            c2 * rand() * (p.gBest - p.pos)
    nothing
end

"""
Devuelve los índices de los `nNeighbor` vecinos de la partícula `i` en un 
enjambre con `nParticle` partículas.
Se supone que forman una estructura cíclica: 1,2,...,n,1,2...
"""
function neighIndices(i::Int, nNeighbor::Int, nParticle::Int)
    # el número de vecinos debe ser superior a 3
    nNeighbor = max(3, nNeighbor)
    # número de vecinos a la izquierda de la partícula i-ésima
    nLeft = (nNeighbor - 1) ÷ 2
    # el índice de la primera partícula del grupo local
    startIndex = (i - nLeft)
    # el índice de la última partícula del grupo local
    endIndex = startIndex + nNeighbor -1
    # índices para el grupo local
    indices = collect(startIndex:endIndex)
    # ajusta los índices para que estén en range(1:nParticle)
    for i in 1:nNeighbor
        if indices[i] < 1
            indices[i] += nParticle
        elseif indices[i] > nParticle
            indices[i] -= nParticle
        end
    end
    indices
end
# neighIndices(1, 5, 40)  

"""
- `fitFunc::Function`: función que debe evaluarse
- `nDim::Int`: dimensión del espacio de parámetros a explorar
- `nParticle::Int`: número de partículas de un enjambre
- `nNeighbor::Int`: número de vecinos (partículas) en un grupo local
- `nIter::Int`: número de iteraciones de actualización del ejambre
- `c1::Float64`: constante cognitiva
- `c2::Float64`: constante social
- `wMax::Float64`: valor máximo del peso de la inercia
- `wMin::Float64`: valor mínimo del peso de la inercia
- `w::Float64`: valor actual del peso de inercia
- `gBest::Array{Float64, 1}`: posición en la que el enjambre tiene el valor 
        mejor a lo largo de la historia
- `fitgBest::Float64`: valor en `gBest`
- `particles::Array{Particle, 1}`: partículas del enjambre
"""
mutable struct Swarm
    fitFunc::Function
    nDim::Int
    nParticle::Int
    nNeighbor::Int
    nIter::Int
    c1::Float64
    c2::Float64
    wMax::Float64
    wMin::Float64
    w::Float64
    gBest::Array{Float64, 1}    
    fitgBest::Float64
    particles::Array{Particle, 1}
    # Constructor
    function Swarm(fitFunc::Function, 
                   nDim::Int; 
                    nParticle::Int=40, 
                    nNeighbor::Int=3, 
                    nIter::Int=2000,
                    c1::Float64=2.0, 
                    c2::Float64=2.0,
                    wMax::Float64=0.9, 
                    wMin::Float64=0.4)
        
        # El tamaño del vecindario no puede superar el del enjambre
        if nNeighbor > nParticle  
            nNeighbor = nParticle
        end    
        w = wMax
        gBest = rand(nDim)
        fitgBest = Inf

        # Crear el enjambre con nPartículas
        particles = [Particle(nDim) for i in 1:nParticle]
        new(fitFunc, nDim, nParticle, nNeighbor, nIter, 
            c1, c2, wMax, wMin, w, gBest, fitgBest, particles)        
    end       
end

# f(x)=x^2+1
# s = Swarm(f, 2)

"""
Actualiza gBest y fitgBest para cada partícula del enjambre `s`.
"""        
function updategBestAndFitgBestParticles!(s::Swarm)
    for i in 1:s.nParticle
        
        neighborIds = neighIndices(i, s.nNeighbor, s.nParticle)
        neighborFits = [s.particles[Id].fitValue for Id in neighborIds]
        fitgBest, index = findmin(neighborFits)

        if fitgBest < s.particles[i].fitgBest
            gBest = s.particles[neighborIds[index]].pos
            s.particles[i].gBest = gBest
            s.particles[i].fitgBest = fitgBest
        end
    end
    nothing
end

"""
Actualiza gBest y fitgBest para el enjambre `s`.
"""        
function updategBestAndFitgBest!(s::Swarm)
    gFits = [particle.fitValue for particle in s.particles]
    fitgBest, index = findmin(gFits)

    if fitgBest < s.fitgBest
        s.gBest = s.particles[index].pos   
        s.fitgBest = fitgBest
    end
    nothing
end

"""
Inicialización (0ª iteración) del enjambre `s`.
"""
function initSwarm(s::Swarm)
    # Reiniciar el fitValue para cada partícula
    for particle in s.particles
        initFitValue!(s.fitFunc, particle)
        updatepBestAndFitpBest!(particle)
    end
    # actualizar gBest y fitgBest para las partículas del enjambre
    updategBestAndFitgBestParticles!(s)
    # actualizar gBest y fitgBest para el enjambre
    updategBestAndFitgBest!(s)
    nothing
end

"""
Actualiza el peso de inercia después de cada iteración.
"""
function updateInertia!(s::Swarm)
    dw = (s.wMax - s.wMin)/s.nIter
    s.w -= dw
    nothing
end

"""
Actualiza las partículas del enjambre `s`.
"""
function updateParticles!(s::Swarm)
    for particle in s.particles
        updateVel!(particle, s.w, s.c1, s.c2)
        updatePosAndFitValue!(s.fitFunc, particle)
    end
    nothing
end

"""
Una iteración para el enjambre `s`.
"""
function updateSwarm!(s::Swarm)
    # actualiza velocidad, posición y fitness de las partículas del enjambre
    updateParticles!(s::Swarm)
    # actualizar los valores gBest y fitgBest de cada partícula del enjambre
    updategBestAndFitgBestParticles!(s::Swarm)
    # actualizar el gBest y fitgBest para el enjambre
    updategBestAndFitgBest!(s::Swarm) 
    # actualizar el peso de inercia w para cada partícula del enjambre
    updateInertia!(s::Swarm)
    nothing 
end



"""
Crea un enjambre con las características pedidas y ejecuta PSO con ese enjambre 
nIter pasos. 
Devuelve la mejor posición encontrada, y el valor en esa posición.
"""

function swarmFit(fitFunc::Function, 
                  nDim::Int; 
                    nParticle::Int = 10, 
                    nIter::Int = 100, 
                    nNeighbor::Int = 3)
    # Crea el ejambre y lo inicializa
    s = Swarm(fitFunc, nDim, nParticle=nParticle, nIter=nIter, nNeighbor=nNeighbor)
    initSwarm(s)
    
    # Ejecuta la nIter actualizaciones del enjambre
    for i in 1:s.nIter
        updateSwarm!(s)
    end
    # Devuelve la posición de la mejor solución encontrada
    return s.gBest, s.fitgBest
end

################
### Test
################

# f(x) = x[1]^2 + x[2]^2
# s = Swarm(f, 2, nParticle=4)
# initSwarm(s)
# println(s.particles[1])
# updateSwarm!(s)
# println(s.particles[1])
# updateSwarm!(s)
# println(s.particles[1])
# swarmFit(f, 2, nParticle = 100, nIter = 50, nNeighbor = 10)


print("Librería Opt cargada con éxito")