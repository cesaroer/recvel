import Foundation

/// Mecanica de cada ejercicio de `ExerciseLibrary`: como se hace, claves tecnicas
/// y errores comunes. Todo el texto vive en la app (offline, sin backend).
///
/// Las imagenes de demostracion vienen de free-exercise-db
/// (https://github.com/yuhonas/free-exercise-db), publicado bajo Unlicense
/// (dominio publico). Se empaquetan localmente en Recvel/Resources/ExerciseMedia
/// como dos fotogramas por ejercicio (`<slug>_0.jpg` = inicio, `<slug>_1.jpg` = fin);
/// la vista los alterna para simular el gif del movimiento.
struct ExerciseMechanics: Identifiable, Hashable {
    var id: String { exercise }
    /// Nombre EXACTO tal como aparece en `ExerciseLibrary`.
    let exercise: String
    /// Que entrena y para que sirve, en una linea.
    let summary: String
    /// Posicion de partida.
    let setup: String
    /// Ejecucion paso a paso.
    let steps: [String]
    /// Claves tecnicas cortas (lo que hay que sentir/vigilar).
    let cues: [String]
    /// Errores comunes que restan resultado o suman riesgo.
    let mistakes: [String]
    /// Slug del fotograma empaquetado, si existe demostracion visual.
    let mediaSlug: String?

    /// Nombres de los recursos de imagen (0 = inicio, 1 = final del recorrido).
    var frameNames: [String] {
        guard let mediaSlug else { return [] }
        return ["\(mediaSlug)_0", "\(mediaSlug)_1"]
    }
}

enum ExerciseMechanicsCatalog {
    static let attribution = "Imagenes: free-exercise-db (Unlicense, dominio publico)"

    static func mechanics(for name: String) -> ExerciseMechanics? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = entries.first(where: { $0.exercise.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exact
        }
        // Las plantillas guardan lineas como "Sentadilla 4x8" o "Correr 30 min";
        // si el nombre llega con sufijos, se busca por prefijo mas largo.
        return entries
            .filter { trimmed.localizedCaseInsensitiveContains($0.exercise) }
            .max { $0.exercise.count < $1.exercise.count }
    }

    static func hasMechanics(for name: String) -> Bool { mechanics(for: name) != nil }

    // swiftlint:disable:next line_length
    static let entries: [ExerciseMechanics] = [
        // MARK: - Pecho
        .init(
            exercise: "Press de banca",
            summary: "Empuje horizontal: pectoral, triceps y deltoides anterior.",
            setup: "Acostado en banca, pies firmes en el piso, escapulas juntas y hundidas, agarre poco mas ancho que hombros.",
            steps: [
                "Saca la barra del rack y llevala sobre la linea del pecho con los brazos extendidos.",
                "Baja controlado (2-3 s) hasta rozar la parte baja del pecho, codos a ~45 grados del torso.",
                "Empuja hacia arriba y ligeramente atras hasta extender codos sin perder el arco de la espalda."
            ],
            cues: ["Escapulas retraidas todo el set", "Munecas apiladas sobre los codos", "Pies empujando el piso"],
            mistakes: ["Rebotar la barra en el pecho", "Codos abiertos a 90 grados", "Levantar los gluteos de la banca"],
            mediaSlug: "Barbell_Bench_Press___Medium_Grip"
        ),
        .init(
            exercise: "Press inclinado",
            summary: "Empuje inclinado: enfasis en la porcion clavicular del pectoral.",
            setup: "Banca a 30-45 grados, escapulas retraidas, agarre poco mas ancho que hombros.",
            steps: [
                "Lleva la barra sobre la clavicula con codos extendidos.",
                "Baja controlado hasta la parte alta del pecho.",
                "Empuja hasta extender sin bloquear de golpe."
            ],
            cues: ["Inclinacion no mayor a 45 grados", "Codos a 45 grados del torso"],
            mistakes: ["Inclinar demasiado (lo vuelve press de hombro)", "Bajar la barra al cuello"],
            mediaSlug: "Barbell_Incline_Bench_Press___Medium_Grip"
        ),
        .init(
            exercise: "Aperturas con mancuernas",
            summary: "Aislamiento del pectoral en aduccion horizontal.",
            setup: "Acostado, mancuernas sobre el pecho, codos con flexion fija de ~15 grados.",
            steps: [
                "Abre los brazos en arco hasta sentir estiramiento en el pecho (sin dolor en el hombro).",
                "Cierra el arco juntando las manos sobre el pecho."
            ],
            cues: ["El codo no cambia de angulo", "Piensa en abrazar, no en empujar"],
            mistakes: ["Bajar mas alla del plano del torso", "Convertirlo en press flexionando codos"],
            mediaSlug: "Dumbbell_Flyes"
        ),
        .init(
            exercise: "Fondos",
            summary: "Empuje vertical en paralelas: pectoral bajo y triceps.",
            setup: "Suspendido en paralelas, brazos extendidos, hombros lejos de las orejas.",
            steps: [
                "Baja flexionando codos hasta que el hombro quede a la altura del codo.",
                "Empuja hasta extender manteniendo el torso estable."
            ],
            cues: ["Torso ligeramente inclinado al frente para pecho, vertical para triceps", "Escapulas deprimidas"],
            mistakes: ["Bajar mas de lo que permite el hombro", "Encoger los hombros hacia las orejas"],
            mediaSlug: "Dips___Triceps_Version"
        ),
        .init(
            exercise: "Flexiones",
            summary: "Empuje horizontal con peso corporal y demanda de core.",
            setup: "Manos bajo los hombros, cuerpo en linea recta de cabeza a talones.",
            steps: [
                "Baja el pecho hacia el piso con codos a ~45 grados.",
                "Empuja el piso hasta extender codos manteniendo la cadera alineada."
            ],
            cues: ["Gluteos y abdomen activos", "El cuerpo se mueve como una tabla"],
            mistakes: ["Cadera hundida o levantada", "Rango parcial", "Cuello adelantado"],
            mediaSlug: "Pushups"
        ),

        // MARK: - Espalda
        .init(
            exercise: "Remo con barra",
            summary: "Jalon horizontal: dorsal, romboides y trapecio medio.",
            setup: "Cadera en bisagra, torso a ~45 grados, espalda neutra, barra colgando bajo los hombros.",
            steps: [
                "Jala la barra hacia el ombligo llevando los codos atras.",
                "Baja controlado hasta extender los brazos sin redondear la espalda."
            ],
            cues: ["Junta las escapulas al final", "El torso no sube con el jalon"],
            mistakes: ["Usar impulso de cadera", "Redondear la zona lumbar", "Jalar con biceps unicamente"],
            mediaSlug: "Bent_Over_Barbell_Row"
        ),
        .init(
            exercise: "Jalon al pecho",
            summary: "Jalon vertical guiado: dorsal ancho.",
            setup: "Sentado, muslos fijos bajo el rodillo, agarre amplio prono.",
            steps: [
                "Jala la barra hacia la parte alta del pecho llevando los codos hacia las costillas.",
                "Sube controlado dejando que las escapulas roten arriba."
            ],
            cues: ["Pecho arriba", "Codos hacia abajo, no hacia atras"],
            mistakes: ["Jalar detras de la nuca", "Balancear el torso"],
            mediaSlug: "Wide_Grip_Lat_Pulldown"
        ),
        .init(
            exercise: "Dominadas",
            summary: "Jalon vertical con peso corporal: dorsal, biceps y core.",
            setup: "Colgado con agarre prono a la anchura de hombros, escapulas activas.",
            steps: [
                "Deprime las escapulas y jala hasta pasar la barbilla sobre la barra.",
                "Baja controlado hasta extender los codos."
            ],
            cues: ["Inicia el movimiento con las escapulas", "Costillas abajo, sin arquear"],
            mistakes: ["Balanceo (kipping) involuntario", "Rango a medias", "Encoger los hombros al colgar"],
            mediaSlug: "Pullups"
        ),
        .init(
            exercise: "Remo con mancuerna",
            summary: "Jalon horizontal unilateral: corrige asimetrias del dorsal.",
            setup: "Una rodilla y una mano en la banca, espalda plana, mancuerna colgando.",
            steps: [
                "Jala la mancuerna hacia la cadera manteniendo el codo pegado.",
                "Baja hasta estirar el dorsal sin rotar el torso."
            ],
            cues: ["Hombros paralelos al piso", "Jala con el codo, no con la mano"],
            mistakes: ["Rotar el torso para subir mas peso", "Tirar hacia el hombro en vez de la cadera"],
            mediaSlug: "One_Arm_Dumbbell_Row"
        ),
        .init(
            exercise: "Band pull-aparts",
            summary: "Salud escapular: trapecio medio y deltoides posterior.",
            setup: "De pie, banda a la altura del pecho, brazos extendidos al frente.",
            steps: [
                "Separa la banda llevando las manos a los lados hasta juntar escapulas.",
                "Regresa lento resistiendo la banda."
            ],
            cues: ["Hombros lejos de las orejas", "Movimiento solo de escapulas y brazos"],
            mistakes: ["Arquear la espalda", "Soltar la banda de golpe"],
            mediaSlug: "Band_Pull_Apart"
        ),

        // MARK: - Piernas
        .init(
            exercise: "Sentadilla",
            summary: "Patron de sentadilla: cuadriceps, gluteo y core.",
            setup: "Barra sobre el trapecio, pies a la anchura de hombros y puntas ligeramente afuera.",
            steps: [
                "Toma aire, tensa el abdomen y baja llevando cadera y rodillas al mismo tiempo.",
                "Desciende hasta que el pliegue de la cadera pase la rodilla, si tu movilidad lo permite.",
                "Sube empujando el piso, extendiendo cadera y rodillas juntas."
            ],
            cues: ["Rodillas siguiendo la linea de los pies", "Torso y cadera suben al mismo ritmo", "Peso repartido en todo el pie"],
            mistakes: ["Rodillas colapsando hacia dentro", "Levantar la cadera primero (buenos dias)", "Talones despegando"],
            mediaSlug: "Barbell_Full_Squat"
        ),
        .init(
            exercise: "Peso muerto",
            summary: "Bisagra de cadera: cadena posterior completa.",
            setup: "Barra sobre el medio del pie, tibias casi tocandola, espalda neutra y dorsales activos.",
            steps: [
                "Presuriza el abdomen, empuja el piso y despega la barra pegada a las piernas.",
                "Extiende cadera y rodillas a la vez hasta quedar erguido.",
                "Baja haciendo bisagra: cadera atras primero, luego flexiona rodillas."
            ],
            cues: ["Barra siempre pegada al cuerpo", "Costillas abajo, sin hiperextender arriba", "Axilas 'apretando' la barra"],
            mistakes: ["Redondear la lumbar", "Jalar con la espalda antes de mover las piernas", "Hiperextender al terminar"],
            mediaSlug: "Barbell_Deadlift"
        ),
        .init(
            exercise: "Prensa",
            summary: "Empuje de pierna guiado: cuadriceps y gluteo con poca carga axial.",
            setup: "Espalda y cadera pegadas al respaldo, pies a media plataforma.",
            steps: [
                "Baja la plataforma hasta ~90 grados de rodilla sin despegar la cadera.",
                "Empuja hasta casi extender, sin bloquear de golpe."
            ],
            cues: ["Lumbar pegada al respaldo", "Rodillas alineadas con los pies"],
            mistakes: ["Bajar tanto que la cadera se despega", "Bloquear las rodillas con fuerza"],
            mediaSlug: "Leg_Press"
        ),
        .init(
            exercise: "Zancadas",
            summary: "Patron unilateral: cuadriceps, gluteo y estabilidad.",
            setup: "De pie, tronco erguido, mirada al frente.",
            steps: [
                "Da un paso adelante y baja hasta que ambas rodillas queden a ~90 grados.",
                "Empuja con el talon delantero para volver o avanzar al siguiente paso."
            ],
            cues: ["Torso vertical", "Rodilla trasera baja sin golpear el piso"],
            mistakes: ["Paso demasiado corto (rodilla muy adelantada)", "Inclinar el torso al frente"],
            mediaSlug: "Bodyweight_Walking_Lunge"
        ),
        .init(
            exercise: "Desplantes",
            summary: "Zancada en el sitio: fuerza unilateral y control de rodilla.",
            setup: "Pies juntos, abdomen activo.",
            steps: [
                "Da un paso al frente o atras y baja controlado.",
                "Regresa al punto de inicio empujando con la pierna delantera."
            ],
            cues: ["Cadera cuadrada al frente", "Baja recto, no en diagonal"],
            mistakes: ["Perder el equilibrio por pisar en linea", "Dejar caer la rodilla trasera"],
            mediaSlug: "Bodyweight_Walking_Lunge"
        ),
        .init(
            exercise: "Elevacion de talones",
            summary: "Gemelo y soleo: fuerza del tobillo y absorcion de impacto.",
            setup: "Punta de los pies en el escalon, talones libres.",
            steps: [
                "Sube hasta la maxima flexion plantar y sostiene 1 s.",
                "Baja lento hasta estirar el gemelo."
            ],
            cues: ["Pausa arriba", "Rango completo, no rebotes"],
            mistakes: ["Rebotar con el tendon", "Rango corto"],
            mediaSlug: "Standing_Calf_Raises"
        ),
        .init(
            exercise: "Step-ups",
            summary: "Subida a cajon: gluteo, cuadriceps y control unilateral.",
            setup: "Cajon a la altura de la rodilla, un pie completo arriba.",
            steps: [
                "Empuja con el pie de arriba hasta quedar de pie sobre el cajon.",
                "Baja controlado con la misma pierna."
            ],
            cues: ["No impulses con el pie de abajo", "Rodilla alineada con el pie"],
            mistakes: ["Saltar para subir", "Dejarse caer al bajar"],
            mediaSlug: "Step_up_with_Knee_Raise"
        ),

        // MARK: - Hombros
        .init(
            exercise: "Press militar",
            summary: "Empuje vertical: deltoides, triceps y core anti-extension.",
            setup: "De pie, barra en la clavicula, codos ligeramente adelante, gluteos y abdomen apretados.",
            steps: [
                "Empuja la barra vertical pasando la cara (mete un poco la barbilla).",
                "Termina con la barra sobre la mitad de la cabeza y los hombros activos.",
                "Baja controlado a la clavicula."
            ],
            cues: ["Costillas abajo", "Al final la cabeza 'pasa' bajo la barra"],
            mistakes: ["Arquear la lumbar para pasar el peso", "Empujar la barra hacia adelante"],
            mediaSlug: "Standing_Military_Press"
        ),
        .init(
            exercise: "Elevaciones laterales",
            summary: "Aislamiento del deltoides medio.",
            setup: "De pie, mancuernas a los costados, codos casi extendidos.",
            steps: [
                "Sube los brazos a los lados hasta la altura del hombro.",
                "Baja lento, resistiendo."
            ],
            cues: ["Guia con el codo, no con la mano", "Hombros lejos de las orejas"],
            mistakes: ["Impulso de cadera", "Subir por encima del hombro encogiendo el trapecio"],
            mediaSlug: "Side_Lateral_Raise"
        ),
        .init(
            exercise: "Face pull",
            summary: "Deltoides posterior y rotadores externos: salud del hombro.",
            setup: "Polea a la altura de la cara, cuerda con agarre neutro, brazos extendidos.",
            steps: [
                "Jala la cuerda hacia la frente separando las manos.",
                "Termina con codos altos y manos a los lados de la cabeza; regresa controlado."
            ],
            cues: ["Codos por encima de las munecas", "Rota los pulgares hacia atras al final"],
            mistakes: ["Jalar con el trapecio superior", "Usar peso que obliga a inclinar el torso"],
            mediaSlug: "Face_Pull"
        ),

        // MARK: - Brazos
        .init(
            exercise: "Curl de biceps",
            summary: "Flexion de codo: biceps braquial.",
            setup: "De pie, brazos extendidos, palmas al frente, codos pegados al torso.",
            steps: [
                "Flexiona el codo subiendo el peso hasta el hombro.",
                "Baja lento hasta extender por completo."
            ],
            cues: ["El codo no viaja al frente", "Aprieta arriba 1 s"],
            mistakes: ["Balancear el torso", "Rango parcial abajo"],
            mediaSlug: "Dumbbell_Bicep_Curl"
        ),
        .init(
            exercise: "Extension de triceps",
            summary: "Extension de codo con hombro flexionado: cabeza larga del triceps.",
            setup: "Peso sobre la cabeza, codos apuntando al frente y pegados.",
            steps: [
                "Baja el peso detras de la cabeza flexionando solo los codos.",
                "Extiende hasta arriba sin abrir los codos."
            ],
            cues: ["Codos fijos y cerrados", "Abdomen activo para no arquear"],
            mistakes: ["Abrir los codos hacia los lados", "Arquear la lumbar"],
            mediaSlug: "Standing_Overhead_Barbell_Triceps_Extension"
        ),
        .init(
            exercise: "Curl martillo",
            summary: "Curl con agarre neutro: braquial y braquiorradial.",
            setup: "De pie, mancuernas con palmas enfrentadas.",
            steps: [
                "Sube manteniendo el agarre neutro hasta el hombro.",
                "Baja controlado hasta extender."
            ],
            cues: ["Muneca firme y neutra", "Codos quietos"],
            mistakes: ["Rotar la muneca a mitad del recorrido", "Impulso de hombros"],
            mediaSlug: "Hammer_Curls"
        ),

        // MARK: - Core
        .init(
            exercise: "Plancha",
            summary: "Anti-extension: estabilidad de columna con el core.",
            setup: "Antebrazos bajo los hombros, cuerpo en linea recta.",
            steps: [
                "Aprieta gluteos y abdomen y sostiene la posicion respirando.",
                "Manten la cadera a la altura de los hombros todo el tiempo."
            ],
            cues: ["Costillas abajo, pelvis metida", "Empuja el piso con los antebrazos"],
            mistakes: ["Cadera hundida o muy alta", "Aguantar la respiracion"],
            mediaSlug: "Plank"
        ),
        .init(
            exercise: "Crunch",
            summary: "Flexion corta de columna: recto abdominal.",
            setup: "Boca arriba, rodillas flexionadas, manos en el pecho o sienes.",
            steps: [
                "Despega los omoplatos enrollando las costillas hacia la pelvis.",
                "Baja controlado sin soltar la tension."
            ],
            cues: ["Exhala al subir", "Barbilla neutra, sin jalar el cuello"],
            mistakes: ["Jalar la cabeza con las manos", "Subir todo el torso (eso es sit-up)"],
            mediaSlug: "Crunches"
        ),
        .init(
            exercise: "Rueda abdominal",
            summary: "Anti-extension avanzada: recto abdominal y dorsal.",
            setup: "De rodillas, rueda bajo los hombros, pelvis metida.",
            steps: [
                "Rueda al frente todo lo que puedas sin que la lumbar se arquee.",
                "Regresa jalando con el abdomen, no con los brazos."
            ],
            cues: ["Gluteos apretados todo el recorrido", "Rango corto al inicio"],
            mistakes: ["Ir demasiado lejos y arquear la espalda", "Doblar la cadera para hacerlo facil"],
            mediaSlug: "Ab_Roller"
        ),
        .init(
            exercise: "Elevacion de piernas",
            summary: "Flexion de cadera controlada: abdomen inferior.",
            setup: "Colgado de la barra o acostado con la lumbar pegada al piso.",
            steps: [
                "Sube las piernas manteniendo la pelvis metida.",
                "Baja lento sin dejar que la lumbar se despegue o el cuerpo se balancee."
            ],
            cues: ["Empieza metiendo la pelvis", "Sin balanceo"],
            mistakes: ["Usar impulso", "Arquear la lumbar al bajar"],
            mediaSlug: "Hanging_Leg_Raise"
        ),

        // MARK: - Cardio
        .init(
            exercise: "Correr",
            summary: "Cardio de impacto: base aerobica y densidad osea.",
            setup: "Calzado adecuado, 5 min de caminata o trote suave de calentamiento.",
            steps: [
                "Manten una cadencia alta (~170-180 pasos/min) con zancada corta.",
                "Aterriza con el pie bajo la cadera, no muy adelante.",
                "Termina con 5 min de trote suave o caminata."
            ],
            cues: ["Hombros relajados", "Respiracion que permita hablar en ritmo facil"],
            mistakes: ["Subir volumen mas de ~10% por semana", "Zancada larga con talon adelantado"],
            mediaSlug: "Running_Treadmill"
        ),
        .init(
            exercise: "Caminata",
            summary: "Cardio de bajo impacto: recuperacion activa y base aerobica.",
            setup: "Ritmo comodo, postura erguida.",
            steps: ["Camina a paso constante con braceo natural.", "Sube el ritmo si quieres estimulo aerobico real."],
            cues: ["Pisada completa talon-punta", "Mirada al frente"],
            mistakes: ["Ritmo tan bajo que no genera estimulo cuando ese es el objetivo"],
            mediaSlug: "Walking_Treadmill"
        ),
        .init(
            exercise: "Ciclismo",
            summary: "Cardio sin impacto: gran volumen aerobico con poco dano muscular.",
            setup: "Sillin a la altura de la cadera; la rodilla queda casi extendida abajo.",
            steps: ["Pedalea a cadencia 80-95 rpm.", "Ajusta resistencia para mantener el ritmo objetivo."],
            cues: ["Rodillas apuntando al frente", "Espalda larga, sin encogerse"],
            mistakes: ["Sillin muy bajo (dolor de rodilla)", "Cadencia muy lenta con mucha carga"],
            mediaSlug: "Bicycling"
        ),
        .init(
            exercise: "Natacion",
            summary: "Cardio sin impacto con demanda de tren superior.",
            setup: "Calentamiento de hombros y 100-200 m suaves.",
            steps: ["Nada por series con descansos cortos.", "Cuida el patron respiratorio bilateral."],
            cues: ["Cuerpo alineado y horizontal", "Rotacion desde la cadera"],
            mistakes: ["Cabeza muy alta (hunde las piernas)", "Bracear sin ritmo respiratorio"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Futbol",
            summary: "Cardio intermitente: aerobico + esprints y cambios de direccion.",
            setup: "Calentamiento con movilidad de cadera y tobillo, y aceleraciones progresivas.",
            steps: ["Juega o entrena por bloques.", "Termina con trote suave y movilidad."],
            cues: ["Calienta antes de esprintar", "Hidratacion entre bloques"],
            mistakes: ["Entrar en frio a esprints (riesgo de isquios)", "Sumarlo a un dia de piernas pesado"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Basquetbol",
            summary: "Cardio intermitente con saltos y cambios de direccion.",
            setup: "Calentamiento de tobillo, rodilla y saltos suaves.",
            steps: ["Juega por cuartos o bloques.", "Cierra con movilidad de cadera y tobillo."],
            cues: ["Aterriza con rodilla flexionada", "Pies activos"],
            mistakes: ["Ignorar la carga de saltos acumulada", "No calentar tobillos"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Tenis",
            summary: "Cardio intermitente con rotacion y desplazamientos laterales.",
            setup: "Movilidad toracica y de cadera antes de jugar.",
            steps: ["Pelotea para calentar.", "Juega puntos o sets."],
            cues: ["Rota desde el torso, no solo el brazo", "Pasos cortos de ajuste"],
            mistakes: ["Golpear fuerte sin calentar el hombro"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Remo",
            summary: "Cardio de cuerpo completo con bajo impacto.",
            setup: "Correas ajustadas, agarre relajado, espalda neutra.",
            steps: [
                "Empuja con las piernas primero.",
                "Luego abre la cadera y al final jala con los brazos.",
                "Regresa en orden inverso: brazos, cadera, piernas."
            ],
            cues: ["60% piernas, 20% cadera, 20% brazos", "Ritmo de 22-26 paladas/min en aerobico"],
            mistakes: ["Jalar con los brazos primero", "Redondear la espalda al final"],
            mediaSlug: "Rowing_Stationary"
        ),
        .init(
            exercise: "HIIT",
            summary: "Intervalos de alta intensidad: mejora rapida del VO2max.",
            setup: "10 min de calentamiento progresivo obligatorio.",
            steps: [
                "Alterna esfuerzos duros (20 s a 4 min) con recuperaciones activas.",
                "Manten la calidad: si el ritmo cae mucho, termina la sesion.",
                "Enfria 5-10 min."
            ],
            cues: ["Maximo 1-2 sesiones duras por semana", "Recuperacion completa entre intervalos"],
            mistakes: ["Hacerlo a diario", "Encadenarlo con fuerza pesada el mismo dia"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Saltar la cuerda",
            summary: "Cardio de impacto ligero: coordinacion y rigidez del tobillo.",
            setup: "Cuerda a la altura de las axilas al pisarla, codos pegados.",
            steps: ["Salta ~2 cm con los pies juntos.", "Gira la cuerda con las munecas, no con los brazos."],
            cues: ["Aterriza en el metatarso", "Rodillas suaves"],
            mistakes: ["Saltar muy alto", "Girar con los hombros"],
            mediaSlug: "Rope_Jumping"
        ),
        .init(
            exercise: "Otro",
            summary: "Cualquier actividad cardiovascular que registres por tiempo.",
            setup: "Calentamiento progresivo de 5-10 min.",
            steps: ["Mantén una intensidad sostenible.", "Cierra con 5 min suaves."],
            cues: ["Registra minutos y percepcion de esfuerzo"],
            mistakes: ["Empezar al maximo sin calentar"],
            mediaSlug: nil
        ),

        // MARK: - Movilidad
        .init(
            exercise: "Gato-vaca",
            summary: "Movilidad segmentaria de columna, ideal para empezar el dia.",
            setup: "Cuadrupedia: manos bajo hombros, rodillas bajo cadera.",
            steps: [
                "Inhala y arquea suavemente la espalda llevando el pecho al frente.",
                "Exhala y redondea la columna metiendo la pelvis."
            ],
            cues: ["Mueve vertebra por vertebra", "Sin forzar los extremos"],
            mistakes: ["Ir rapido", "Forzar el cuello hacia atras"],
            mediaSlug: "Cat_Stretch"
        ),
        .init(
            exercise: "Rotacion toracica",
            summary: "Movilidad de la espalda alta: clave para press y sentadilla.",
            setup: "Cuadrupedia o de lado, una mano en la nuca.",
            steps: ["Abre el codo hacia el techo rotando el torso.", "Regresa lento y repite."],
            cues: ["El giro nace del torso, no de la lumbar", "Exhala al abrir"],
            mistakes: ["Rotar desde la cadera", "Movimiento brusco"],
            mediaSlug: "Spinal_Stretch"
        ),
        .init(
            exercise: "Estiramiento suave de cadera",
            summary: "Libera flexores de cadera tras horas sentado.",
            setup: "Rodilla en el piso, pie contrario adelante en 90 grados.",
            steps: ["Mete la pelvis y avanza ligeramente la cadera.", "Sostiene 30 s por lado respirando."],
            cues: ["Gluteo del lado estirado activo", "Sin arquear la lumbar"],
            mistakes: ["Buscar el estiramiento arqueando la espalda"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Movilidad de cadera 90/90",
            summary: "Rotacion interna y externa de cadera.",
            setup: "Sentado con una pierna al frente a 90 grados y la otra al lado a 90 grados.",
            steps: ["Gira el torso hacia la pierna delantera.", "Cambia de lado rotando las rodillas al piso."],
            cues: ["Torso erguido", "Movimiento lento y controlado"],
            mistakes: ["Redondear la espalda para llegar mas lejos"],
            mediaSlug: "Groin_and_Back_Stretch"
        ),
        .init(
            exercise: "Estiramiento de isquios",
            summary: "Movilidad de la cadena posterior.",
            setup: "Sentado o de pie con una pierna extendida.",
            steps: ["Haz bisagra de cadera hacia la pierna extendida.", "Sostiene 30 s por lado."],
            cues: ["Espalda larga", "Estira sin dolor agudo"],
            mistakes: ["Redondear la espalda en vez de hacer bisagra", "Rebotar"],
            mediaSlug: "Seated_Floor_Hamstring_Stretch"
        ),
        .init(
            exercise: "Rotacion de tobillo",
            summary: "Movilidad de tobillo: base de sentadilla y carrera.",
            setup: "Sentado o de pie con un pie despegado.",
            steps: ["Dibuja circulos amplios con el pie en ambos sentidos.", "10-15 por direccion."],
            cues: ["Rango completo, sin dolor"],
            mistakes: ["Circulos minimos y rapidos"],
            mediaSlug: "Ankle_Circles"
        ),
        .init(
            exercise: "Aperturas de pecho en puerta",
            summary: "Estira pectoral: compensa la postura adelantada.",
            setup: "Antebrazo apoyado en el marco, codo a la altura del hombro.",
            steps: ["Gira el cuerpo alejandote del brazo.", "Sostiene 30 s por lado."],
            cues: ["Costillas abajo", "Sensacion en el pecho, no en el hombro"],
            mistakes: ["Codo demasiado alto (pinza el hombro)"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Circulos de hombro",
            summary: "Calentamiento articular del hombro.",
            setup: "De pie, brazos relajados.",
            steps: ["Dibuja circulos hacia atras, cada vez mas amplios.", "Invierte la direccion."],
            cues: ["Hombros lejos de las orejas"],
            mistakes: ["Encoger el trapecio"],
            mediaSlug: "Arm_Circles"
        ),
        .init(
            exercise: "Movilidad de hombro con banda",
            summary: "Rango de hombro asistido con banda.",
            setup: "Banda con agarre amplio, brazos extendidos al frente.",
            steps: ["Lleva la banda por encima de la cabeza hacia atras.", "Regresa por el mismo camino."],
            cues: ["Agarre lo bastante amplio para no forzar", "Codos extendidos"],
            mistakes: ["Agarre corto que obliga a doblar codos y arquear"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Estiramiento cruzado de hombro",
            summary: "Estira deltoides posterior y capsula del hombro.",
            setup: "Brazo cruzado al frente a la altura del pecho.",
            steps: ["Presiona el brazo con la mano contraria.", "Sostiene 30 s por lado."],
            cues: ["Hombro abajo", "Sin girar el torso"],
            mistakes: ["Tirar del codo con fuerza"],
            mediaSlug: "Shoulder_Stretch"
        ),
        .init(
            exercise: "Rotaciones externas suaves",
            summary: "Activacion del manguito rotador.",
            setup: "Codo pegado al costado a 90 grados, banda ligera.",
            steps: ["Rota el antebrazo hacia afuera sin despegar el codo.", "Regresa lento."],
            cues: ["Codo fijo al costado", "Poca carga, mucho control"],
            mistakes: ["Despegar el codo", "Usar banda muy dura"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Respiracion diafragmatica",
            summary: "Baja la activacion simpatica y ayuda a la recuperacion.",
            setup: "Acostado o sentado, una mano en el pecho y otra en el abdomen.",
            steps: [
                "Inhala 4 s por la nariz llevando el aire al abdomen.",
                "Exhala 6-8 s lento por la boca.",
                "Repite 5-10 ciclos."
            ],
            cues: ["Solo se mueve la mano del abdomen", "Exhalacion mas larga que la inhalacion"],
            mistakes: ["Respirar con el pecho", "Forzar la inhalacion"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Postura del nino",
            summary: "Descarga lumbar y relaja la respiracion.",
            setup: "De rodillas, gluteos hacia los talones, brazos extendidos al frente.",
            steps: ["Relaja el torso sobre los muslos.", "Respira profundo 30-60 s."],
            cues: ["Rodillas abiertas si molesta la cadera", "Frente apoyada"],
            mistakes: ["Tensar los hombros"],
            mediaSlug: "Childs_Pose"
        ),
        .init(
            exercise: "Perro boca abajo",
            summary: "Estira cadena posterior y abre hombros.",
            setup: "Desde plancha alta, eleva la cadera formando una V invertida.",
            steps: ["Empuja el piso con las manos alargando la espalda.", "Pedalea los talones hacia el piso."],
            cues: ["Espalda larga antes que rodillas extendidas", "Puedes flexionar rodillas"],
            mistakes: ["Redondear la espalda por forzar las piernas rectas"],
            mediaSlug: "Downward_Facing_Balance"
        ),
        .init(
            exercise: "Cobra",
            summary: "Extension suave de columna: contrarresta estar sentado.",
            setup: "Boca abajo, manos bajo los hombros, codos pegados.",
            steps: ["Despega el pecho empujando suave con las manos.", "Sostiene 20-30 s respirando."],
            cues: ["Gluteos relajados", "Cuello largo, sin echar la cabeza atras"],
            mistakes: ["Empujar hasta sentir pinzamiento lumbar"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Paloma",
            summary: "Estiramiento profundo de gluteo y rotadores de cadera.",
            setup: "Una pierna doblada al frente, la otra extendida atras.",
            steps: ["Baja el torso sobre la pierna delantera.", "Sostiene 45-60 s por lado."],
            cues: ["Cadera cuadrada", "Apoya con cojin si molesta la rodilla"],
            mistakes: ["Cargar la rodilla delantera en torsion"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Guerrero II",
            summary: "Fuerza isometrica de piernas con apertura de cadera.",
            setup: "Pies separados, pie delantero al frente y trasero a 90 grados.",
            steps: ["Flexiona la rodilla delantera sobre el tobillo.", "Extiende los brazos y sostiene 30-45 s."],
            cues: ["Rodilla alineada con el segundo dedo", "Torso centrado"],
            mistakes: ["Rodilla colapsando hacia dentro", "Inclinar el torso al frente"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Puente de gluteos",
            summary: "Activacion de gluteo y extension de cadera.",
            setup: "Boca arriba, rodillas flexionadas, pies bajo las rodillas.",
            steps: ["Mete la pelvis y sube la cadera apretando gluteos.", "Baja controlado sin descansar del todo."],
            cues: ["El movimiento es de cadera, no de lumbar", "Pausa 1-2 s arriba"],
            mistakes: ["Arquear la lumbar para subir mas", "Empujar con las puntas de los pies"],
            mediaSlug: "Single_Leg_Glute_Bridge"
        ),
        .init(
            exercise: "Torsion espinal acostado",
            summary: "Relaja la espalda baja y la cadena lateral.",
            setup: "Boca arriba, brazos en cruz, rodillas flexionadas.",
            steps: ["Deja caer las rodillas a un lado.", "Sostiene 30-45 s y cambia de lado."],
            cues: ["Ambos omoplatos en el piso", "Respira hacia el costado que se estira"],
            mistakes: ["Forzar hasta despegar el hombro"],
            mediaSlug: "Spinal_Stretch"
        ),
        .init(
            exercise: "Estiramiento de cuadriceps",
            summary: "Libera el cuadriceps y el flexor de cadera.",
            setup: "De pie, sostente de algo, toma el tobillo por detras.",
            steps: ["Lleva el talon al gluteo con la pelvis metida.", "Sostiene 30 s por lado."],
            cues: ["Rodillas juntas", "Pelvis metida"],
            mistakes: ["Arquear la lumbar", "Jalar la rodilla hacia atras"],
            mediaSlug: "Quad_Stretch"
        ),
        .init(
            exercise: "Sentadilla profunda sostenida",
            summary: "Movilidad de cadera, rodilla y tobillo en posicion profunda.",
            setup: "Pies a la anchura de hombros, baja hasta el fondo.",
            steps: ["Sostiene abajo 30-60 s con los codos empujando las rodillas.", "Respira y busca torso erguido."],
            cues: ["Talones en el piso (o eleva con un disco)", "Pecho arriba"],
            mistakes: ["Colapsar la espalda", "Aguantar la respiracion"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Estiramiento de gemelos",
            summary: "Movilidad de tobillo: mejora sentadilla y carrera.",
            setup: "Manos en la pared, una pierna atras extendida.",
            steps: ["Empuja el talon trasero al piso.", "Sostiene 30 s y repite con rodilla flexionada."],
            cues: ["Pie trasero apuntando al frente", "Dos versiones: rodilla recta y flexionada"],
            mistakes: ["Despegar el talon"],
            mediaSlug: "Calf_Stretch_Elbows_Against_Wall"
        ),
        .init(
            exercise: "Flexion lateral de pie",
            summary: "Abre la cadena lateral y el cuadrado lumbar.",
            setup: "De pie, un brazo arriba.",
            steps: ["Inclinate al lado contrario formando un arco.", "Sostiene 20-30 s por lado."],
            cues: ["Sin rotar el torso", "Alarga antes de inclinar"],
            mistakes: ["Doblarse hacia adelante"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Postura del triangulo",
            summary: "Estira isquios y costado con control de cadera.",
            setup: "Pies separados, pie delantero al frente.",
            steps: ["Haz bisagra lateral y baja la mano hacia la espinilla.", "Sostiene 30 s por lado."],
            cues: ["Espalda larga", "Pecho abierto al lado"],
            mistakes: ["Redondear la espalda para tocar el piso"],
            mediaSlug: nil
        ),

        // MARK: - Challenge (McGill / bandas / pilates / calistenia / yoga de fuerza)
        .init(
            exercise: "Bird-dog",
            summary: "Anti-rotacion: estabilidad lumbar (McGill Big 3).",
            setup: "Cuadrupedia, columna neutra, abdomen firme.",
            steps: [
                "Extiende brazo y pierna opuestos hasta la linea del cuerpo.",
                "Sostiene 6-8 s y regresa sin dejar caer la cadera.",
                "Alterna lados."
            ],
            cues: ["La cadera no se inclina", "Talon empujando hacia atras"],
            mistakes: ["Subir la pierna por encima de la cadera", "Rotar la pelvis"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Curl-up McGill",
            summary: "Flexion abdominal sin cargar la columna (McGill Big 3).",
            setup: "Boca arriba, una rodilla flexionada, manos bajo la lumbar.",
            steps: [
                "Despega ligeramente cabeza y hombros manteniendo la lumbar apoyada en las manos.",
                "Sostiene 8-10 s y baja."
            ],
            cues: ["La lumbar NO se aplana contra el piso", "Movimiento minimo"],
            mistakes: ["Hacer un crunch completo", "Jalar el cuello"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Plancha lateral",
            summary: "Anti-flexion lateral: oblicuos y cuadrado lumbar (McGill Big 3).",
            setup: "De lado, antebrazo bajo el hombro, rodillas o pies apoyados.",
            steps: ["Sube la cadera hasta alinear cuerpo.", "Sostiene 20-45 s por lado."],
            cues: ["Cadera alta y estable", "Hombro lejos de la oreja"],
            mistakes: ["Rotar el torso al frente", "Dejar caer la cadera"],
            mediaSlug: "Side_Bridge"
        ),
        .init(
            exercise: "Dead bug",
            summary: "Anti-extension con movimiento de extremidades.",
            setup: "Boca arriba, brazos al techo, caderas y rodillas a 90 grados.",
            steps: [
                "Baja brazo y pierna opuestos manteniendo la lumbar pegada al piso.",
                "Regresa y alterna."
            ],
            cues: ["Exhala al extender", "Si la lumbar se despega, reduce el rango"],
            mistakes: ["Perder el contacto lumbar", "Ir rapido"],
            mediaSlug: "Dead_Bug"
        ),
        .init(
            exercise: "Abdominales de pie",
            summary: "Core de pie: util cuando molesta el suelo o hay poco espacio.",
            setup: "De pie, pies a la anchura de cadera, manos en la nuca o al frente.",
            steps: ["Lleva la rodilla al codo contrario acortando el costado.", "Alterna con ritmo controlado."],
            cues: ["Exhala en cada repeticion", "Aprieta el abdomen, no solo mueve la pierna"],
            mistakes: ["Balancear sin tension abdominal"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Marcha con rodilla alta",
            summary: "Activacion cardio-core de bajo impacto.",
            setup: "De pie, torso erguido.",
            steps: ["Sube alternadamente las rodillas a la altura de la cadera.", "Bracea de forma coordinada."],
            cues: ["Torso quieto", "Apoyo suave"],
            mistakes: ["Inclinarse atras para subir mas la rodilla"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Pasos",
            summary: "Volumen diario de movimiento: la base del gasto energetico.",
            setup: "Calzado comodo.",
            steps: ["Acumula los pasos en bloques a lo largo del dia.", "Un bloque de 10-15 min ya cuenta."],
            cues: ["Constancia mas que intensidad"],
            mistakes: ["Dejar todo para el final del dia"],
            mediaSlug: "Walking_Treadmill"
        ),
        .init(
            exercise: "Sentadilla en pared",
            summary: "Isometrico de cuadriceps, amable con la rodilla.",
            setup: "Espalda contra la pared, pies adelantados, rodillas a 90 grados.",
            steps: ["Sostiene la posicion respirando.", "20-60 s por serie."],
            cues: ["Peso en los talones", "Espalda completa en la pared"],
            mistakes: ["Rodillas por delante de las puntas", "Aguantar la respiracion"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Remo con banda",
            summary: "Jalon horizontal con banda: postura y espalda alta.",
            setup: "Banda anclada al frente a la altura del pecho, brazos extendidos.",
            steps: ["Jala llevando los codos atras y juntando escapulas.", "Regresa controlado."],
            cues: ["Hombros abajo", "Torso quieto"],
            mistakes: ["Encoger los hombros", "Usar el torso como palanca"],
            mediaSlug: "Band_Pull_Apart"
        ),
        .init(
            exercise: "Paseo del monstruo",
            summary: "Fortalece gluteo medio: clave para cadera y rodilla.",
            setup: "Banda alrededor de las rodillas o tobillos, media sentadilla.",
            steps: ["Camina lateral y al frente manteniendo tension en la banda.", "10-15 pasos por direccion."],
            cues: ["Rodillas siempre separadas", "Torso estable"],
            mistakes: ["Juntar las rodillas al pisar", "Balancear el torso"],
            mediaSlug: "Monster_Walk"
        ),
        .init(
            exercise: "Almeja con banda",
            summary: "Aislamiento de gluteo medio y rotadores de cadera.",
            setup: "De lado, rodillas flexionadas, banda arriba de las rodillas.",
            steps: ["Abre la rodilla de arriba sin rotar la pelvis.", "Baja lento."],
            cues: ["Pelvis quieta", "Sensacion en el lateral del gluteo"],
            mistakes: ["Rodar la cadera hacia atras para abrir mas"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Empuje de cadera con banda",
            summary: "Extension de cadera con resistencia: gluteo mayor.",
            setup: "Boca arriba o con la espalda en un banco, banda sobre la cadera.",
            steps: ["Sube la cadera hasta alinear torso y muslos.", "Aprieta 1-2 s y baja."],
            cues: ["Costillas abajo", "Mira al frente, no al techo"],
            mistakes: ["Hiperextender la lumbar", "Rango corto"],
            mediaSlug: "Butt_Lift_Bridge"
        ),
        .init(
            exercise: "El cien",
            summary: "Clasico de Pilates: resistencia abdominal y respiracion.",
            setup: "Boca arriba, piernas en mesa (90/90), cabeza y hombros elevados.",
            steps: [
                "Bombea los brazos a los lados con ritmo.",
                "Inhala 5 bombeos, exhala 5; repite 10 ciclos."
            ],
            cues: ["Lumbar estable", "Cuello relajado"],
            mistakes: ["Tensar el cuello", "Perder el ritmo respiratorio"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Roll-up",
            summary: "Control articular de columna con abdomen.",
            setup: "Boca arriba, brazos extendidos por encima de la cabeza.",
            steps: ["Enrolla la columna vertebra por vertebra hasta sentarte.", "Baja igual de lento."],
            cues: ["Sin impulso", "Exhala al subir"],
            mistakes: ["Lanzar los brazos para subir", "Dejarse caer al bajar"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Teaser",
            summary: "Pilates avanzado: fuerza abdominal y equilibrio.",
            setup: "Boca arriba, piernas extendidas y brazos arriba.",
            steps: ["Sube torso y piernas al mismo tiempo formando una V.", "Sostiene 2-3 s y baja controlado."],
            cues: ["Espalda larga en la V", "Empieza con rodillas flexionadas si es necesario"],
            mistakes: ["Redondear en exceso la lumbar", "Usar impulso"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Nado boca abajo",
            summary: "Fortalece extensores de espalda y gluteos.",
            setup: "Boca abajo, brazos extendidos al frente.",
            steps: ["Despega brazos y piernas opuestos alternando rapido y corto.", "20-40 s por serie."],
            cues: ["Cuello largo, mirada al piso", "Movimiento pequeno"],
            mistakes: ["Extender el cuello hacia atras", "Rango exagerado"],
            mediaSlug: "Superman"
        ),
        .init(
            exercise: "Patada lateral",
            summary: "Control de cadera y gluteo medio (Pilates).",
            setup: "De lado, cuerpo alineado, cabeza apoyada.",
            steps: ["Lleva la pierna de arriba al frente y luego atras con control.", "8-12 por lado."],
            cues: ["Pelvis inmovil", "Rango que puedas controlar"],
            mistakes: ["Balancear la pelvis con la pierna"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Circulos de pierna",
            summary: "Movilidad y control de la articulacion de la cadera.",
            setup: "Boca arriba, una pierna extendida al techo.",
            steps: ["Dibuja circulos controlados con la pierna.", "5-8 por direccion y cambia."],
            cues: ["Pelvis pegada al piso", "Circulos pequenos al inicio"],
            mistakes: ["Dejar que la cadera se despegue"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Puente de hombros",
            summary: "Extension de cadera y movilidad de columna (Pilates).",
            setup: "Boca arriba, rodillas flexionadas, pies bajo las rodillas.",
            steps: ["Sube la cadera enrollando la columna vertebra por vertebra.", "Baja en el mismo orden inverso."],
            cues: ["Enrolla, no levantes en bloque", "Gluteos activos arriba"],
            mistakes: ["Arquear la lumbar", "Empujar con las puntas"],
            mediaSlug: "Butt_Lift_Bridge"
        ),
        .init(
            exercise: "Hollow hold",
            summary: "Isometrico anti-extension: base de la calistenia.",
            setup: "Boca arriba, lumbar pegada al piso, brazos y piernas extendidos.",
            steps: ["Despega hombros y piernas manteniendo la lumbar pegada.", "Sostiene 15-40 s."],
            cues: ["Costillas abajo", "Si la lumbar se despega, sube las piernas"],
            mistakes: ["Arquear la espalda", "Contener la respiracion"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Superman",
            summary: "Extensores de espalda y gluteos con peso corporal.",
            setup: "Boca abajo, brazos extendidos al frente.",
            steps: ["Despega pecho, brazos y piernas a la vez.", "Sostiene 2 s y baja."],
            cues: ["Mirada al piso", "Aprieta gluteos"],
            mistakes: ["Extender el cuello", "Rebotar"],
            mediaSlug: "Superman"
        ),
        .init(
            exercise: "Escaladores",
            summary: "Cardio-core: plancha dinamica.",
            setup: "Plancha alta, manos bajo los hombros.",
            steps: ["Lleva las rodillas al pecho alternando rapido.", "20-40 s por serie."],
            cues: ["Cadera baja y estable", "Hombros sobre las manos"],
            mistakes: ["Subir la cadera", "Rebotar los pies"],
            mediaSlug: "Mountain_Climbers"
        ),
        .init(
            exercise: "Burpees",
            summary: "Cuerpo completo: fuerza-resistencia y pulso alto.",
            setup: "De pie, espacio libre alrededor.",
            steps: [
                "Baja a cuclillas y coloca las manos en el piso.",
                "Salta o camina los pies atras a plancha (opcional: flexion).",
                "Regresa los pies y salta arriba."
            ],
            cues: ["Cadera y hombros alineados en la plancha", "Aterriza suave"],
            mistakes: ["Cadera hundida en la plancha", "Aterrizar con rodillas rigidas"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Sentadilla con salto",
            summary: "Potencia de tren inferior.",
            setup: "Pies a la anchura de hombros.",
            steps: ["Baja a media sentadilla y salta con maxima intencion.", "Aterriza suave y encadena."],
            cues: ["Aterriza con rodillas flexionadas", "Calidad sobre cantidad"],
            mistakes: ["Muchas repeticiones con tecnica pobre", "Aterrizar rigido"],
            mediaSlug: "Freehand_Jump_Squat"
        ),
        .init(
            exercise: "Flexion pike",
            summary: "Empuje vertical con peso corporal: progresa al pino.",
            setup: "V invertida con cadera alta, manos bajo los hombros.",
            steps: ["Baja la coronilla hacia el piso entre las manos.", "Empuja hasta extender."],
            cues: ["Codos a 45 grados", "Cadera alta todo el recorrido"],
            mistakes: ["Convertirlo en flexion normal bajando la cadera"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Remo invertido",
            summary: "Jalon horizontal con peso corporal: alternativa a dominadas.",
            setup: "Barra a la altura de la cadera, cuerpo recto bajo ella.",
            steps: ["Jala el pecho a la barra juntando escapulas.", "Baja controlado hasta extender."],
            cues: ["Cuerpo en tabla", "Cuanto mas horizontal, mas dificil"],
            mistakes: ["Cadera hundida", "Rango parcial"],
            mediaSlug: "Inverted_Row"
        ),
        .init(
            exercise: "Fondos en banca",
            summary: "Triceps con peso corporal, accesible en casa.",
            setup: "Manos en el borde de la banca, pies al frente.",
            steps: ["Baja flexionando codos hacia atras.", "Empuja hasta extender."],
            cues: ["Codos hacia atras, no afuera", "Baja solo lo que el hombro tolere"],
            mistakes: ["Bajar demasiado y forzar el hombro", "Alejarse mucho de la banca"],
            mediaSlug: "Bench_Dips"
        ),
        .init(
            exercise: "Plancha alta",
            summary: "Anti-extension con manos extendidas: core y hombro.",
            setup: "Manos bajo los hombros, cuerpo alineado.",
            steps: ["Aprieta gluteos y abdomen y sostiene respirando.", "20-60 s."],
            cues: ["Empuja el piso separando escapulas", "Pelvis metida"],
            mistakes: ["Cadera hundida", "Bloquear la respiracion"],
            mediaSlug: "Plank"
        ),
        .init(
            exercise: "Postura de la silla",
            summary: "Isometrico de cuadriceps y core (yoga de fuerza).",
            setup: "Pies juntos o a la anchura de cadera, brazos arriba.",
            steps: ["Flexiona rodillas llevando la cadera atras.", "Sostiene 30-45 s."],
            cues: ["Peso en talones", "Costillas abajo"],
            mistakes: ["Arquear la lumbar", "Rodillas muy adelantadas"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Postura del barco",
            summary: "Isometrico abdominal y flexores de cadera.",
            setup: "Sentado, torso inclinado atras, piernas elevadas.",
            steps: ["Forma una V manteniendo la espalda larga.", "Sostiene 20-40 s."],
            cues: ["Pecho arriba", "Flexiona rodillas si la espalda se redondea"],
            mistakes: ["Redondear la lumbar", "Contener la respiracion"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Guerrero III",
            summary: "Equilibrio unilateral: gluteo, isquios y core.",
            setup: "De pie en una pierna, torso empezando a inclinarse.",
            steps: ["Inclina el torso y extiende la pierna libre atras hasta formar una T.", "Sostiene 20-30 s por lado."],
            cues: ["Cadera cuadrada al piso", "Mirada abajo para estabilizar"],
            mistakes: ["Abrir la cadera de la pierna elevada", "Redondear la espalda"],
            mediaSlug: nil
        ),
        .init(
            exercise: "Plancha lateral con elevacion",
            summary: "Plancha lateral dinamica: oblicuos y gluteo medio.",
            setup: "Plancha lateral estable sobre antebrazo.",
            steps: ["Baja la cadera unos centimetros y vuelve a subir.", "8-12 repeticiones por lado."],
            cues: ["Movimiento pequeno y controlado", "Cuerpo en un plano"],
            mistakes: ["Rotar el torso", "Dejar caer la cadera al piso"],
            mediaSlug: "Side_Bridge"
        )
    ]
}
