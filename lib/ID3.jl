using DataFrames
using StatsBase
using CSV
using Plots
using Random
using Statistics

##########################
## Funciones Auxiliares ##
##########################

log2a(x) = (x > 0) ? log2(x) : 0

function entropia(y)
    if length(y) == 0
        return 0.0
    end
    p = values(StatsBase.proportionmap(y))
    -sum(p .* log2a.(p))
end

# Función para calcular el mejor punto de corte para un atributo continuo
function encontrar_mejor_corte(data, atributo, obj)
    if nrow(data) <= 1
        return nothing, -Inf
    end
    
    # Ordena valores numéricos
    valores_ordenados = sort(unique(data[:, atributo]))
    if length(valores_ordenados) <= 1
        return nothing, -Inf
    end
    
    # Calcular los posibles puntos de corte (puntos medios entre valores consecutivos)
    puntos_corte = [(valores_ordenados[i] + valores_ordenados[i+1])/2 for i in 1:length(valores_ordenados)-1]
    
    # Encontrar el punto de corte con la máxima ganancia de información
    mejor_ganancia = -Inf
    mejor_corte   = nothing
    
    for c in puntos_corte
        # Dividir los datos en dos grupos
        mascara   = data[:, atributo] .<= c
        data_izq  = data[mascara, :]
        data_dcha = data[.!mascara, :]
        
        # Calcular la entropía ponderada
        prob_izq  = nrow(data_izq) / nrow(data)
        prob_dcha = nrow(data_dcha) / nrow(data)
        
        entropia_ponderada = prob_izq * entropia(data_izq[:, obj]) +
                             prob_dcha * entropia(data_dcha[:, obj])
        
        # Calcular la ganancia de información
        ganancia = entropia(data[:, obj]) - entropia_ponderada
        
        if ganancia > mejor_ganancia
            mejor_ganancia = ganancia
            mejor_corte = c
        end
    end
    
    return mejor_corte, mejor_ganancia
end

# Ganancia de Información para atributo categórico/continuo
function GI(data, atributo, obj)
    # Comprobar si atributo es continuo (numérico)
    es_continuo = eltype(data[:, atributo]) <: Number
    
    if es_continuo
        mejor_corte, mejor_ganancia = encontrar_mejor_corte(data, atributo, obj)
        return mejor_ganancia
    else
        entropia_total     = entropia(data[:, obj])
        entropia_ponderada = 0.0
        valores_atributo   = unique(data[:, atributo])
        
        for v in valores_atributo
            subdata = data[data[:, atributo] .== v, :]
            prob    = nrow(subdata) / nrow(data)
            entropia_ponderada += prob * entropia(subdata[:, obj])
        end
        
        return entropia_total - entropia_ponderada
    end
end

# Encontrar los mejores atributos y el punto de división
function encontrar_mejor_atributo(data, atributos, obj)
    mejor_ganancia = -Inf
    mejor_atr      = first(atributos)
    mejor_corte    = nothing
    
    for atr in atributos
        es_continuo = eltype(data[:, atr]) <: Number
        
        if es_continuo
            punto_corte, ganancia = encontrar_mejor_corte(data, atr, obj)
            if ganancia > mejor_ganancia
                mejor_ganancia = ganancia
                mejor_atr = atr
                mejor_corte = punto_corte
            end
        else
            ganancia = GI(data, atr, obj)
            if ganancia > mejor_ganancia
                mejor_ganancia = ganancia
                mejor_atr = atr
                mejor_corte = nothing
            end
        end
    end
    
    return mejor_atr, mejor_corte
end

# Función para dividir datos en entrenamiento y prueba
function train_test_split(
    data::DataFrame;
    train_ratio::Float64=0.8, 
    seed::Int=42)
    
    Random.seed!(seed)
    n = nrow(data)
    train_indices = sample(1:n, Int(floor(n * train_ratio)), replace=false)
    test_indices = setdiff(1:n, train_indices)
    
    train_data = data[train_indices, :]
    test_data = data[test_indices, :]
    
    return train_data, test_data
end

###############################################
## Estructura para la construcción del árbol ##
###############################################

# Estructura para representar un nodo del árbol. Puede ser de tipo 
#   Atributo    (nodo de decisión)
#   Hoja        (nodo de respuesta)
#
# Si es de tipo atributo, y es continuo, tiene un punto_corte
#
# Ejemplo Hoja:
#  
# Treenode(
#     nothing,                  # es de tipo hoja, así que no tiene atributo
#     nothing,                  # tampoco tiene punto de corte
#     Dict{Any, Treenode}(),    # ni hijos...
#     String3("No"))
#   
# Ejemplo Atributo:
#
# Treenode(
#     :Wind, 
#     Dict{Any, Treenode}       # es de tipo atributo, así que tiene hijos
#         (
#             String7("Strong") => Treenode(
#                 nothing, 
#                 nothing,
#                 Dict{Any, Treenode}(), 
#                 String3("No")), 
#             String7("Weak") => Treenode(
#                 nothing,
#                 nothing, 
#                 Dict{Any, Treenode}(), 
#                 String3("Yes"))), 
#     nothing)                  # es de tipo atributo, así que no tiene hoja

mutable struct Treenode
    atributo::Union{Symbol, Nothing}
    punto_corte::Union{Float64, Nothing} 
    hijos::Dict{Any, Treenode}
    hoja::Union{Any, Nothing}
    
    Treenode() = new(nothing, nothing, Dict(), nothing)
end

########################
## Implementación ID3 ##
########################

function id3_train(
    data::DataFrame, 
    atributos::Vector{Symbol}, 
    objetivo::Symbol, 
    min_muestras::Int = 2)

    nodo = Treenode()
    
    # Base cases
    if length(unique(data[:, objetivo])) == 1
        nodo.hoja = first(data[:, objetivo])
        return nodo
    end
    
    if isempty(atributos) || nrow(data) < min_muestras
        nodo.hoja = mode(data[:, objetivo])
        return nodo
    end
    
    # Encontrar mejor atributo y punto de corte
    mejor_at, punto_corte = encontrar_mejor_atributo(data, atributos, objetivo)
    nodo.atributo = mejor_at
    nodo.punto_corte = punto_corte
    
    # Tratar de forma diferente los atributos continuos y los categóricos
    if !isnothing(punto_corte)  # Atributos continuos
        # División binaria basada en el punto de corte
        mascara = data[:, mejor_at] .<= punto_corte
        subdatas = Dict(
            "≤ $(punto_corte)" => data[mascara, :],
            "> $(punto_corte)" => data[.!mascara, :]
        )
    else  # Atributos categóricos
        # Cortar por valores únicos
        subdatas = Dict(v => data[data[:, mejor_at] .== v, :] 
                      for v in unique(data[:, mejor_at]))
    end

    # Crear subárboles
    for (v, subdata) in subdatas
        if nrow(subdata) == 0
            hijo = Treenode()
            hijo.hoja = mode(data[:, objetivo])
        else
            hijo = id3_train(subdata, atributos, objetivo, min_muestras)
        end
        nodo.hijos[v] = hijo
    end
    
    # Crear subárboles: ¡¡¡¡ Incorrecta !!!!
    ### Esta versión es incorrecta porque no permite preguntar varias veces 
    ### por el mismo atributo numérico con diferentes cortes.
    ### Es una implementación natural para atributos categóricos, pero no
    ### para atributos numéricos
    # resto_atributos = filter(f -> f != mejor_at, atributos)
    # for (v, subdata) in subdatas
    #     if nrow(subdata) == 0
    #         hijo = Treenode()
    #         hijo.hoja = mode(data[:, objetivo])
    #     else
    #         hijo = id3_train(subdata, resto_atributos, objetivo, min_muestras)
    #     end
    #     nodo.hijos[v] = hijo
    # end
    
    return nodo
end

# Función para predecir una muestra
function ID3_predict(nodo::Treenode, muestra::DataFrameRow)
    if !isnothing(nodo.hoja)
        return nodo.hoja
    end
    
    # Manejar atributos continuos
    if !isnothing(nodo.punto_corte)
        v = muestra[nodo.atributo] <= nodo.punto_corte ? "≤ $(nodo.punto_corte)" : "> $(nodo.punto_corte)"
    else
        v = muestra[nodo.atributo]
    end
    
    if !haskey(nodo.hijos, v)
        hojas = [hijo.hoja for hijo in values(nodo.hijos) if !isnothing(hijo.hoja)]
        return isempty(hojas) ? nothing : mode(hojas)
    end
    
    return ID3_predict(nodo.hijos[v], muestra)
end

# Función para predecir múltiples muestras
function ID3_predict(nodo::Treenode, data::DataFrame)
    return [ID3_predict(nodo, data[i, :]) for i in 1:nrow(data)]
end

########################
## Representación ID3 ##
########################

function show_arbol(nodo::Treenode, depth::Int=0, prefix::String="")
    function tree_to_string(nodo::Treenode, prof::Int)
        if isnothing(nodo.atributo)
            return "$(prefix * "   "^prof)     ✅ $(nodo.hoja)"
        end
        
        # Mostrar punto de corte para atributos continuos
        split_info = isnothing(nodo.punto_corte) ? "" : " (corte en $(round(nodo.punto_corte, digits=2)))"
        nodo_str = "$(prefix * "  "^prof)   ❓: $(nodo.atributo)$(split_info)?\n"
        
        for (valor, hijo) in nodo.hijos
            hijo_str = tree_to_string(hijo, prof + 1)
            nodo_str *= "$(prefix * "  "^(prof+1)) └─ $(nodo.atributo) $(valor):\n"
            nodo_str *= "$(hijo_str)\n"
        end
        
        return nodo_str
    end
    
    function tree_info(nodo::Treenode)
        function contar_nodos(nodo::Treenode)
            if isnothing(nodo.atributo)
                return (nodos = 1, hojas = 1, prof = 0)
            end
            
            total_nodos, total_hojas, max_prof = 1, 0, 0
            
            for hijo in values(nodo.hijos)
                hijo_info = contar_nodos(hijo)
                total_nodos += hijo_info.nodos
                total_hojas += hijo_info.hojas
                max_prof = max(max_prof, hijo_info.prof)
            end
            
            return (nodos = total_nodos, hojas = total_hojas, prof = max_prof + 1)
        end
        
        info = contar_nodos(nodo)
        
        return """
        Información del árbol: 
            $(info.nodos) nodos ($(info.hojas) hojas), Profundidad $(info.prof)
        """
    end
    
    cadena_arbol = """
    Representación del Árbol de Decisión
    
    $(tree_info(nodo))
    
    Estructura del árbol:
    $(tree_to_string(nodo, 0))
    """
    
    return cadena_arbol
end

####################
## Evaluación ID3 ##
####################

function evalua_modelo(true_labels, pred_labels)
    # Matriz de confusión
    unique_labels = unique(vcat(true_labels, pred_labels))
    MC = zeros(Int, length(unique_labels), length(unique_labels))
    
    label_to_index = Dict(label => i for (i, label) in enumerate(unique_labels))
    
    for (true_label, pred_label) in zip(true_labels, pred_labels)
        true_idx = label_to_index[true_label]
        pred_idx = label_to_index[pred_label]
        MC[true_idx, pred_idx] += 1
    end
    
    # Calcular diagonal manualmente
    suma_diagonal = sum(MC[i, i] for i in 1:size(MC, 1))
    suma_total    = sum(MC)
    
    # Métricas por clase
    metricas = Dict()
    for (i, label) in enumerate(unique_labels)
        tp = MC[i, i]
        suma_fila = sum(MC[i, :])
        suma_sol  = sum(MC[:, i])
        
        precision = tp / max(suma_sol, 1e-10)  # Evitar división por cero
        recall = tp / max(suma_fila, 1e-10)
        f1_score = iszero(precision + recall) ? 0.0 : 2 * (precision * recall) / (precision + recall)
        
        metricas[label] = (
            precision = precision, 
            recall = recall, 
            f1_score = f1_score
        )
    end
    
    # Métricas globales
    accuracy = suma_diagonal / suma_total
    
    return (
        MC = MC, 
        class_metricas = metricas, 
        accuracy = accuracy,
        labels = unique_labels
    )
end

# Función para representar la matriz de confusión
function plot_MC(evaluacion)
    MC = evaluacion.MC
    labels = evaluacion.labels
    num = maximum(MC)
    fontsize = 12
    nx, ny = size(MC)
    
    # Mapa de calor para la matriz
    heatmap(
        MC, 
        title="Matiz de Confusión", 
        xlabel="Salida Predicha", 
        ylabel="Salida Real", 
        xticks=(1:nx, labels),
        yticks=(1:ny, labels),
        color=cgrad(:matter, 1+num, categorical = true)#:tab10
    )
    # Valores de la matriz
    ann = [(i,j, text(round(MC[i,j], digits=2), fontsize, :grey, :center))
                for i in 1:nx for j in 1:ny]
    annotate!(ann, linecolor=:white)
end