using Pkg
Pkg.activate(".")
Pkg.instantiate()

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


# Problemas de Satisfacción de Restricciones
# ==========================================

#=
Comenzamos cargando las librerías que necesitaremos para la realización de la 
práctica. Las esenciales son:
    * `ConstraintSolver`: proporciona las funciones que permiten definir un CSP 
	tal y como lo hemos visto en clase.
    * `JuMP`: un conjunto de funciones de búsqueda y optimización muy especia-
	lizadas que nos permiten resolver problemas con restricciones de forma 
	transparente a 	partir de las definiciones de la librería anterior.
    * `Printf`: librería auxiliar que facilita la entrada/salida de información
	en la consola.
=#


# Pkg.add("ConstraintSolver")
using ConstraintSolver 				# Librería de CSP
# Pkg.add("Printf")
using Printf                 		# Auxiliar para print
# Pkg.add("JuMP")
using JuMP                  	    # Librería de optimización (usada por CSP)
const CS = ConstraintSolver     	# Para facilitar el uso de ConstraintSolver


#------------------------------------------------------------------------------
#        Ejemplos
#------------------------------------------------------------------------------

# Vamos a comenzar mostrando algunos ejemplos resueltos para mostrar las carac-
# terísticas esenciales de la definición y resolución de CSPs con las librerías 
# usadas. Más adelante habrá algunos ejercicios propuestos que deben ser resuel-
# tos para poner a prueba la correcta asimilación del contenido del tema.

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

## Un ejemplo sencillo
## -------------------

# Vamos a comenzar con un ejemplo muy sencillo (y muy poco interesante) para 
# que queden claras las diversas estructuras y métodos que se usan para definir
# y resolver un Problema de Satisfacción de Restricciones con los paquetes dis-
# ponibles:

# Encontrar los pares (x,y) ∈ [1,10]×[1,10] que verifican x + y = 14.

# Comenzamos resolviendo el sistema para encontrar una solución cualquiera 
# (puede haber muchas, solo queremos una):

# Comenzamos limpiando la terminal, pero solo por motivos de claridad en la
# explicación (observa el `;` al final de la instrucción)
clc();

# ----- Definición -------

# Declaración del modelo que servirá para almacenar el problema
model = Model(CS.Optimizer) 

# Declaración de las variables simbólicas que intervienen (y sus tipos y
# dominios)
@variable(model, 1 <= x <= 10, Int)
@variable(model, 1 <= y <= 10, Int)

# Declaración de las restricciones que definen el problema
@constraint(model, x + y == 14)

# ------ Solucionador -------

# Resolvemos con el optimizador (por defecto, JUMP)
optimize!(model)

# ------- Presentación de resultados ------------

# Extraemos una solución (realmente, JUMP almacena en x,y mucha más información
# que ha usado durante la resolución, a nosotros nos interesa sus valores numé-
# ricos, que es una de las informaciones guardadas)

xsol = JuMP.value(x)
ysol = JuMP.value(y)

# Se puede hacer de forma más corta como: 
#     xsol, ysol = JuMP.value.([x,y])

println("Solución encontrada: x: $xsol , y: $ysol")

# Observa que las soluciones se muestran como Float

# Veamos cómo podríamos usar el solucionador para encontrar todas las 
# soluciones:

# ⚠ Hay problemas que tienen una cantidad enorme de soluciones, así que se 
# debes ser cauto a la hora de buscar todas las soluciones de un problema.

clc();

# Declaración del modelo que servirá para almacenar el problema: Observa que es
# aquí donde indicamos un cambio en la forma en que debe funcionar la interfaz

model = Model(optimizer_with_attributes(CS.Optimizer, 
	"all_solutions" => true,
	"logging"       => []
))

# Declaración de las variables que intervienen (y sus tipos y dominios)
@variable(model, 1 <= x <= 10, Int)
@variable(model, 1 <= y <= 10, Int)

# Declaración de las restricciones que definen el problema
@constraint(model, x + y == 14)

# ------ Solucionador -------

# Resolvemos con el optimizador (por defecto, JUMP)
optimize!(model)

# Extraemos todas las soluciones
num_sols = MOI.get(model, MOI.ResultCount())   # MOI.ResultCount() extrae el nº de soluciones
println("Nº Soluciones encontradas: $num_sols\n")
for sol in 1:num_sols
	xs, ys = convert.(Integer, JuMP.value.([x,y]; result = sol)) # 👀 `;` en la separación de argumentos
	println("Solución nº $sol: x: $xs , y: $ys")  # 👀 interpolación de cadenas
end

# 💁 Si quieres saber qué tipos de variables, restricciones y objetivos admite
# el paquete `ConstraintSolver`, puedes consultar [esta página]
# (https://wikunia.github.io/ConstraintSolver.jl/stable/supported/) 
# (es la distribución oficial del paquete).

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

## Coloreado de Mapas
## ------------------

# Dado un mapa, y un número de colores, dar una coloración válida del mapa: dos
# paises con frontera común deben colorearse con colores distintos.

# Se puede identificar con la asignación de colores a los nodos de un grafo, 
# donde dos nodos vecinos deben colorearse con colores distintos. Por ello, el 
# coloreado de mapas es lo mismo que el coloreado de grafos.

# La forma más sencilla de formalizarlo como un CSP es asociar una variable a 
# cada país (suponemos que tenemos N países), que va a tomar como valor el 
# color que se le asigna, y poner como restricciones:
#   1. El color se puede representar como un número entero entre 1 y K (el 
#		número de colores que tenemos).
#   2. Los valores/colores de dos países con frontera común (nodos conectados) 
#		deben ser distintos.

# Es decir, si x_1,...,x_N son los colores asociados a los países p_1,...,p_N, 
# respectivamente, entonces:
#   1. ∀ i ∈ {1,...,N} (1 ≤ x_i ≤ K)
#   2. ∀ i,j∈ {1,...,N} (p_i fronterizo con p_j → x_i ≠ x_j)

clc();
model = Model(CS.Optimizer)

# Vamos a considerar los siguientes países:
#     Alemania, Suiza, Francia, Italia, España

# Creación de las variables asociadas al problema (en este caso, solo 5 países,
# 4 colores)
@variable(model, 1 <= x[1:5] <= 4, Int)  # 👀 x es ahora un array


# Añadiendo restricciones por paises con frontera común
@constraint(model, x[1] != x[3]) # Alemania tiene frontera con Francia
@constraint(model, x[1] != x[2]) # Alemania tiene frontera con Suiza
@constraint(model, x[3] != x[5]) # Francia tiene frontera con España
@constraint(model, x[3] != x[2]) # Francia tiene frontera con Suiza
@constraint(model, x[3] != x[4]) # Francia tiene frontera con Italia
@constraint(model, x[2] != x[4]) # Suiza tiene frontera con Italia
	
# Lanzamos la optimización
optimize!(model)

# Mostramos el vector de colores asignados a los países en la solución 
# encontrada
println(convert.(Integer, JuMP.value.(x)))

# Pero podemos mejorar considerablemente la representación con un par de 
# retoques, y convirtiendo el problema de satisfacción en un problema de 
# optimización, minimizando el número de colores necesarios para la solución 
# (es decir, que no solo damos un coloreado del mapa, sino que lo hacemos 
# usando el menor número posible de colores para este mapa):

clc();
model = Model(optimizer_with_attributes(CS.Optimizer, 
	"logging"       => []
	))
num_colors = 5

# Creación de las variables asociadas al problema (en este caso, solo 5 países)
@variable(model, 1 <= x[1:5] <= num_colors, Int)

# Aunque será más cómodo trabajar con las variables genéricas anteriores, 
# podemos darles un nombre reconocible para que las restricciones sean más 
# intuitivas y podamos interpretar los resultados de forma más sencilla. Con la
# siguiente definición podemos trabajar indistintamente con la nomenclatura que 
# nos parezca más cómoda en cada caso:
alemania, suiza, francia, italia, españa = x # 👀 Asignación múltiple

# Restricciones por paises con frontera común, esta vez usando los nombres de 
# las variables asociadas a cada país:
@constraint(model, alemania != francia)
@constraint(model, alemania != suiza)
@constraint(model, francia != españa)
@constraint(model, francia != suiza)
@constraint(model, francia != italia)
@constraint(model, suiza != italia)

# Creación de una variable adicional para minimizar el número de colores 
# necesarios. No es necesaria, porque podríamos proponer una cantidad fija de
# colores iniciales y ver si somos capaces de encontrar solución
@variable(model, 1 <= max_color <= num_colors, Int)

# El color asociado a cada país debe ser <= que el número máximo de colores
@constraint(model, max_color .>= x) # 👀 operador `.`

# Marcamos minimzación de max_color como objetivo de optimización
@objective(model, Min, max_color)

# Lanzamos la optimización
optimize!(model)

# Podemos obtener el estado de parada del optimizador
# 	status = JuMP.termination_status(model)

# Mostramos el número de colores necesarios que ha conseguido optimizar
println("Nº colores: $(convert(Integer,JuMP.value(max_color)))")

# y los colores asignados a los países en la solución encontrada
alemania, suiza, francia, italia, españa = convert.(Integer, JuMP.value.(x))

println("Colores asignados por paises 
Alemania: $alemania
Suiza: $suiza
Francia: $francia
Italia: $italia
España: $españa")

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

## send + more = money
## -------------------

# Problema de Criptoaritmética: asignar valores (dígitos entre 0 y 9) a las 
# letras anteriores de forma que la suma sea correcta. Letras distintas tienen 
# asignaciones distintas, y ninguna de las cifras empieza por $0$.

# La solución más directa e intuitiva es asignar un valor (entre 0 y 9) a cada 
# letra, y obligar a que se verifique esa igualdad numérica (que se puede ex-
# presar como un cálculo a partir de los valores de las variables anteriores). 
# De esta forma, tenemos una primera aproximación (algo burda) a la definición 
# del problema como un CSP:

clc();
# Modelo de solucionador de restricciones y estableciendo ConstraintSolver como
#  optimizador.
model = Model(optimizer_with_attributes(CS.Optimizer, 
	"logging"       => []
	))

# Definimos las variables necesarias para el modelado del problema
@variable(model, 0 <= x[1:8] <= 9, Int)
s, e, n, d, m, o, r, y = x  # 👀 Aquí las variables-letras son simbólicas

# Todas deben tener valores distintos
#   Es tan habitual imponer este tipo de restricciones que todos los resolvedo-
#	res de CSP tienen incorporada una restricción compacta para obligar a un 
#	conjunto de variables que sean distintas entre sí (2 a 2).
@constraint(model, x[1:8] in CS.AllDifferentSet())  # 👀 Es una función auxiliar que añade ConstraintSolver

# Los números no empiezan por 0
@constraint(model, m != 0)
@constraint(model, s != 0)

# Restricción numérica (muy "bruta")
@constraint(model, d + 10n + 100e + 1000s + e + 10r + 100o + 1000m == y + 10e + 100n + 1000o + 10000m)

# Lanzamos el optimizador
optimize!(model)

# Mostramos los valores asignados a cada letras en la solución encontrada
vx = convert.(Integer, JuMP.value.(x)) # 👀 uso de `convert` y `.`
s, e, n, d, m, o, r, y = vx # 👀 Aquí las variables-letras son enteros
println("s = $s, e = $e, n = $n, d = $d, m = $m, o = $o, r = $r, y = $y")
println("$s$e$n$d + $m$o$r$e = $m$o$n$e$y")


# El problema de la formalización anterior es que solo usa una gran restricción
# que precisa que todas las variables estén instanciadas para poder decidir si 
# es válida o no. Esto significa que los algoritmos basados en backtracking y 
# comprobación avanzada no podrán podar la búsqueda de forma prematura (lo que
# hubiera permitido ahorrar muchas construcciones de asignaciones y sus corres-
# pondientes, y fallidas, comprobaciones).

# Por ello, vamos a dar una segunda formalización que divide esa gran restric-
# ción en un conjunto de restricciones menores, a costa de introducir algunas 
# variables de acarreo adicionales. La idea es usar la suma por dígitos que se 
# realiza en base 10:

#      c3 c2 c1
#      s  e  n  d
#   +  m  o  r  e
#   -------------
#   m  o  n  e  y

clc();
# Modelo de solucionador de restricciones y estableciendo ConstraintSolver como
# optimizador.
model = Model(optimizer_with_attributes(CS.Optimizer, 
	"logging"       => []
	))

# Definimos las variables necesarias para el modelado del problema
@variable(model, 0 <= x[1:8] <= 9, Int)
s, e, n, d, m, o, r, y = x
@variable(model, 0 <= c[1:3] <= 1, Int)
c1, c2, c3 = c

# Todas deben tener valores distintos
@constraint(model, x[1:8] in CS.AllDifferentSet())

# Los números no empiezan por 0
@constraint(model, m != 0)
@constraint(model, s != 0)

# Restricción numérica por cada suma de dígitos
@constraint(model, e + d == y + 10c1)
@constraint(model, c1 + n + r == e + 10c2)
@constraint(model, c2 + e + o == n + 10c3)
@constraint(model, c3 + s + m == 10m + o)

# Lanzamos el optimizador
optimize!(model)

# Miramos el estado de parada del optimizador
# 	status = JuMP.termination_status(model2b)
# Mostramos los colores asignados a los países en la solución encontrada
vx = convert.(Integer, JuMP.value.(x))
s, e, n, d, m, o, r, y = vx
println("s = $s, e = $e, n = $n, d = $d, m = $m, o = $o, r = $r, y = $y")
println("$s$e$n$d + $m$o$r$e = $m$o$n$e$y")


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

## Sudoku
## ------

# Es un problema ampliamente conocido, así que lo describimos muy brevemente: 
# Una rejilla de 9×9 en la que se deben colocar números entre 1 y 9 con la 
# condición de que:
#   1. En cada fila no se repiten números.
#   2. En cada columna no se repiten números.
#   3. En cada submatriz de tamaño 3×3 no se repiten números (estas submatrices
#		dividen la rejilla completa en 9 espacios disjuntos del mismo tamaño).
#   4. A veces, se dan algunos valores fijos en la rejilla inicial que hay que 
#		respetar.

# Por tanto, la formalización más directa como CSP consiste en considerar una 
# variable X_{ij} para cada posición (i,j)∈ {1,...,9}^2 y que toman valores en
# [1,9]. Con esta representación, las restricciones se escriben de forma casi
# directa.

clc();
# Problema de Sudoku concreto (los 0s representan casillas vacías):
grid = [
	6 0 2 0 5 0 0 0 0
	0 0 0 0 0 3 0 4 0
	0 0 0 0 0 0 0 0 0
	4 3 0 0 0 8 0 0 0
	0 1 0 0 0 0 2 0 0
	0 0 0 0 0 0 7 0 0
	5 0 0 2 7 0 0 0 0
	0 0 0 0 0 0 0 8 1
	0 0 0 6 0 0 0 0 0]

# Modelo CSP y variables
model = Model(CS.Optimizer)

# Definimos las 81 variables asociadas al problema: las 81 variables de la
# rejilla
@variable(model, 1 <= x[1:9, 1:9] <= 9, Int)

# Asignamos valores conocidos a celdas fijas (las no nulas)
for r = 1:9, c = 1:9
	if grid[r, c] != 0
		@constraint(model, x[r, c] == grid[r, c])
	end
end

# Restricción de valores distintos en cada fila y cada columna
for rc = 1:9
	@constraint(model, x[rc, :] in CS.AllDifferentSet())  # 👀 uso de [rc, :] , [:, rc]
	@constraint(model, x[:, rc] in CS.AllDifferentSet())
end

# Valores distintos en cada submatriz/bloque 3x3
for br = 0:2
	for bc = 0:2
		@constraint(model, vec(x[3br + 1:3(br+1), 3bc + 1:3(bc+1)]) in CS.AllDifferentSet()) # 👀 uso de submatrices
	end
end

# Lanzamos el optimizador
optimize!(model)
	
# Devolvemos la solución encontrada 
convert.(Integer, JuMP.value.(x)) # 👀 conversión directa de toda la matriz, `convert` y `.`

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

## Puzzle de las Esquinas
## ----------------------

# Este rompecabezas pide que se coloquen los dígitos del 1 al 8 en los bordes
# del cuadrado (tal y como se indica en la figura siguiente, un dígito en cada
# celda) de modo que el número de cada celda lateral sea igual a la suma de los
# números de las esquinas contiguas.  
  
#    NO │ N | NE
#   ------------
#    O  │   │ E
#   ------------
#    SO │ S │ SE

# A partir de este ejemplo, vamos a crear funciones que permitan parametrizar
# la generación de soluciones personalizando la llamada al optimizador por
# medio de argumentos con nombre.
# En este caso, vamos a intentar dar todas las posibles soluciones, no la
# primera que encuentre el resolvedor en su proceso de búsqueda, así que
# tendremos que modificar algunos atributos que este trae por defecto. En el
# código puedes ver no solo la modificación del atributo que permite generar
# todas las soluciones, sino otros atributos que modifican el proceso de
# búsqueda de asignaciones, el tiempo de búsqueda permitido, etc.

# Observa que, al definirse la estructura del modelo dentro de la función, las
# variables que se usan son de forma natural locales a la misma, por lo que no
# hace falta explicitarlo, como sí hemos hecho en los ejemplos anteriores.

# Como el modelado del problema es bastante directo no detallaremos aquí
# ninguna característica adicional, toda la información relevante se puede
# extraer del a lectura del código.

clc();
function esquinas(print_solutions=true, all_solutions=true, timeout=6)

	# Mostramos la forma de fijar hiperparámetros en el optimizador
    model = Model(optimizer_with_attributes(CS.Optimizer, 
        "all_solutions" => all_solutions,
        "logging" => [], 
        "time_limit" => timeout,
    ))

    # Son 8 variables, con valores enteros
    @variable(model, 1 <= x[1:8] <= 8, Int)
	
    # a los que asignamos nombres para facilitar la escritura
    NO, N, NE, O, E, SO, S, SE = x
    
	# Todos los valores distintos
    @constraint(model, x in CS.AllDifferent())
    
	# Restricciones: Casilla_Lado = Casilla_Esquina1 + Casilla_Esquina2
    @constraint(model, N == NO + NE)
    @constraint(model, O == NO + SO)
    @constraint(model, E == NE + SE)
    @constraint(model, S == SO + SE)

    # Resolución del Problema
    optimize!(model)

    # Recogemos el estado del resolvedor en la parada (nos puede indicar si no
	# ha encontradp soluciones, por ejemplo)
    status = JuMP.termination_status(model)

    # Impresión de las soluciones (si las hay, en este caso, como se sabe que 
	# sí hay solución, se muestra solo para que se conozca su uso)
    if status == MOI.OPTIMAL
    	num_sols = MOI.get(model, MOI.ResultCount())
        println("Nº Soluciones encontradas: $num_sols\n")
        if print_solutions
            for sol in 1:num_sols
                NO, N, NE, O, E, SO, S, SE = convert.(Integer, JuMP.value.(x; result=sol))
				println("             $NO $N $NE")
                println("Solución #$sol: $O   $E")
                println("             $SO $S $SE")
                println()
            end
        end
    else
        println("Status: $status")
    end
end

clc();
@time esquinas() # 👀 macro @time para tener información de recursos de ejecución

# 👀 Las 8 soluciones son realmente giros y simetrías de la misma.

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

## N - Reinas
## ----------

# Plantea cómo disponer en un tablero de ajedrez de tamaño N×N (el tablero de
# ajedrez estándar es N=8), N reinas de forma que no haya amenazas entre ningún
# par de ellas (recordemos que una reina amenaza a toda la fila, columna y
# diagonales de la casilla en la que se sitúa).

# PlutoUI.Show(MIME"image/png"(), read("./img/8queens.jpg"))

# Este problema ha sido ya resuelto en los recursos de teoría de 3 formas
# distintas. Observa que la solución dada aquí es ligeramente distinta a todas
# ellas, intenta analizar por qué funciona y cómo traduce los 4 tipos de
# restricciones (filas, columnas, y ambas diagonales).

clc();
function nqueens(n=8, print_solutions=true, all_solutions=true, timeout=6)
    	
	model = Model(optimizer_with_attributes(CS.Optimizer, 
		"all_solutions" => all_solutions,
        "logging" => [], 
        "time_limit" => timeout,
    ))

	# Variables
    @variable(model, 1 <= x[1:n] <= n, Int)

	# Restricciones
    @constraint(model, x in CS.AllDifferent())
    @constraint(model, [x[i] + i for i in 1:n] in CS.AllDifferent())
    @constraint(model, [x[i] - i for i in 1:n] in CS.AllDifferent())

    # Resolución del modelo
    optimize!(model)

    status = JuMP.termination_status(model)

	num_sols = 0
    if status == MOI.OPTIMAL
        num_sols = MOI.get(model, MOI.ResultCount())
        if print_solutions
            for sol in 1:num_sols
                x_val = convert.(Integer, JuMP.value.(x; result=sol))
                println("Sol #$sol: $x_val")

            end
        end
    else
        println("status:$status")
    end
end

clc();
@time nqueens(8)

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

## Clases en la E.T.S.I.I
## ----------------------

# Alicia, al volver de la escuela, describe las cuatro asignaturas (IA, SI, MD
# y PD) a las que ha asistido a su amigo Juan. A Juan le interesan las cuatro
# asignaturas, pero ella no recuerda exactamente en qué aula fue cada una ni el
# orden, solo recuerda haber visitado la A1.16, H1.12, I1.32, y la F0.10, y
# alguna informaciónn adicional:

#  1. Alicia acudió  a la la H1.12 para SI.
#  2. Después de haber acudido a MD no fue la  F0.10.
#  3. La segunda clase la recibió en la A1.16.
#  4. Dos clases después de salir de la I1.32, acudió a PD.
    
# Identifica dónde se imparte cada asignatura y en qué orden.

clc();
function asignaturas(print_solutions=true, all_solutions=true)

	model = Model(optimizer_with_attributes(CS.Optimizer, 
		"all_solutions" => all_solutions,
        "logging" => []
	))

    # Modelaremos el problema con 2 conjuntos de variables de 4 elementos: una
	# para asignaturas y otra para aulas. El valor que tenga cada variable
	# indicará el orden que ocupa el elemento asociado.
	
    # Lista de asignaturas
    @variable(model, 1 <= asigs[1:4] <= 4, Int)
    IA, SI, MD, PD = asigs
    # Lista de Aulas
    @variable(model, 1 <= aulas[1:4] <= 4, Int)
    F010, A116, I132, H112 = aulas

    # Todos los ordenes de asignaturas/aulas son distintos
    @constraint(model, asigs in CS.AllDifferent())
    @constraint(model, aulas in CS.AllDifferent())
	
    #  1. Alicia atendió a SI en la H1.12.
    @constraint(model, SI == H112)
    # 2. El aula a la que asistió justo después de acudir a MD no fue la F0.10.
    @constraint(model, MD + 1 != F010)
    #  3. A1.16 fue la segunda aula a la que fue Alicia.
    @constraint(model, A116 == 2)
    # 4. Dos clases después de salir de la I1.32, Alicia acudió a PD.
    @constraint(model, I132 + 2 == PD)

    # Lanzamos el optimizador
    optimize!(model)
    
	# Registramos el estado de parada
    status = JuMP.termination_status(model)

    # Imprimimos las soluciones encontradas
    if status == MOI.OPTIMAL
        num_sols = MOI.get(model, MOI.ResultCount())
        println("num_sols: $num_sols\n")
        if print_solutions
            for sol in 1:num_sols
                println("Solución #$sol:")
                asigs_val = convert.(Integer, JuMP.value.(asigs; result=sol))
                aulas_val = convert.(Integer, JuMP.value.(aulas; result=sol))
                println("  Orden Asignaturas [IA, SI, MD, PD]: $asigs_val")
                println("  Orden Aulas [F0.10, A1.16, I1.32, H1.12]: $aulas_val")
                println()
            end
        end
    else
        println("status:$status")
    end
end

clc();
@time asignaturas()

## Monjes y puertas
## ----------------

# Hay una habitación con cuatro puertas (denotadas por A, B, C y D) y ocho
# monjes. Una o más de las puertas pueden ser de salida. Cada monje puede
# mentir o no.

# Los monjes hacen las siguientes afirmaciones:
#  * Monje 1: La puerta A es de salida.
#  * Monje 2: Al menos una de las puertas B y C es de salida.
#  * Monje 3: El monje 1 y el monje 2 dicen la verdad.
#  * Monje 4: Las puertas A y B son ambas salidas.
#  * Monje 5: Las puertas A y C son ambas salidas.
#  * Monje 6: O el monje 4 o el monje 5 dicen la verdad.
#  * Monje 7: Si el Monje 3 dice la verdad, también lo hace el Monje 6.
#  * Monje 8: Si el monje 7 y el monje 8 dicen la verdad, el monje 1 también.

# ¿Qué puerta/s son salidas? ¿Puedes determinar quién dice la verdad y quién
# miente? ¿Y si añadimos la información de que solo una de las puertas es la
# salida?

# Para este problema disponemos de varias aproximaciones, en ellas se hace uso
# de una representación del problema por medio de variables booleanas (por
# ejemplo, la afirmación "la puerta A es una salida" puede ser verdad o
# mentira), pero en algunos casos podemos transformar las conectivas lógicas
# (AND, OR, ...) en operaciones aritméticas, mientras que en otros casos
# podemos dejarlas como conectivas lógicas usando los operadores lógicos de
# Julia.

# Transformación Lógica ⇋ Aritmética
#	Para transformar las relaciones lógicas habituales en relaciones aritmé-
#	ticas (teniendo en cuenta que $true=1$ y $false=0$) basta tener presente
#	que:
    
#     | Fórmula Lógica | Equivalencia Aritmética|
#     |:---------------|:----------------------:|
#     |A ∧ B           | A + B = 2              |
#     |A ∨ B           | A + B ≥ 1              |
#     |A xor B         | A + B = 1              |
#     |A ⇒ B           | A ≤ B                  |
#     |A ⇔ B           | A = B                  | 
#     -------------------------------------------

# Por lo que podemos representar el problema como (las posibles variantes de
# cada restricción se dan como líneas comentadas):

clc();
function monjes_y_puertas(print_solutions=true, all_solutions=true, timeout=6)

    model = Model(optimizer_with_attributes(CS.Optimizer, 
		"all_solutions" => all_solutions,
        "logging" => [], 
        "time_limit" => timeout,
    ))

    num_puertas = 4
    num_monjes = 8

	# dx = true ↔ dx de salida
    @variable(model, puertas[1:num_puertas], Bin)
    da, db, dc, dd = puertas
    puertas_nombres = ["A", "B", "C", "D"]

	# my = true ↔ my dice la verdad
    @variable(model, monjes[1:num_monjes], Bin)
    m1, m2, m3, m4, m5, m6, m7, m8 = monjes

    # Monje 1: La puerta A es de salida.
    @constraint(model, m1 == da) 

    # Monje 2: Al menos una de las puertas B y C es salida.
    # @constraint(model, m2 := { db + dc >= 1})
    # @constraint(model, m2 := { db == 1 || dc == 1})
    @constraint(model, m2 := {db || dc}) # 👀 `:=` permite añadir restricciones booleanas

    # Monje 3: El monje 1 y el monje 2 dicen la verdad.
    # @constraint(model, m3 := { m1 + m2 == 2})
    # @constraint(model, m3 := { m1 == 1 && m2 == 1})
    @constraint(model, m3 := {m1 && m2})

    # Monje 4: Las puertas A y B son ambas salidas.
    # @constraint(model, m4 := { da + db == 2})
    # @constraint(model, m4 := { da == 1 && db == 1})
    @constraint(model, m4 := {da && db})

    # Monje 5: Las puertas A y C son ambas salidas.
    # @constraint(model, m5 := { da + dc == 2})
    # @constraint(model, m5 := { da == 1 && dc == 1})
    @constraint(model, m5 := {da && dc})

    # Monje 6: O el monje 4 o el monje 5 dicen la verdad.
    # @constraint(model, m6 := { m4 + m5 == 1})
    # @constraint(model, m6 := { m4 == 1|| m5 == 1})
    @constraint(model, m6 := {m4 || m5})

    # Monje 7: Si el Monje 3 dice la verdad, también lo hace el Monje 6.
    # @constraint(model, m7 := { m3 <= m6}) # ORIG
    # @constraint(model, m7 := { m3 => m6})  # No funciona!
    @constraint(model, m7 := {m3 => {m6 == 1}})

    # Monje 8: Si el monje 7 y el monje 8 dicen la verdad, el monje 1 también.
    b1 = @variable(model, binary = true)
    @constraint(model, b1 := {m7 == 1 && m8 == 1})
    @constraint(model, m8 := {b1 <= m1})

    # Hay exactamente una salida
    # @constraint(model, da + db + dc + dd == 1) # ⚠ Comentar o descomentar dependiendo de si la consideramos

    # Lanzamos el solver
    optimize!(model)

	# Mostramos resultados
    status = JuMP.termination_status(model)
    if status == MOI.OPTIMAL
        num_sols = MOI.get(model, MOI.ResultCount())
        println("num_sols:$num_sols\n")
        if print_solutions
            for sol in 1:num_sols
                println("Solución #$sol:")
                puertas_val = convert.(Integer, JuMP.value.(puertas; result=sol))
                monjes_val = convert.(Integer, JuMP.value.(monjes; result=sol))
                println("Puertas: $puertas_val  Monjes: $monjes_val")
                println("Salidas       : ", [puertas_nombres[i] for i in 1:num_puertas if puertas_val[i] == 1])
                println("Monjes veraces: ", [m for m in 1:num_monjes if monjes_val[m] == 1])
				println("")
            end
        end
    else
        println("status:$status")
    end
end

@time monjes_y_puertas()

#------------------------------------------------------------------------------
#        Ejercicios Propuestos
#------------------------------------------------------------------------------

## Noticias
## --------

# El Daily Galaxy envió a sus cuatro mejores reporteros (Carlos, Jaime, Luis y
# Pedro), a diferentes lugares (Granada, Cádiz, Sevilla, y Córdoba), para
# cubrir cuatro noticias de última hora: nacimiento de un bebé de 100Kg, lanza-
# miento de un dirigible hecho de globos infantiles, inauguración de un rasca-
# cielos de 3Km de altura, y la aparición de una ballena varada de color rosa. 

# El editor del periódico intenta recordar dónde se encuentra cada uno de los
# reporteros y qué noticia ha cubierto, pero solo tiene la siguiente informa-
# ción parcial confirmada:

	# 1. El bebé no nació ni en Córdoba ni en Cádiz.
	# 2. Jaime no fue a Sevilla.
	# 3. El lanzamiento del dirigible y la inauguración del rascacielos fueron
	#	cubiertos, en algún orden, por Luis y el reportero que fue enviado a 
	#	Sevilla.
	# 4. Córdoba no fue el lugar de la ballena varada ni de la inauguración del
	#	rascacielos. 
	# 5. Granada es el lugar al que fue Carlos, el lugar donde varó la ballena,
	#	o ambos.

## Arquero
## -------

# Teniendo en cuenta que una diana tiene las puntuaciones 16, 17, 23, 24, 39,
# 40 en sus diferentes círculos, y que el arquero puede tirar tantas flechas
# como quiera. ¿Cuál sería la mejor distribución de tiros para quedarse lo más
# cerca posible de 100?

## Monedas
## -------

# ¿Cuál es el número mínimo de monedas que permite pagar exactamente cualquier
# cantidad inferior a un euro? Recordemos que existen seis moneda de céntimos
# de euro, de denominación 1, 2, 5, 10, 20, 50.

## Tomografía Discreta
## -------------------

# Una matriz que contiene 0s y 1s se escanea vertical y horizontalmente, dando
# el número total de 1s en cada fila y columna. El problema consiste en recons-
# truir el contenido de la matriz a partir de esta información. Por ejemplo:

    #    0 0 7 1 6 3 4 5 2 7 0 0
    # 0
    # 0 
    # 8      ■ ■ ■ ■ ■ ■ ■ ■ 
    # 2      ■             ■
    # 6      ■   ■ ■ ■ ■   ■
    # 4      ■   ■     ■   ■
    # 5      ■   ■   ■ ■   ■
    # 3      ■   ■         ■
    # 7      ■   ■ ■ ■ ■ ■ ■
    # 0
    # 0

## Diferencia mínima
## -----------------

# A partir de los dígitos (0 a 9) construimos 2 números, X e Y, cada uno de 5
# dígitos, y sin repetirse ninguno entre ellos (es decir, vistos como conjun-
# tos, X e Y forman una partición de 0:9). ¿Cuál es la diferencia mínima que
# se puede conseguir?

## Sucesiones Mágicas
## ------------------

# Una sucesión mágica de longitud n es una sucesión de enteros x_0 ... x_{n-1}
# entre 0 y n-1, tal que para todo 0 ≤ i ≤ n-1, el número i aparece exactamente
# x_i veces en la sucesión. Por ejemplo, 6,2,1,0,0,0,1,0,0,0 es una sucesión
# mágica, ya que el 0 aparece 6 veces en ella, el 1 aparece 2 veces, el 2 apa-
# rece 1 vez, etc.

# Construye sucesiones mágicas por medio de CSP.

## Buscaminas
## ----------

# Un campo minado viene dado por una matriz numérica que indica cuántas minas
# son adyacentes a cada posición (si hay un número, no puede haber una mina). 
# En el siguiente ejemplo: 
	# en el campo minado de entrada los ■ representan que ese dato es descono-
	#	cido (pudiendo haber, o no, una mina en esa posición), 
	# en la solución, los □ representan un espacio sin mina, y * representa una
	#	mina, 
	# las posiciones con números indican el número de minas que le rodean (no
	#	hay minas en ellos).
# El objetivo consiste en decubrir dónde están todas las minas de un campo
# minado de entrada.

# Por ejemplo:

# 	■ ■ 2 ■ 3 ■ 		* □ 2 □ 3 *
# 	2 ■ ■ ■ ■ ■ 		2 * □ * * □
# 	■ ■ 2 4 ■ 3   ==>	□ □ 2 4 * 3
# 	1 ■ 3 4 ■ ■ 		1 □ 3 4 * □
# 	■ ■ ■ ■ ■ 3 		□ * * * □ 3
# 	■ 3 ■ 3 ■ ■ 		* 3 □ 3 * *

# A continuación se dan algunos ejemplos concretos con los que se puede
# trabajar.

clc();
# M representa un valor desconocido (el ■ del ejemplo anterior)
M = -1	

buscaminas_problemas = Dict(
	:0 =>
			[[M, M, 2, M, 3, M],
			[2, M, M, M, M, M],
			[M, M, 2, 4, M, 3],
			[1, M, 3, 4, M, M],
			[M, M, M, M, M, 3],
			[M, 3, M, 3, M, M]],

	:1 =>
			[[M, 2, M, 2, 1, 1, M, M],
			[M, M, 4, M, 2, M, M, 2],
			[2, M, M, 2, M, M, 3, M],
			[2, M, 2, 2, M, 3, M, 3],
			[M, M, 1, M, M, M, 4, M],
			[1, M, M, M, 2, M, M, 3],
			[M, 2, M, 2, 2, M, 3, M],
			[1, M, 1, M, M, 1, M, 1]],

	:2 =>
			[[1, M, M, 2, M, 2, M, 2, M, M],
			[M, 3, 2, M, M, M, 4, M, M, 1],
			[M, M, M, 1, 3, M, M, M, 4, M],
			[3, M, 1, M, M, M, 3, M, M, M],
			[M, 2, 1, M, 1, M, M, 3, M, 2],
			[M, 3, M, 2, M, M, 2, M, 1, M],
			[2, M, M, 3, 2, M, M, 2, M, M],
			[M, 3, M, M, M, 3, 2, M, M, 3],
			[M, M, 3, M, 3, 3, M, M, M, M],
			[M, 2, M, 2, M, M, M, 2, 2, M]],

	:3 =>
			[[2, M, M, M, 3, M, 1, M],
			[M, 5, M, 4, M, M, M, 1],
			[M, M, 5, M, M, 4, M, M],
			[2, M, M, M, 4, M, 5, M],
			[M, 2, M, 4, M, M, M, 2],
			[M, M, 5, M, M, 4, M, M],
			[2, M, M, M, 5, M, 4, M],
			[M, 3, M, 3, M, M, M, 2]],

	:4 =>
			[[0, M, 0, M, 1, M, M, 1, 1, M],
			[1, M, 2, M, 2, M, 2, 2, M, M],
			[M, M, M, M, M, M, 2, M, M, 2],
			[M, 2, 3, M, 1, 1, M, M, M, M],
			[0, M, M, M, M, M, M, 2, M, 1],
			[M, M, M, 2, 2, M, 1, M, M, M],
			[M, M, M, M, M, 3, M, 3, 2, M],
			[M, 5, M, 2, M, M, M, 3, M, 1],
			[M, 3, M, 1, M, M, 3, M, M, M],
			[M, 2, M, M, M, 1, 2, M, M, 0]],

	:5 =>
			[[M, 2, 1, M, 2, M, 2, M, M, M],
			[M, 4, M, M, 3, M, M, M, 5, 3],
			[M, M, M, 4, M, 4, 4, M, M, 3],
			[4, M, 4, M, M, 5, M, 6, M, M],
			[M, M, 4, 5, M, M, M, M, 5, 4],
			[3, 4, M, M, M, M, 5, 5, M, M],
			[M, M, 4, M, 4, M, M, 5, M, 5],
			[2, M, M, 3, 3, M, 6, M, M, M],
			[3, 6, M, M, M, 3, M, M, 4, M],
			[M, M, M, 4, M, 2, M, 2, 1, M]],

	:6 =>
			[[M, 3, 2, M, M, 1, M, M],
			[M, M, M, M, 1, M, M, 3],
			[3, M, M, 2, M, M, M, 4],
			[M, 5, M, M, M, 5, M, M],
			[M, M, 6, M, M, M, 5, M],
			[3, M, M, M, 5, M, M, 4],
			[2, M, M, 5, M, M, M, M],
			[M, M, 2, M, M, 3, 4, M]],

	:7 =>
			[[M, 1, M, M, M, M, M, 3, M],
			[M, M, M, 3, 4, 3, M, M, M],
			[2, 4, 4, M, M, M, 4, 4, 3],
			[M, M, M, 4, M, 4, M, M, M],
			[M, 4, M, 4, M, 3, M, 6, M],
			[M, M, M, 4, M, 3, M, M, M],
			[1, 2, 3, M, M, M, 1, 3, 3],
			[M, M, M, 3, 2, 2, M, M, M],
			[M, 2, M, M, M, M, M, 3, M]],

	:8 =>
			[[M, M, M, M, M, M, M],
			[M, 2, 3, 4, 3, 5, M],
			[M, 1, M, M, M, 3, M],
			[M, M, M, 5, M, M, M],
			[M, 1, M, M, M, 3, M],
			[M, 1, 2, 2, 3, 4, M],
			[M, M, M, M, M, M, M]],

	:9 =>
			[[2, M, M, M, 2, M, M, M, 2],
			[M, 4, M, 4, M, 3, M, 4, M],
			[M, M, 4, M, M, M, 1, M, M],
			[M, 4, M, 3, M, 3, M, 4, M],
			[2, M, M, M, M, M, M, M, 2],
			[M, 5, M, 4, M, 5, M, 4, M],
			[M, M, 3, M, M, M, 3, M, M],
			[M, 4, M, 3, M, 5, M, 6, M],
			[2, M, M, M, 1, M, M, M, 2]],

	:10 =>
			[[M, M, M, M, M, M],
			[M, 2, 2, 2, 2, M],
			[M, 2, 0, 0, 2, M],
			[M, 2, 0, 0, 2, M],
			[M, 2, 2, 2, 2, M],
			[M, M, M, M, M, M]],

	:11 =>
			[[2, 3, M, 2, 2, M, 2, 1],
			[M, M, 4, M, M, 4, M, 2],
			[M, M, M, M, M, M, 4, M],
			[M, 5, M, 6, M, M, M, 2],
			[2, M, M, M, 5, 5, M, 2],
			[1, 3, 4, M, M, M, 4, M],
			[0, 1, M, 4, M, M, M, 3],
			[0, 1, 2, M, 2, 3, M, 2]],

	:12 =>
			[[M, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, M],
			[M, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, M],
			[M, M, 1, M, M, 1, M, M, 1, M, M, 1, M, M],
			[M, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, M],
			[M, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, M]],

	:13 =>
			[[M, M, M, 0, M, M, M, 0, M, M, M],
			[M, M, M, 0, 1, M, 1, 0, M, M, M],
			[M, M, M, 0, 1, M, 1, 0, M, M, M],
			[0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0],
			[M, 1, 1, 1, 1, M, 1, 1, 1, 1, M],
			[M, M, M, 1, M, 2, M, 1, M, M, M],
			[M, 1, 1, 1, 1, M, 1, 1, 1, 1, M],
			[0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0],
			[M, M, M, 0, 1, M, 1, 0, M, M, M],
			[M, M, M, 0, 1, M, 1, 0, M, M, M],
			[M, M, M, 0, M, M, M, 0, M, M, M]],

	:14 =>
			[[M, 1, M, 1, M, 1],
			[2, M, 2, M, 1, M],
			[M, 3, M, 2, M, 1],
			[1, M, 3, M, 2, M],
			[M, 1, M, 2, M, 1]],

	:15 =>
			[[0, 0, 0, 0, 1, M, M, M, M],
			[0, 0, 0, 0, 1, M, M, 3, M],
			[0, 0, 1, 1, 2, M, M, M, M],
			[0, 0, 1, M, M, M, M, 1, M],
			[0, 0, 1, 2, M, 3, M, M, M],
			[0, 0, 0, 1, M, M, M, M, M],
			[0, 0, 1, 2, 2, 1, 1, 1, 1],
			[0, 0, 1, M, 1, 0, 0, 0, 0],
			[0, 0, 1, M, 1, 0, 0, 0, 0]])


# Cómo funciona Constraint Solver?

# Se puede tener una idea más detallada de cómo ha evolucionado este proyecto y
# cómo se ha diseñado en el [blog del autor](https://opensourc.es/blog/constraint-solver-1).

# Se trata de un proyecto en curso y en continuo cambio, por tanto, aquí solo
# veremos el estado actual del proyecto y de una forma muy intuitiva y resumida.

## Concepto general
# Constrint Solver trabaja sobre un conjunto de variables discretas acotadas.
# Por ejemplo, si tenemos una restricción `all_different([x,y])` y `x` está
# fijada en `3`, entonces ese valor puede eliminarse directamente del conjunto
# de valores posibles para `y`. Ahora que `y` ha cambiado, esto puede llevar a
# que se elimine la restricción `all_different([x,y])`, y además puede que se
# produzcan nuevas mejoras llamando a las restricciones en las que interviene
# `y` (haciendo que el espacio de búsqueda se haga más pequeño).

# Después de este paso podría resultar que el problema es inviable o que ya
# esté resuelto, pero la mayoría de las veces aún no se sabe. Es entonces
# cuando entra en juego el backtracking.

## Backtracking

# En el backtracking dividimos el modelo actual en varios modelos, en cada uno
# de los cuales fijamos una variable a un valor determinado. Esto crea una
# estructura en forma de árbol. El solucionador de restricciones decide cómo
# dividir el modelo en varias partes. La mayoría de las veces es útil dividirlo
# en pocas partes en lugar de en muchas. Esto significa que si tenemos dos
# variables. `x` e `y`, y `x` tiene 3 valores posibles después del primer paso,
# e `y` tiene 9 valores posibles, preferimos elegir `x` para crear tres nuevas
# ramas en nuestro árbol en vez de 9. Esto es útil ya que obtenemos información
# sobre los valores posibles, y así obtenemos más información por paso de
# resolución.

# Después de fijar un valor vamos a uno de los nodos abiertos (posible mundo).
# Un nodo abierto es un nodo del árbol que aún no hemos dividido (es un nodo
# hoja) y que no es ni inviable ni una solución fija (por lo que debemos seguir
# desarrollándolo).

# Hay dos tipos de problemas que tienen una estrategia de backtracking diferen-
# te. Uno de ellos es un problema de viabilidad, como el de resolver sudokus, y
# el otro es un problema de optimización, como el de colorear mapas/grafos.

# En el primer caso probamos una rama hasta llegar a un nodo hoja y luego
# retrocedemos hasta demostrar que el problema no es factible o nos detenemos
# cuando encontramos una solución factible.

# Para problemas de optimización se elige un nodo que tenga la mejor cota
# (mejor objetivo posible) y si hay varios se elige el de mayor profundidad.

# En general el solucionador guarda lo que ha cambiado en cada paso para poder
# actualizar el espacio de búsqueda actual al saltar a un nodo abierto diferen-
# te en el árbol.
