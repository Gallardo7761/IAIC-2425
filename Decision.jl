using Pkg
Pkg.activate(".")
# Pkg.instantiate()

include("./lib/ID3.jl")

###########################
## ID3 Datos Categóricos ##
###########################

## Ejercicio 1.
# Vamos a trabajar con el dataset Golf, que contiene la opinión de varios 
# usuarios de un campo de Golf, indicando si la experiencia de haber jugado en 
# un día determinado ha sido agradable o no dependiendo de las condiciones 
# climáticas.

# Comenzamos por cargar el dataset en un dataframe de la forma habitual:
data = CSV.read("./datasets/Golf.csv", DataFrame, header=true)
describe(data)

# El atributo objetivo es la columna última, `Play`, y las otras se usarán como 
# atributos de decisión
atributos = propertynames(data)[1:4]
objetivo = propertynames(data)[end]

# Preparamos el dataframe para proporcionar los conjuntos de entrenamiento
# y test (por defecto, 80%+20%)
train_data, test_data = train_test_split(data)

# Entrenamos el modelo (crea el árbol), usando solo el entrenamiento
id3 = id3_train(train_data, atributos, objetivo)

# Representamos el árbol para saber qué camino siguen las decisiones:
println(show_arbol(id3))

# Predecimos las respuestas sobre el conjunto de test:
true_labels = test_data[:, objetivo]
predicciones = ID3_predict(id3, test_data)

# Y evaluamos los resultados
evaluacion = evalua_modelo(true_labels, predicciones)

# Tras la evaluación, obtenemos una estructura con todos los resultados del 
# rendimiento del modelo generado:
begin
    println("\nMetricas de Evaluación:")
    println("Accuracy: ", round(evaluacion.accuracy, digits=4))

    println("\nMétricas por Clase:")
    for (label, metrica) in evaluacion.class_metricas
        println("Clase $label:")
        println("  Precisión:  ", round(metrica.precision, digits=4))
        println("  Recall:     ", round(metrica.recall, digits=4))
        println("  F1 Score:   ", round(metrica.f1_score, digits=4))
    end

    println("\nMatriz de Confusión:")
    display(evaluacion.MC)
end

# que también podemos representar gráficamente
display(plot_MC(evaluacion))

# Extrae del árbol de decisión construido las reglas de decisión que lo forman
# y escribe un programa en Julia que calcule la misma función que el árbol.

## Ejercicio 2

# Usa los modelos categóricos de decisión (`Presion`, `Lentes`, `Examen`) para 
# realizar tareas similares.

#########################
## ID3 Datos Numéricos ##
#########################

# Ejercicio 3: Iris
# -----------------

# Carga del conjunto de datos
data = CSV.read("./datasets/iris.csv", DataFrame, header=true)
describe(data)

# El atributo objetivo es la columna última, `class`, y las otras se usarán como 
# atributos de decisión
atributos = propertynames(data)[1:4]
objetivo = propertynames(data)[end]

# Preparamos el dataframe para proporcionar los conjuntos de entrenamiento
# y test (por defecto, 80%+20%)
train_data, test_data = train_test_split(data;train_ratio=0.66)

# Entrenamos el modelo (crea el árbol), usando solo el entrenamiento
id3 = id3_train(train_data, atributos, objetivo)

# Representamos el árbol para saber qué camino siguen las decisiones:
println(show_arbol(id3))

# Predecimos las respuestas sobre el conjunto de test:
true_labels = test_data[:, objetivo]
predicciones = ID3_predict(id3, test_data)

# Y evaluamos los resultados
evaluacion = evalua_modelo(true_labels, predicciones)

# Tras la evaluación, obtenemos una estructura con todos los resultados del 
# rendimiento del modelo generado:
begin
    println("\nMetricas de Evaluación:")
    println("Accuracy: ", round(evaluacion.accuracy, digits=4))

    println("\nMétricas por Clase:")
    for (label, metrica) in evaluacion.class_metricas
        println("Clase $label:")
        println("  Precisión:  ", round(metrica.precision, digits=4))
        println("  Recall:     ", round(metrica.recall, digits=4))
        println("  F1 Score:   ", round(metrica.f1_score, digits=4))
    end

    println("\nMatriz de Confusión:")
    display(evaluacion.MC)
end

# que también podemos representar gráficamente

display(plot_MC(evaluacion))

# Ejercicio 4: Wine
# -----------------

# Carga del conjunto de datos
data = CSV.read("./datasets/wine.csv", DataFrame, header=true)
describe(data)

# El atributo objetivo es la columna última, `class`, y las otras se usarán como 
# atributos de decisión
atributos = propertynames(data)[2:14]
objetivo = propertynames(data)[1]

# Preparamos el dataframe para proporcionar los conjuntos de entrenamiento
# y test (por defecto, 80%+20%)
train_data, test_data = train_test_split(data)

# Entrenamos el modelo (crea el árbol), usando solo el entrenamiento
id3 = id3_train(train_data, atributos, objetivo)

# Representamos el árbol para saber qué camino siguen las decisiones:
println(show_arbol(id3))

# Predecimos las respuestas sobre el conjunto de test:
true_labels = test_data[:, objetivo]
predicciones = ID3_predict(id3, test_data)

# Y evaluamos los resultados
evaluacion = evalua_modelo(true_labels, predicciones)

# Tras la evaluación, obtenemos una estructura con todos los resultados del 
# rendimiento del modelo generado:
begin
    println("\nMetricas de Evaluación:")
    println("Accuracy: ", round(evaluacion.accuracy, digits=4))

    println("\nMétricas por Clase:")
    for (label, metrica) in evaluacion.class_metricas
        println("Clase $label:")
        println("  Precisión:  ", round(metrica.precision, digits=4))
        println("  Recall:     ", round(metrica.recall, digits=4))
        println("  F1 Score:   ", round(metrica.f1_score, digits=4))
    end

    println("\nMatriz de Confusión:")
    display(evaluacion.MC)
end

# que también podemos representar gráficamente
display(plot_MC(evaluacion))

#########################
## ID3 Datos Mezclados ##
#########################

# Ejercicio 5: Golf Numérico
# --------------------------

# Carga del conjunto de datos
data = CSV.read("./datasets/GolfNum.csv", DataFrame, header=true)
describe(data)

# El atributo objetivo es la columna última, `class`, y las otras se usarán como 
# atributos de decisión
atributos = propertynames(data)[2:5]
objetivo = propertynames(data)[6]

# Preparamos el dataframe para proporcionar los conjuntos de entrenamiento
# y test (por defecto, 80%+20%)
train_data, test_data = train_test_split(data)

# Entrenamos el modelo (crea el árbol), usando solo el entrenamiento
id3 = id3_train(train_data, atributos, objetivo,5)

# Representamos el árbol para saber qué camino siguen las decisiones:
println(show_arbol(id3))

# Predecimos las respuestas sobre el conjunto de test:
true_labels = test_data[:, objetivo]
predicciones = ID3_predict(id3, test_data)

# Y evaluamos los resultados
evaluacion = evalua_modelo(true_labels, predicciones)

# Tras la evaluación, obtenemos una estructura con todos los resultados del 
# rendimiento del modelo generado:
begin
    println("\nMetricas de Evaluación:")
    println("Accuracy: ", round(evaluacion.accuracy, digits=4))

    println("\nMétricas por Clase:")
    for (label, metrica) in evaluacion.class_metricas
        println("Clase $label:")
        println("  Precisión:  ", round(metrica.precision, digits=4))
        println("  Recall:     ", round(metrica.recall, digits=4))
        println("  F1 Score:   ", round(metrica.f1_score, digits=4))
    end

    println("\nMatriz de Confusión:")
    display(evaluacion.MC)
end

# que también podemos representar gráficamente
display(plot_MC(evaluacion))

# Ejercicio 6: Obesity
# --------------------

# Carga del conjunto de datos
data = CSV.read("./datasets/Obesity.csv", DataFrame, header=true)
describe(data)

# El atributo objetivo es la columna última, `class`, y las otras se usarán como 
# atributos de decisión
atributos = propertynames(data)[1:16]
objetivo = propertynames(data)[17]

# Preparamos el dataframe para proporcionar los conjuntos de entrenamiento
# y test (por defecto, 80%+20%)
train_data, test_data = train_test_split(data)

# Entrenamos el modelo (crea el árbol), usando solo el entrenamiento
id3 = id3_train(train_data, atributos, objetivo)

# Representamos el árbol para saber qué camino siguen las decisiones:
println(show_arbol(id3))

# Predecimos las respuestas sobre el conjunto de test:
true_labels = test_data[:, objetivo]
predicciones = ID3_predict(id3, test_data)

# Y evaluamos los resultados
evaluacion = evalua_modelo(true_labels, predicciones)

# Tras la evaluación, obtenemos una estructura con todos los resultados del 
# rendimiento del modelo generado:
begin
    println("\nMetricas de Evaluación:")
    println("Accuracy: ", round(evaluacion.accuracy, digits=4))

    println("\nMétricas por Clase:")
    for (label, metrica) in evaluacion.class_metricas
        println("Clase $label:")
        println("  Precisión:  ", round(metrica.precision, digits=4))
        println("  Recall:     ", round(metrica.recall, digits=4))
        println("  F1 Score:   ", round(metrica.f1_score, digits=4))
    end

    println("\nMatriz de Confusión:")
    display(evaluacion.MC)
end

# que también podemos representar gráficamente
display(plot_MC(evaluacion))

