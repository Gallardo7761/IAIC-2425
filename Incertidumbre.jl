include("./lib/MCTS.jl")


##########################
## Tic-Tac-Toe          ##
##########################

#=

Recuerda, el juego debe tener las siguientes funciones modeladas:

acc_disponibles::Function   # s   -> colección de acciones aplicables a `s`
aplica_acc::Function        # s,a -> estado resultante de aplicar `a` a `s`
es_terminal::Function       # s   -> true/false decide si `s` es terminal
resultado::Function         # s,p -> Ganancia de `p` en el estado `s`

Un estado será un vector de 9 posiciones, indicando con -1,1,0 la ocupación de 
cada casilla.

=#

function acc_disponibles_ttt(s)
  return findall(x -> x == 0, s)  # Casillas vacías
end

function aplica_acc_ttt(s, a)
  s2 = copy(s)
  jugador_actual = sum(s) == 0 ? 1 : -1  # Determina el jugador actual
  s2[a] = jugador_actual
  return s2
end

function es_terminal_ttt(s)
  return ganador_ttt(s) != 0 || all(x -> x != 0, s)  # Si hay ganador o está lleno
end

function ganador_ttt(s)
  lineas = [(1,2,3), (4,5,6), (7,8,9), (1,4,7), (2,5,8), (3,6,9), (1,5,9), (3,5,7)]
  for (i, j, k) in lineas
      if s[i] != 0 && s[i] == s[j] && s[j] == s[k]
          return s[i]
      end
  end
  return 0  # Nadie ha ganado
end

function  resultado_ttt(s,p)
  g = ganador_ttt(s)
  if g == 0
    return 0.5
  elseif g == p 
    return 1
  else
    return 0
  end
end

# Crear una instancia de JuegoGenerico para Tic-Tac-Toe
ttt = JuegoGenerico(
  acc_disponibles_ttt,
  aplica_acc_ttt,
  es_terminal_ttt,
  resultado_ttt
)

# Estado inicial del juego (tablero vacío)
s0 = fill(0, 9)

# Función para imprimir el tablero de Tic-Tac-Toe
function print_tablero(s)
  simbolo = ["O", " ", "X"]
  println(" $(simbolo[s[1]+2]) | $(simbolo[s[2]+2]) | $(simbolo[s[3]+2])")
  println("---|---|---")
  println(" $(simbolo[s[4]+2]) | $(simbolo[s[5]+2]) | $(simbolo[s[6]+2])")
  println("---|---|---")
  println(" $(simbolo[s[7]+2]) | $(simbolo[s[8]+2]) | $(simbolo[s[9]+2])")
end

print_tablero(s1)


# Función para jugar un turno humano
function turno_humano(s)
  while true
      print("Elige una casilla libre (1-9): ")
      a = parse(Int, readline())
      if s[a] == 0
          return a
      else
          println("   Casilla ocupada, por favor...")
      end
  end
end


# Función principal del juego
#   prof_pens: Entero que indica el número de iteraciones que se ejecuta MCTS
#             A mayor valor, mejores resultados, pero más tiempo de espera
function play_ttt(prof_pens::Int)
  # Estado inicial del tablero (vacío)
  s = fill(0, 9)
  jugador_actual = 1  # 1 para humano, -1 para la máquina

  println("¡Bienvenido a Tic-Tac-Toe!")
  print_tablero(s)

  while true
      if jugador_actual == 1
          # Turno humano
          println("\nTu turno:")
          a = turno_humano(s)
          s = aplica_acc_ttt(s, a)
      else
          # Turno de la máquina (MCTS)
          println("\nTurno de la máquina:")
          s = mcts(s, ttt, prof_pens, 1)  # MCTS con 1000 iteraciones
      end

      # Imprimir el tablero
      print_tablero(s)

      # Verificar si el juego ha terminado
      if es_terminal_ttt(s)
          ganador = ganador_ttt(s)
          if ganador == 1
              println("¡Has ganado!")
          elseif ganador == -1
              println("La máquina ha ganado.")
          else
              println("¡Es un empate!")
          end
          break
      end

      # Cambiar de jugador
      jugador_actual *= -1
  end
end
