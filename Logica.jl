using Pkg
Pkg.activate(".")
Pkg.instantiate()

# Lógica Proposicional
# ====================

## Cabecera de Carga y Librería
## ----------------------------

include("./lib/Logic.jl")

#= LEER ENTERO ANTES DE CONTINUAR
Vamos a trabajar, esencialmente, con una librería, `Satisfiability`, que permite trabajar con algunas partes de la Lógica Proposicional de forma cómoda y sencilla. Se basa en el uso de SAT solvers y SMT solvers externos (en la librería anterior, que es simplemente una carcasa personalizada sobre Satisfiability, se ha preparado para trabajar con el solver Z3). Nosotros vamos a hacer un uso limitado de todas sus capacidades, restringiendo su uso al de una calculadora lógica para verificar que estamos formalizando correctamente y comprobar la satisfactibilidad, consecuencia lógica, pasar a forma clausal/normal, algoritmo DPLL, etc.

##    Sobre Z3 y su instalación

    Instalar Z3 es muy sencillo, basta bajarse la versión correspondiente al SO de: https://github.com/Z3Prover/z3/releases/tag/z3-4.13.0. Tras ello, se descomprime en una carpeta (yo la he puesto en c:/utils/z3), y ya está listo para funcionar. 

    Normalmente, bastaría con añadir al path de las variables de entorno de tu SO la dirección en la que se encuentra el ejecutable para que se pueda ejecutar desde cualquier proceso por medio del comando simple `z3`, pero como aquí estamos ejecutándolo dentro de un REPL dentro de VSCode, pueden aparecer algunos problemas de localización.

    En la última versión de `Satisfiability`, la primera ejecución de la librería reconoce si Z3 está instalado y, en caso negativo, se encarga de su instalación en segundo plano. En todo caso, esta opción debe ser estudiada para ver que funciona en todos los casos.
=#

# Tras este paréntesis, podemos hacer un recorrido muy rápido sobre lo poco que necesitamos para poder hacer algunos ejercicios de representación en Lógica Proposicional:

# La declaración de variables booleanas (variables proposicionales) se hace por medio de una macro, por ejemplo:

@satvariable(p, Bool)
@satvariable(q, Bool)
@satvariable(r, Bool)

# También permite declarar Arrays de variables booleanas:

@satvariable(z[1:3], Bool)

# que podemos usar directamente, o "desestructurar", facilitando la escritura cuando son muchas variables:

a, b, c = z

# La definición de fórmulas más complejas se puede hacer por medio sintáctico, funcional, o una mezcla de ambos:

f1 = ((p ⟹ q) ∧ (q ⟹ r)) ⟺ (p ⟹ r)
f2 = iff((p ⟹ q) ∧ (q ⟹ r), p ⟹ r)
f3 = iff(and(implies(p,q), implies(q,r)), (implies(p,r)))

# La función `SAT` ejecuta el solver sobre la fórmula deseada, devolviendo (true / false) y, en caso de que sea satisfactible, almacena en las variables proposicionales los valores que la hacen satisfactible:

SAT(f1)
println("p = $(value(p)), q = $(value(q)), r = $(value(r))")

SAT(¬f1)
println("p = $(value(p)), q = $(value(q)), r = $(value(r))")

# Disponemos también de las funciones habituales INSAT, TAUT y EQUIV para decidir si una fórmula es insatisfactible, tautología, o saber si dos fórmulas son equivalentes. Incluso, trabajando con colecciones de  fórmulas, podemos responder al problema de la consecuencia lógica, CONS (o ⋉ si se quiere usar de forma infija). Por ejemplo:

EQUIV(f1, f2)
EQUIV(f1, f3)
TAUT(f1)
TAUT(p ∨ ¬p)
INSAT(p ∧ ¬p)

println(tree(f1))

begin
    @satvariable(z[1:3], Bool)
    a,b,c = z
    @show [a ∧ b] ⋉ a;
    @show CONS([a ∧ b], a);
    @show [a ∨ b] ⋉ a;
    @show [a ⟹ b, b] ⋉ a;
    @show [a ⟹ b, a] ⋉ b;
    @show CONS([a ⟹ b, a], b);
end

## Uso extendido de Lógica Proposicional dentro de Julia

    # Ten en cuenta que esto nos permite incluir una capa de Lógica Proposicional dentro de Julia que es capaz de considerar valores booleanos sobre variables proposicionales qe internamente usan cualquier tipo de dato, por ejemplo:

    @satvariable(a[1:6], Int)
    c = [215; 275; 335; 355; 420; 580]

    expr = (and(a .>= 0)) ∧ (sum(a .* c) == 1770)
    SAT(expr)
    println("Resultado: $(value(a))")
    println("Comprobación: $(sum(value(a) .* c))")

    expr2 = (and(a .>= 0)) ∧ (sum(a .* c) == 1770) ∧ (a[5] > 0)
    SAT(expr2)
    println("Resultado: $(value(a))")
    println("Comprobación: $(sum(value(a) .* c))")

    # O incluso hacer comprobaciones a nivel de funciones. Por ejemplo
    @satvariable(x, Bool)
    @satvariable(y, Bool)
    @uninterpreted(f, Bool, Bool)
    SAT([x != y, f(x) == y, f(f(x)) == x])
    @show f(true);
    @show f(false);

# -----------------------------------------------------------------------------
# Demostración de utiliadades de la librería
# -----------------------------------------------------------------------------

# La siguiente función sirve de demostración de uso de algunas otras
# funcionalidades que pueden encontrarse en la librería desarrollada para el 
# curso

# Demo de varias funcionalidades
function demoLP(f, var)
    clc();
    cr = Crayon(foreground=:blue,bold=true)
    cn = Crayon(foreground=:white,bold=false)
    println(cr, "Árbol de Formación de: ", cn,"$(pretty(f))",cn)
    println(tree(f))
    println(cr, "Subfórmulas:", cn)
    sf = subform(f)
    for f in sf
        println("  $(pretty(f)), Prof. = $(depth(f))")
    end
    println()

    cnf_f, disyunciones_f = CNF(f)
    println(cr, "FNC:  ",cn,"$(pretty(cnf_f))")
    println(cr, "EQUIV(FNC(f),f)", cn, " = $(EQUIV(cnf_f,f))")
    println(cr, "Cláusulas:", cn)
    dis = pretty.(disyunciones_f)
    for f in dis    
        println("   $f")
    end

    lit = reduce(vcat,literals.(disyunciones_f))
    println(cr, "Literales", cn, " = $lit")

    println(cr, "Forma Clausal:", cn, " $(clausal_form(f))")
    println()
    
    println(cr, "Modelos:", cn)
    sol = models(f, var)
    for (i,s) in enumerate(sol)
        sol10 = join(["$v: $(x ? 1 : 0)" for (v,x) in s], ", ")  # Representación -> 0/1
        println("   m_$i = {$sol10}")                            # La mostramos
    end

    println()
    println(cr, "DPLL (completo):", cn)
    DPLL(f; debug=true)
    println()
    println(cr, "DPLL (soluciones):", cn)
    DPLL(f; debug=false)
end 

@satvariable(p,Bool)
@satvariable(q,Bool)
@satvariable(r,Bool)
@satvariable(s,Bool)
@satvariable(t,Bool)

demoLP(¬p ∨ q, [p,q])
demoLP(p ∧ q, [p,q])
demoLP((¬p ⟹ q) ⟹ r ∧ s, [p,q,r,s])
demoLP((p ∨ q) ⟹ (¬r ∧ t ∧ s), [p,q,r,s,t])
demoLP(((p ∨ q) ⟹ (¬r ∧ t ∧ s)) ∧ ((¬r ∧ t ∧ s) ⟹ (p ∨ q)), [p,q,r,s,t])


# -----------------------------------------------------------------------------
# Ejemplos Resueltos
# -----------------------------------------------------------------------------

# En los ejemplos siguientes, si no se dice lo contrario, habrá que formalizar el razonamiento en una Lógica Proposicional con las variables adecuadas y verificar si el razonamiento es válido o no haciendo uso de las funciones definidas anteriormente.

#= 
Ejemplo 1
---------

Si Juan es comunista, entonces Juan es ateo. Juan es ateo. Por tanto, Juan es comunista.

Definimos las siguientes variables proposicionales:

    1.  c : Juan es comunista
    2.  a : Juan es ateo

=#

clc();
@satvariable(c, Bool)                 # 👀 declaración de variables booleanas
@satvariable(a, Bool)

# Por la definición de Tautología:
TAUT(((c ⟹ a) ∧ a ) ⟹ c)
println("   c = $(value(c)),  a = $(value(a))")

# Por reducción al absurdo:
INSAT(and([c ⟹ a,a,¬c]))
println("   c = $(value(c)),  a = $(value(a))")

# Por la función de consecuencia lógica:
@show [c ⟹ a,a] ⋉ c
println("   c = $(value(c)),  a = $(value(a))")

#= 
Ejemplo 2
---------

Cuando tanto la temperatura como la presión atmosférica permanecen contantes, no llueve. La temperatura permanece constante. En consecuencia, en caso de que llueva, la presión atmosférica no permanece constante.

Definimos las siguientes variables proposicionales:

    1.  T : Temperatura permanece constante
    2.  P : Presión permanece constante
    3.  L : Llueve 
=#

clc();
@satvariable(T, Bool)
@satvariable(P, Bool)
@satvariable(L, Bool)
@show [(T ∧ P) ⟹ ¬ L, T] ⋉ (L ⟹ ¬ P)

#= 
Ejemplo 3
---------

Siempre que un número x es divisible por 10, acaba en 0. El número x no acaba en 0. Luego, x no es divisible por 10.

Definimos las siguientes variables proposicionales:

    1.  d10 : x es divisible por 10
    2.  a0 : x acaba en 0
=#

clc();
@satvariable(d10, Bool)
@satvariable(a0, Bool)
@show [d10 ⟹ a0, ¬a0] ⋉ ¬d10


#= 
Ejemplo 4
---------

En un texto de Lewis Carroll, el tio Jorge y el tío Jaime discuten acerca de la barbería del pueblo, atendida por tres barberos: Alberto, Benito y Carlos. Los dos tíos aceptan las siguientes premisas:

    1. Si Carlos no está en la barbería, entonces ocurrirá que si tampoco está Alberto, Benito tendrá que estar para atender el establecimiento.
    2. Si Alberto no está, tampoco estará Benito.
    
El tío Jorge concluye de todo esto que Carlos no puede estar ausente, mientras que el tío Jaime afirma que sólo puede concluirse que Carlos y Alberto no pueden estar ausentes a la vez. 

¿Cuál de los dos tiene razón?

Definimos las siguientes variables proposicionales:

    1.  A : Alberto está en la barbería
    2.  B : Benito está en la barbería
    3.  C : Carlos está en la barbería 
=#

clc();
@satvariable(z[1:3],Bool)
A,B,C = z
Hechos = [¬C ⟹ (¬A ⟹ B), ¬A ⟹ ¬B]
Jorge = Hechos ⋉ C
Jaime = Hechos ⋉ ¬(¬C ∧ ¬A)
@show Jorge;
@show Jaime;

#= 
Ejemplo 5
---------

Demuestra la corrección del siguiente argumento.

    1. Los animales con pelo o que dan leche son mamíferos.
    2. Los mamíferos que tienen pezuñas o que rumian son ungulados.
    3. Los ungulados de cuello largo son jirafas.
    4. Los ungulados con rayas negras son cebras.

Se observa un animal que tiene pelos, pezuñas y rayas negras. Por tanto, el animal es una cebra.

Definimos las siguientes variables proposicionales:

    1.  P : Animal con pelo
    2.  L : Animal que da leche
    3.  M : Mamífero
    4.  Z : Pezuñas
    5.  R : Rumian
    6.  U : Ungulado
    7.  C : Cuello largo
    8.  J : Jirafa
    9.  N : Rayas negras
    10. Cb : Cebra 
=#

@satvariable(z[1:10], Bool)
P, L, M, Z, R, U, C, J, N, Cb = z
Hechos = [(P ∨ L) ⟹ M, (M ∧ (Z ∨ R)) ⟹ U, (U ∧ C) ⟹ J, (U ∧ N) ⟹ Cb, P, Z, N]
@show Hechos ⋉ Cb


#= 
Ejemplo 6
---------

Problema de las N Reinas...

=#

N = 8

# Usaremos una variable proposicional para cada posición del tablero, indicando si hay una reina o no. Así, a partir de ahora, si se verifica r[i,j] significa que en la posición (i,j) del trablero hay una reina.
@satvariable(r[1:N,1:N], Bool)

# 1. En cada fila hay como mucho una reina: Si r(i.j) entonces no puede verificarse ningún otro r(i,j´)

Filas(N) = [ r[i,j]⟹ ¬r[i,j´] for i in 1:N for j in 1:N for j´ in 1:N if j ≠ j´]

# 2. En cada columna hay como mucho una reina: Si r(i.j) entonces no puede verificarse ningún otro r(i´,j)

Columnas(N) = [ r[i,j]⟹ ¬r[i´,j] for i in 1:N for j in 1:N for i´ in 1:N if i ≠ i´]

# 3. En cada diagonal principal hay como mucho una reina: Si r(i,j) entonces no puede verificarse ningún otro r(i+k,j+k)

DiagonalPrincipal(N) = [ r[i,j]⟹ ¬r[i+k,j+k] for i in 1:N for j in 1:N for k in -N:N if (k ≠ 0) && (i+k ∈ 1:N) && (j+k ∈ 1:N)]

# 3. En cada diagonal secundaria hay como mucho una reina: Si r(i,j) entonces no puede verificarse ningún otro r(i+k,j-k)

DiagonalSecundaria(N) = [ r[i,j]⟹ ¬r[i+k,j-k] for i in 1:N for j in 1:N for k in -N:N if (k ≠ 0) && (i+k ∈ 1:N) && (j-k ∈ 1:N)]

# Todo lo anterior lo veririca, por ejemplo, el tablero vacío, así que puede dar soluciones erróneas. Por tanto, hemos de introducir condiciones de existencia de suficientes reinas:

# 4. En cada columna hay, al menos, una reina

Marco(N) = [or(r[:,j]) for j in 1:N]

# Una distribución de reinas será solución si verifica simultáneamente todas las condiciones anteriores:
NReinas(N) = [Filas(N); Columnas(N); DiagonalPrincipal(N); DiagonalSecundaria(N); Marco(N)]

SAT(and(NReinas(N)))

value(r)

# También tenemos una función que nos devuelve todos los modelos de una fórmula. Lo que devuelve es una colección de diccionarios en los que se indica el valor de cada variable. Además de la fórmula, debes indicarle qué variables quieres que devuelva.

# 👀 ¡¡ Cuidado con la siguiente ejecución, el número de modelos podría ser exponencial en N !!
# 👀  Si quieres probarlo, reduce N a 4 o 5...
N = 5
@satvariable(r[1:N,1:N], Bool)
models(and(NReinas(N)), [r[i,j] for i in 1:N for j in 1:N])

#= 
-------------------
IMPLEMENTACIÓN DPLL
-------------------

Este ejercicio está orientado a explicar la implementación de DPLL que puedes encontrar en la librería. Para ello, haremos uso de la nomenclatura DIMACS, basada en vectores numéricos, y supondremos que las fórmulas vienen dadas en Forma Clausal (o, equivalentemente, en Forma Normal Conjuntiva):

Si las variables que se usan son x_1,...,x_n, una cláusula vendrá dada por el conjunto de índices de los literales que la forman (positivos, si el literal viene afirmado, y negativos, si el literal está negado). 

Representación:
    Es decir, la representación de la clásula C será:
        {i: x_i ∈ C} ∪ {-i: ¬x_i ∈ C}

    Lo más habitual es representar $C$ como la lista/colección/conjunto de los elementos que la forman. Por ejemplo:

        C ≡ (x_1 ∨ ¬x_3 ∨ x_4) ⟶ C ≡ [1,-3,4]

    Así pues, una fórmula siempre se puede expresar como una colección de listas de la forma anterior (que corresponde al conjunto de las cláusulas de su forma clausal). Por ejemplo:

        F ≡ (p∨¬q) ∧ (p∨q) ∧ r ⟶ F ≡ [ [1,-2], [1,2], [3] ]

Algoritmo DPLL:
    Los pasos a seguir para la implementación del algoritmo DPLL se siguen inmediatamente del modo de funcionamiento de este algoritmo:

    1. Reconocer si hay cláusulas unitarias (equivalentemente, listas con un solo elemento).
    2. Si hay claúsulas unitarias, propagarlas, es decir: 
        1. Eliminar las cláusulas que contengan ese literal.
        2. Eliminar el literal complementario de las cláusulas que contengan el complementario.
        3. Dejar igual el resto de cláusulas (aquellas que no tienen ni el literal ni el complementario).
    3. Si no hay cláusulas unitarias, seleccionar uno de los literales que aparezcan en alguna cláusula y llamar dos veces al procedimiento DPLL que estamos definiendo (se forman 2 ramas de ejecución): 
        1. Una llamada añadiendo una cláusula unitaria con el literal seleccionado. 
        2. Otra llamada añadiendo una cláusula unitaria con el literal complementario.
    4. Cuando ya no quedan cláusulas compuestas en una rama, podemos interpretar lo que dice esa rama:
        1. Si hay dos claúsulas unitarias opuestas (una tiene un literal, y otra su complementario): esa rama no da solución para la fórmula de entrada.
        2. Si no hay cláusulas unitarias opuestas, entonces las cláusulas que quedan especifican una valoración que es modelo de la fórmula de entrada.

Observaciones
    1. DPLL es un algoritmo recursivo.
    2. En cada una las llamadas recursivas del paso 3 ya hay una cláusula unitaria, por lo que se ejecutará el paso 2 en cada una de ellas, simplificando el conjunto de cláusulas de nuevo.

=#


# -----------------------------------------------------------------------------
# Ejercicios Propuestos
# -----------------------------------------------------------------------------

#= 
Ejercicio 1
-----------

Haciendo uso de la librería y utilidades vistas, decide si los siguientes razonamientos son correctos:

    1. El ladrón debió entrar por la puerta, a menos que el robo se perpetrara desde dentro y uno de los sirvientes estuviera implicado en él. Pero sólo podía entrar por la puerta si alguien le descorría el cerrojo. Si alguien lo hizo, es que uno de los sirvientes estaba implicado en el robo. Luego, seguro que algún sirviente ha estado implicado.

    2. Si el tiempo está agradable y el cielo despejado, saldremos a navegar y nos daremos un baño. No es verdad que el cielo no esté despejado a menos que nos bañemos. Luego el tiempo no está agradable.

    3. Los salarios no suben si no aumentan los precios. No obstante, subirán los salarios y no los precios, a no ser que suban los salarios y simultáneamente se produzca inflación. Luego, en cualquier caso se producirá inflación.

    4. Si se elevan los precios o los salarios habrá inflación. Si hay inflación, el gobierno ha de regularla o el pueblo sufrirá. Si el pueblo sufre, los gobernantes se harán más impopulares. Pero es así que el gobierno no regulará la inflación y que, sin embargo, los gobernantes no se harán más impopulares. Entonces es que no subirán los salarios.

    5. La física cuántica describe la naturaleza a base de observables clásicos o a base de estados abstractos. Si la describe mediante los primeros, entonces nos permite representar las cosas intuitivamente, pero nos exige renunciar a la causalidad. En cambio, si la describe mediante los segundos, nos impide la representación intuitiva, pero nos permite conservar la causalidad. La física cuántica nos permitirá representar las cosas intuitivamente, a no ser que nos exija renunciar a la causalidad. Por tanto, no es cierto que nos permita representar las cosas intuitivamente sólo si no renuncia a la causalidad. 
=#


#= 
Ejercicio 2
-----------

A partir del algoritmo DPLL implementado, define funciones que decidan SAT, TAUT, equivalencia entre fórmulas y Consecuencia Lógica. Para diferenciarlas de las funciones que vienen en la propia librería ponles como nombre: SAT-DPLL, INSAT-DPLL, TAUT-DPLL, EQUIV-DPLL y CONS-DPLL.
=#

#= 
Ejercicio 3
-----------

Aplica DPLL para resolver los siguientes problemas (se recomienda hacer los ejercicios a mano y después comprobar que son correctos usando la nomeclatura en vectores numéricos y usando la función DPLL explicada anteriormente):

1. Determina la consistencia de los siguientes conjuntos de cláusulas:

    {p ∨ ¬q, p ∨ q, ¬p ∨ ¬q, ¬p ∨ q}
    {¬r, q, p ∨ ¬q, ¬p ∨ r}
    {p ∨ q ∨ r, ¬p ∨ q, ¬q ∨ r, ¬r, p ∨ r}
    {p, ¬p ∨ q, r}
    {¬p ∨ ¬q ∨ r, ¬s ∨ t, ¬t ∨ p, s, ¬s ∨ u, ¬u ∨ q, ¬r}
    {p ∨ q, q ∨ r, r ∨ w, ¬r ∨ ¬p, ¬w ∨ ¬q, ¬q ∨ ¬r}
    {¬p ∨ ¬q ∨ r, ¬p ∨ ¬t ∨ u, ¬p ∨ ¬u ∨ s, ¬t ∨ q, t, p, ¬s}

2. Decide la verdad o falsedad de las siguientes afirmaciones:

    {p ⟹ (q ⟹ r), r ⟹ q} ⊨ r ⟺ q
    {p ⟹ q, q ⟹ (p ∧ q), p ⟹ r} ⊨ q ⟹ r  
=#

#= 
Ejercicio 4
-----------

Las guerras clon han comenzado. Durante el transcurso de una refriega, tres caballeros Jedi, Anakin, Obi Wan y Yoda, se encuentran con el conde Dooku. Utilizaremos el lenguaje proposicional A, O, Y para denotar que el correspondiente caballero participa en el combate, y G para denotar que los Jedi han ganado.

1. Formaliza las siguientes afirmaciones:

    F_1: Para derrotar al conde Dooku deben participar al menos dos caballeros Jedi.
    F_2: El Conde Dooku gana cuando sólo participa un caballero.
    F_3: Si el Conde Dooku pierde entonces Anakin ha participado en el combate.
    F_4: Si el Conde Dooku pierde, entonces no han participado los tres caballeros.

2. ¿Es cierto que {F_1,F_2,F_3} ⊨ G→A∧O? 
=#

#= 
Ejercicio 5
-----------

En una isla habitan dos tribus de nativos, A y B. Todos los miembros de la tribu A siempre dicen la verdad, mientras que todos los de la tribu B siempre mienten. Llegamos a esta isla y le preguntamos a un nativo si allí hay oro, a lo que nos responde: 

    Hay oro en la isla si y sólo si yo siempre digo la verdad.

A partir de lo que nos han dicho:
    1. ¿Podemos saber si hay oro en la isla?
    2. ¿Podemos determinar a qué tribu pertenece el nativo que nos respondió? 
=#

#= 
Ejercicio 6
-----------

Tres niños, Manolito, Juanito y Jesuli, son sorprendidos después de haberse roto el cristal de una ventana cerca de donde estaban jugando. Al preguntarles si alguno de ellos lo había roto, respondieron lo siguiente:

    Manolito: Juanito lo hizo, Jesuli es inocente.
    Juanito: Si Manolito lo rompió, entonces Jesuli es inocente.
    Jesuli: Yo no lo hice, pero uno de los otros dos sí lo rompió.

1. ¿Son consistentes las afirmaciones anteriores? 
2. Si se comprueba que ninguno de los niños rompió el cristal, ¿quiénes han mentido?
3. Si se asume que todos dicen la verdad, ¿quién rompió el cristal? 
=#