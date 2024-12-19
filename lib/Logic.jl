using Satisfiability
using Crayons

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

#################### Satisfactibilidad

# Decide si F es SAT (F puede ser una fórmula o array de fórmulas)
SAT(F) = sat!(F, solver = Z3()) == :SAT

# Decide si F es TAUT (F debe ser una fórmula)
TAUT(F) = sat!(¬F, solver = Z3()) == :UNSAT

# Decide si F es INSAT (F debe ser una fórmula)
INSAT(F) = TAUT(¬F)

# Decide si F = [f_1,...,f_n] ⊧ g
CONS(F,g) = INSAT(push!(F, ¬g))
⋉ = CONS # por si queremos usarlo infijo (\ltimes)

# Decide si F y G son equivalentes
EQUIV(F,G) = TAUT(F ⟺ G)


#################### Modelos

# Función para calcular todos los modelos de una fórmula
#   ahora mismo hay que pasarle las variables involucradas en F

function models(F::BoolExpr, var::Vector{BoolExpr})
    solutions = []
    open(Z3()) do interactive_solver # la sintaxis do cierra el solver
        assert!(interactive_solver, F)
        i = 1
        status, assignment = sat!(interactive_solver) # Intentamos resolver F
        while status == :SAT                          # Mientras sea SAT
            push!(solutions, assignment)              # Almacenamos la solución
            # as10 = [(v , x ? 1 : 0) for (v,x) in assignment] # Representación -> 0/1
            # println("i = $i, modelo = $as10")         # La mostramos
            assign!(var, assignment)                  # Almacenamos las asignaciones 
                                                      # a las variables
            # Ampliamos una restricción para excluir la solución recién encontrada
            assert!(interactive_solver, not(and(var .== value(var))))
            status, assignment = sat!(interactive_solver) # Intentamos resolver F + restricciones
            i += 1
        end
    end
    return solutions
end

#################### CNF

# Con las siguientes funciones convertimos una fórmula a una equivalente CNF usando Z3.
# Es una especie de truco, ya que enviamos comandos SMT-LIB directamente a Z3 y parseamos la salida.

# Para la recuperación de la expresión en el formato de Julia, aprovechamos la característica de 
# metaprogramación del lenguaje. Como las variables individuales son de la forma z_1,z_2,... podemos
# construir objetos Expr de Julia y evaluarlos con eval(). Esto funciona porque la sintaxis para hacer 
# una Expr como or(z_1, z_2) es Expr(:call, :or, :z1, :z2).

# function make_expr(raw::Symbol)
#     result = split(String(raw), "_")    # si raw es un símbolo de variable 
#                                         # como z_i que se corresponde con
#                                         # un índice, reescribimos como z[i] 
#                                         # porque así aparece en el contexto

#     if length(result) == 1              # este caso se da si no hemos tenido 
#                                         # que dividir con _
#         return raw
        
#     elseif length(result) == 2          # y este, si es una variable compuesta
#         return Expr(:ref, Symbol(result[1]), parse(Int, result[2]))
#     end
#   end

#   make_expr(raw::Array) = Expr(:call, make_expr.(raw)...)   # multiple dispatch

# Función para pasar a CNF con z3
# function to_cnfz3(expr)
#     solver = open(Z3())
#     assert!(solver, expr)
    
#     # Aquí está el proceso Z3 que simplifica expr en una CNF (Forma Normal Conjuntiva).
#     #   ¡Cuidado!: Solo trabaja con ∧, ∨, ¬ y ⟹ (no con ⟺)
#     cmd = "(apply (then (! simp :elim-and true) elim-term-ite tseitin-cnf))"

#     # La respuesta de Z3 tiene la forma:
#         #=
#         (goals
#         (goal
#             (or z_5 z_4 (not z_1) z_3)
#             :precision precise :depth 3)
#         )
#         )

#         =#
#     # para obtener la respuesta completa hemos de usar la función nested_parens_match.
#     response = send_command(solver, cmd, is_done=nested_parens_match)
#     # Y posteriormente parsear el resultado
#     parsed = Satisfiability.split_items(response)
#     # Lo anterior nos da un array encajado de la forma 
#     #     [:goals [:goal [:or :z_5 :z_4 [:not :z_1] :z_3] ...]]
#     parsed_exprs = []
#     for item in parsed[1][2] # Saltamos los 2 primeros niveles
#         if isa(item, Array)
#             push!(parsed_exprs, item) # y almacenamos los demás
#         end
#     end
#     # Convertimos el array anterior a expresiones de Julia
#     exprs = make_expr.(parsed_exprs)
#     # y hacemos la conjunción de ellas
#     formula = and(eval.(exprs))
#     close(solver)
#     return formula, (eval.(exprs))
# end

# Extrae los literales de una cláusula como un vector de String
function literals(expr::BoolExpr)
    if expr.op == :identity
        return [expr.name]
    elseif expr.op == :not
        return ["¬" * expr.children[1].name]
    else
        lit = c -> l = c.op == :not ? ("¬" * c.children[1].name) : c.name
        return map(lit, expr.children)
    end
end

# Extrae una forma clausal de una fórmula como un Vector{Vector{String}}
# function clausal_form(expr::BoolExpr)
#     _, cls = to_cnfz3(expr)
#     return map(literals,cls)
# end

function clausal_form(expr::BoolExpr)
    _, cls = CNF(expr)
    return map(literals,cls)
end


#################### DPLL

# Ahora mismo, usa la notación DIMACS: variables 1,2,... y sus complementarios -1,-2,...

# Función DPLL
function DPLL(S::Vector{Vector{Int}}; debug=false)
    M = Vector{Vector{Int}}()
    DPLL_aux(S, Vector{Int}(), M, 0; debug)
    return M
end

# Algoritmo DPLL_aux: es donde de verdad se hace todo
# S  : Fórmula en forma Clausal
# Val: Valoración parcial que se está construyendo 
# 		(:Ins si esa rama no genera un modelo)
function DPLL_aux(S::Vector{Vector{Int}}, Val::Vector{Int}, M::Vector{Vector{Int}}, n::Int; debug=false)
    
    if isempty(S)   # Si S = [] 
        debug && println("   " * repeat("|   ",n) * "S = ∅ : Modelo = $Val")
        push!(M,Val)   
    elseif in(Vector{Int}(),S) # Si en esta rama se ha obtenido la cláusula vacía,
        debug && println("   " * repeat("|   ",n) * "S = $S : InSAT")
    else # Si no es ninguno de los casos anteriores
        debug && println("   " * repeat("|   ",n) * "S = $S : Val = $Val")
        U = unidades(S) # Miramos si hay unidades
        if !isempty(U)  # Si hay alguna: PROPAGACIÓN DE UNIDADES
            p = U[1]    #   tomamos la primera, y propagamos
            debug && println("   " * repeat("|   ",n) * "Propaga: $p") 
            DPLL_aux(propaga(S, p), push!(Val, p), M, n; debug)
        else            # Si no hay unidades: DIVISIÓN
            S1   = copy(S)    # hacemos dos copias de (S, Val)
            Val1 = copy(Val)
            S2   = copy(S)
            Val2 = copy(Val)
            
            p = S[1][1]   # tomamos una variables presente (p.e, la primera)

            # Lanzamos 2 DPLL: 
            debug && println("   " * repeat("|   ",n) * "Divide + Propaga: $p")
            DPLL_aux(propaga(S1, p), push!(Val1, p), M, n+1; debug)
            debug && println("   " * repeat("|   ",n) * "Divide + Propaga: $(-p)")
            DPLL_aux(propaga(S2, -p), push!(Val2, -p), M, n+1; debug)
        end
    end
end

# Extrae las unidades (cláusulas unitarias) de S
function unidades(S::Vector{Vector{Int}})
    return collect(Base.Flatten(filter(x -> length(x) == 1, S)))
end
# unidades( [ [1,-2], [1,2], [3], [-4] ] ) #  == [3, -4]

# Propaga la unidad p en S
function propaga(S::Vector{Vector{Int}}, p::Int)
    S_p = filter(x -> in(-p,x), S)               # Cláusulas que tienen -p
    S_p = map(x -> filter(y -> y != -p, x), S_p) #  ... y les quitamos -p
    S_o = filter(x -> !in(p, x) & !in(-p, x), S) # Cláusulas que no tienen p ni -p
                                                 # El resto, las que tienen p, no se usan
    # Devolvemos S_p ∪ S_o
    return vcat(S_p, S_o)
end
# propaga( [ [1,2], [1,-2], [2], [1,3] ], 2) == [[1], [1,3]]

# Extensión de definición de DPLL para trabajar directamente sobre BoolExpr
function DPLL(F::BoolExpr; debug=false) 
    cls = clausal_form(F)
    clsf = map( l -> occursin("¬",l) ? l[3:end] : l , Base.Iterators.flatten(cls))
    vp = sort(unique(clsf))
    evp = enumerate(vp)
    debug && println("   Correspondencia DIMACS: $(collect(evp))")
    M = DPLL(to_dimacs(cls);debug)# |> to_dimacs |> DPLL
    models ::Vector{Vector{String}} =[]
    for c in M
        dc ::Vector{String} = []
        for (i,l) in evp
            if i ∈ c push!(dc,l) end
            if (-i) ∈ c push!(dc,"¬"*l) end
        end
        push!(models, dc)
    end
    debug && println("")
    return models
end

# Convierte una forma clausal a su formato DIMACS
function to_dimacs(cls::Vector{Vector{String}}; debug=false)
    dimacs_cls::Vector{Vector{Int}} = []
    clsf = map( l -> occursin("¬",l) ? l[3:end] : l , Base.Iterators.flatten(cls))
    vp = sort(unique(clsf))
    evp = enumerate(vp)
    if debug print("Correspondencia DIMACS: $(collect(evp))") end
    for c in cls
        dc ::Vector{Int} = []
        for (i,l) in evp
            if l ∈ c push!(dc,i) end
            if ("¬"*l) ∈ c push!(dc,-i) end
        end
        push!(dimacs_cls, dc)
    end
    return dimacs_cls
end

################ Algunas funciones de representación

# Representación de Árbol de Formación

function tree(F::BoolExpr)
    Sust = Dict([   (r"implies_.+", "⟹:"), 
                    (r"not_.+", "¬:"), 
                    (r"and_.+", "∧:"), 
                    (r"or_.+", "∨:"), 
                    (r"iff_.+", "⟺:"), 
                    (r"= false", ""), 
                    (r"= true", "")])
    rep = repr(F)
    for (old,new) in Sust
        i = length(collect(eachmatch(old, rep)))
        rep = replace(rep, old => new, count=i)
    end
    return rep
end

# Representación "lineal"

function pretty(F::BoolExpr)
    Fp = pretty_aux(F)
    if Fp[1] == '('
        return chop(Fp, head=1, tail=1)
    else
        return Fp
    end
end

function pretty_aux(F::BoolExpr)
    if F.op == :identity
        return F.name
    elseif F.op == :not
        return ("¬" * pretty_aux(F.children[1]))
    elseif F.op == :or
        return ("(" * join(pretty_aux.(F.children), " ∨ ") * ")")
    elseif F.op == :and
        return ("(" * join(pretty_aux.(F.children), " ∧ ") * ")")
    elseif F.op == :implies
        return ("(" * join(pretty_aux.(F.children), " ⟹ ") * ")")
    elseif F.op == :iff
        return ("(" * join(pretty_aux.(F.children), " ⟺  ") * ")")
    else 
        return F.name
    end
end

    # Válido también para vectores de fórmulas

function pretty(F::Vector{BoolExpr})
    pretty.(F)
end

###################### Subfórmulas y profundidad

# Devuelve las subfórmulas de F, ordenadas por profundidad
function subform(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :identity
        return [G]       
    else
        return sort!(unique(push!(reduce(vcat, (subform.(G.children))), G)), by=depth)
    end
end

# Devuelve la profundidad de una fórmula
function depth(F::BoolExpr)
    if F.op == :identity
        return 1
    else
        return 1 + maximum(depth.(F.children))
    end
end

######################## Transformaciones

function simpIFF(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :iff
        G1 = simpIFF(G.children[1])
        G2 = simpIFF(G.children[2])
        G = (¬G1 ∨ G2) ∧ (¬G2 ∨ G1)
    else
        G.children = simpIFF.(G.children)
    end
    return G
end

function simpIMP(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :implies
        G1 = simpIMP(G.children[1])
        G2 = simpIMP(G.children[2])
        G = (¬G1 ∨ G2)
    else
        G.children = simpIMP.(G.children)
    end
    return G
end

function simpDNEG(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :not && G.children[1].op == :not
        G = simpDNEG(G.children[1].children[1])
    else
        G.children = simpDNEG.(G.children)
    end
    return G
end  

function deMorgan(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :not && G.children[1].op == :or
        H = G.children[1].children
        G = and(deMorgan.(not(H)))
    elseif G.op == :not && G.children[1].op == :and
        H = G.children[1].children
        G = or(deMorgan.(not(H)))
    else
        G.children = deMorgan.(G.children)
    end
    return G
end

function simpNEGOR(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :not && G.children[1].op == :or
        H = G.children[1].children
        G = and(not.(simpNEGOR.(H)))
    else
        G.children = simpNEGOR.(G.children)
    end
    return G
end

function simpNEGAND(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :not && G.children[1].op == :and
        H = G.children[1].children
        G = or(not.(simpNEGAND.(H)))
    else
        G.children = simpNEGAND.(G.children)
    end
    return G
end


function distORAND(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :or && G.children[2].op == :and
        H1 = G.children[1] 
        H2 = G.children[2].children
        G = and(map(h -> or(H1,h), H2))
    elseif G.op == :or && G.children[1].op == :and
        H1 = G.children[2] 
        H2 = G.children[1].children
        G = and(map(h -> or(H1,h), H2))
    else
        G.children = distORAND.(G.children)
    end
    return G
end

function distANDOR(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :and && G.children[2].op == :or
        H1 = G.children[1] 
        H2 = G.children[2].children
        G = or(map(h -> and(H1,h), H2))
    elseif G.op == :and && G.children[1].op == :or
        H1 = G.children[2] 
        H2 = G.children[1].children
        G = or(map(h -> and(H1,h), H2))
    else
        G.children = distANDOR.(G.children)
    end
    return G
end

function groupAND(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :and
        indGandPos = [H for H in G.children if H.op == :and]
        indGandNeg = [H for H in G.children if H.op != :and]
        G.children = indGandNeg
        for H in indGandPos
            push!(G.children, H.children...)
        end
    else
        G.children = groupAND.(G.children)
    end
    return G
end

function groupOR(F::BoolExpr)
    G = deepcopy(F)
    if G.op == :or
        indGorPos = [H for H in G.children if H.op == :or]
        indGorNeg = [H for H in G.children if H.op != :or]
        G.children = indGorNeg
        for H in indGorPos
            push!(G.children, H.children...)
        end
    else
        G.children = groupOR.(G.children)
    end
    return G
end

function CNF(F::BoolExpr)
    G = deepcopy(F)
    G = G |> simpIFF
    G = G |> simpIMP
    while occursin("¬(",pretty(G))
        G = G |> simpNEGAND |> simpNEGOR
    end
    G = G |> simpDNEG
    d = depth(G)
    for i in 1:d
        try
            G = G |> distORAND
        catch
        end
    end
    G = G |> groupOR |> groupAND 
    while depth(G) > 4
        G = G |> groupAND 
    end
    if G.op == :and
        return G,G.children
    else
        return G, [G]
    end
end