####################################################
#             P R I M E R  P A R C I A L           #
####################################################

# C_ij con etiqueta [000,999]
# C_ij -> C_ik si diff en 1 en solamente un digito
# 9 + 1 = 0, 0 - 1 = 9
# P = celdas prohibidas
# C(x,y) = 
#   1 si diff en primer  digito
#   2 si diff en segundo digito
#   3 si diff en tercer  digito

include("./lib/Search.jl")

P = Set{Cell}() # no vacio, celdas prohibidas

struct Cell
    x::Int,
    y::Int,
    z::Int

    function Cell(x,y,z)
        new(x,y,z)
    end
end

function get_all_cells()
    res = []
    for x in [0..9]
        for y in [0..9]
            for z in [0..9]
                push!(res,Cell(x,y,z))
            end
        end
    end
    return res
end

# Funciones para generar vecinos de una celda c
function diff_1_one_digit(c1::Cell, c2::Cell)
    x1,y1,z1 = c1.x, c1.y, c1.z
    x2,y2,z2 = c2.x, c2.y, c2.z

    for d1 in [x1,y1,z1]
        for d2 in [x2,y2,z2]
            if abs(d1-d2) == 1
                return true
            end
        end
    end

    return false
end

function neighbours(c1::Cell)
    cells = get_all_cells()
    return map(c2 -> diff_1_one_digit(c1, c2), cells)
end

# Chequear validez de una celda
function valid(c::Cell)
    return !in!(c, P)
end

# Coste de ir de una celda c1 a otra celda c2
function cost(c1::Cell, c2::Cell)
    if c1.x != c2.x
        return 1
    end

    if c1.y != c2.y
        return 2
    end

    if c1.z != c2.z
        return 3
    end

    return Inf
end

# Heurística h que estima el coste real 
function heuristic(c1::Cell, c2::Cell)
    # estimar el coste de cualquier celda
    # hasta la celda goal de forma optimista
    # sin sobreestimar el coste (1,2 o 3)
end

start = Cell(1,2,3)
goal = Cell(4,5,6)

sol = astar(neighbours, start, goal; heuristic = heuristic, cost = cost)