# Propiedad intelectual de Karta

**Normas verificadas al 24 de octubre de 2026** en fuentes primarias: Función Pública, la Corte Constitucional, la DNDA, la Comunidad Andina y la Universidad de Cartagena.

Las notas de vigencia de Función Pública sobre la Ley 23 de 1982 están desactualizadas. Por eso se contrastaron con las sentencias y con la DNDA. Esto es investigación jurídica, no asesoría legal profesional.

## Resumen

| Tema | Conclusión | Qué hacer |
|---|---|---|
| ¿Quién es el autor de Karta? | Camilo Andres Maestre Iglesias: la ley protege la forma (código y documentos), no la idea | Registrar el software ante la DNDA (gratis) |
| La universidad | Su estatuto reclama en la letra las obras hechas «en desarrollo de compromisos académicos», pero sin un acto escrito del autor esa reclamación es débil | Pedir al Comité de Propiedad Intelectual que reconozca que no es titular |
| Código escrito con IA | Solo una persona natural es autora. Lo que genera la IA sin aporte creativo humano no se protege | Declararlo con honestidad en el registro; conservar la evidencia del aporte propio |
| Contribuciones de otros | Son de sus autores; se usan con licencia | [Acuerdo de contribución](acuerdo-de-contribucion.md) v1.0 |
| José Herrera Gómez | Coautor de los textos del curso que haya redactado, no del código | Que acepte el acuerdo por esos aportes |
| Primera versión (abril de 2026) | De otro curso (2026-1); hoy queda el **1,1 %** del código (155 de ~14.000 líneas) | Nada urgente; reemplazar esas líneas si algún día importa |
| Marca «Karta» | Registrable; el registro internacional de Grab «Karta» no designa a Colombia | Buscar antecedentes en SIPI antes de lanzar y radicar en las clases 9, 39 y 42 |

## 1. Qué protege la ley

**El software es una obra literaria**, tanto el código fuente como el objeto, junto con su documentación técnica y sus manuales. Normas:
- Decisión Andina 351 de 1993, arts. 3, 4 y 23;
- Ley 23 de 1982, art. 2;
- Decreto 1066 de 2015, arts. 2.6.1.3.1 y siguientes, que compila el Decreto 1360 de 1989.

**Las ideas no se protegen**, solo su forma de expresión (Decisión 351, art. 7; Ley 23, art. 6). Por eso no decide nada que la idea de Karta sea anterior al curso. Lo que cuenta es quién escribió el código y los documentos, y bajo qué relación jurídica.

**Dos clases de derechos:**
- **Derechos morales** (paternidad, integridad, retracto): perpetuos e irrenunciables (Ley 23, art. 30).
- **Derechos patrimoniales:** se pueden licenciar o transferir y duran toda la vida del autor más 80 años (Ley 23, art. 21).

## 2. La Universidad de Cartagena

El **Estatuto de Propiedad Intelectual** es el Acuerdo 03 del 29 de junio de 2012 del Consejo Superior. Sigue vigente: la Política de Investigación de 2021 lo cita y no hay ningún acuerdo posterior que lo modifique.

**Lo que dice el Estatuto:**
- **Art. 22, num. 1:** la Universidad es dueña de los derechos patrimoniales de las obras de estudiantes «elaboradas… en desarrollo de sus compromisos académicos con la institución». Karta, entregado como proyecto de aula, encaja en esa letra.
- **Art. 24, num. 3:** excluye las obras hechas «por fuera de sus funciones y responsabilidades con la institución» sin usar sus instalaciones ni recursos.
- **Art. 9:** en caso de duda se aplica «la norma más favorable al autor».
- **Art. 25:** la Universidad «en ningún caso podrá ceder» derechos patrimoniales al autor. Por eso no se le pide una cesión, sino un reconocimiento de que no es titular.

**Por qué la reclamación de la Universidad es débil:**
- **No hay acto escrito.** La transferencia de derechos patrimoniales exige un escrito que identifique las obras, las modalidades, el plazo y el territorio (Ley 23, art. 183, en el texto del art. 181 de la Ley 1955 de 2019, declarado exequible en las sentencias C-157 de 2021 y C-077 de 2023; Decisión 351, art. 31). Un reglamento general no lo reemplaza.
- **No vale la cesión general de obras futuras.** El mismo art. 183 declara ineficaz la cesión «de modo general o indeterminable» de la producción futura.
- **No hay contrato.** Un estudiante no tiene con la Universidad contrato de servicios ni de trabajo, que es lo que activaría la presunción de obra por encargo (Ley 23, art. 20, texto de la Ley 1450 de 2011).
- **La DNDA lo dice expresamente:** el estudiante es el titular, y la institución solo lo es si él declara «previa y expresamente» su voluntad de transferir (Circular 06 de 2002, «El derecho de autor en el ámbito universitario»; Circular 026 de 2023).
- **Tampoco hay financiación.** No hay proyecto de investigación ni convenio financiado, que es el único caso de cesión legal a la entidad (Ley 1955 de 2019, art. 169, en el texto de la Ley 2294 de 2023).

**Sobre la docente:** orientar o corregir no la hace coautora, porque aporta ideas y no expresión (Circular DNDA 06 de 2002, sección III).

**Conclusión:** el riesgo de que la Universidad sea titular es **bajo**. Que la letra del art. 22 genere dudas frente a un inversionista o una entidad compradora **no es imposible**.

**Paso para despejar la duda:** solicitar por escrito al Comité de Propiedad Intelectual (art. 42, nums. 3 y 6 del Estatuto) un concepto que reconozca:
- que Camilo es el titular de los derechos patrimoniales;
- que no ha habido ningún acto de transferencia.

La carta está redactada aparte, lista para firmar y radicar. Antes de enviarla conviene registrar el software en la DNDA, porque eso da fecha cierta.

## 3. Código escrito con inteligencia artificial

Una parte importante del código de Karta se escribió con un asistente de IA (Claude), bajo la dirección de Camilo. Los commits lo dicen con el trailer `Co-Authored-By`: 38 de 64.

Para la DNDA, la condición de autor «sólo puede ser reconocida en cabeza de las personas naturales… excluyéndose de dicha protección las inteligencias artificiales» (Concepto rad. 1-2024-14722, marzo de 2024). Lo que tiene esto en consecuencia:

- **Se protege el aporte creativo humano:**
  - la concepción del producto y las decisiones de diseño y de arquitectura;
  - la selección, la revisión y la corrección del código;
  - los textos y las especificaciones;
  - las pruebas en el teléfono y lo que se cambió a partir de ellas.

  El texto generado por la IA sin ese aporte no queda protegido por sí solo.
- **El registro exige decirlo:** el formulario de la DNDA del 6 de agosto de 2026 pide declarar «cual fue el aporte» de la IA. Hay que declararlo con la verdad: dar información falsa es delito.
- **La evidencia del aporte propio ya existe:** el historial de git, los planes y las decisiones (`docs/plan-reconstruccion.md`, `docs/decisiones-fase0.md`), las revisiones y las pruebas. Hay que conservarla.
- **Para la estrategia** importa poco, porque la ventaja de Karta no está en el código sino en la comunidad y en los datos ([plan de código abierto](plan-codigo-abierto.md)). Las licencias siguen protegiendo lo que sí tiene autor.

## 4. Las licencias de Karta en Colombia

AGPL, Apache 2.0 y CC BY 4.0 son autorizaciones no exclusivas válidas, que da el titular de los derechos (Decisión 351, art. 13; Ley 23, arts. 3 y 12). No hay jurisprudencia colombiana sobre ellas.

**Un detalle colombiano:** si una licencia no dice el plazo, queda limitada a 5 años, y si no dice el territorio, al país donde se otorga (art. 183):
- Apache 2.0 y CC BY 4.0 dicen «perpetual, worldwide».
- La AGPL fija el plazo, pero no el territorio de forma expresa. Por eso [LICENSE.md](../LICENSE.md) aclara que el titular la otorga con ámbito mundial.

**Sobre las cláusulas de renuncia a derechos morales** (por ejemplo, la de CC BY 4.0, sección 2.b.1): en Colombia no tienen efecto, porque esos derechos son irrenunciables.

## 5. Contribuciones: por qué el acuerdo está redactado así

El [acuerdo de contribución](acuerdo-de-contribucion.md) aplica lo que exige la ley vigente:

| Exigencia | Fuente | Cómo lo resuelve el acuerdo |
|---|---|---|
| Las licencias se limitan a las modalidades pactadas y se interpretan de forma restrictiva | Decisión 351, art. 31; Ley 23, arts. 77, 78 y 183 | Las cinco modalidades se enumeran expresamente, incluido relicenciar como software privativo |
| Es ineficaz pactar modalidades inexistentes o desconocidas | Ley 23, art. 183, inciso final (C-077 de 2023) | No hay cláusula «por conocer»; para una modalidad nueva se pide autorización |
| Sin plazo, 5 años; sin territorio, el país | Ley 23, art. 183 | «Por todo el término de protección» y «ámbito mundial» |
| Es ineficaz la cesión general de la producción futura | Ley 23, art. 183 | Es una licencia de cada Contribución que se envía, no una cesión |
| Los derechos morales no se ceden ni se renuncian | Ley 23, art. 30; Decisión 351, art. 11 | Se reconocen; se pacta la forma de atribución y se autorizan las modificaciones necesarias (Decisión 351, art. 23) |
| El escrito puede ser un mensaje de datos y la firma puede ser electrónica | Ley 527 de 1999, arts. 6, 7 y 14; Decreto 1074 de 2015, arts. 2.2.2.47.1 y 2.2.2.47.7 | Acuerdo expreso sobre la firma: la frase en el pull request desde una cuenta autenticada |
| El software «como tal» no es patentable, pero sí algunas invenciones implementadas por computador | Decisión 486, art. 15; Consejo de Estado, 28 de abril de 2022 | Licencia de patentes con terminación defensiva, al estilo de Apache 2.0 |
| Los datos de los contribuidores requieren autorización y aviso de privacidad | Ley 1581 de 2012, arts. 9, 12 y 26; Decreto 1074, arts. 2.2.2.25.2.1 y siguientes | Cláusula 11: datos mínimos, sin documento de identidad, finalidades, derechos y transferencia a GitHub |
| Lo que genera la IA no tiene autor | Concepto DNDA 14722 de 2024 | Cada contribuidor declara qué generó con IA y que lo revisó |

## 6. Registro del software ante la DNDA

El registro es **declarativo**: no crea el derecho, pero da publicidad, fecha cierta y presunción de veracidad (Decisión 351, art. 53; Decreto 1066, art. 2.6.1.1.2).

- **Es gratuito.** La tasa del art. 169 de la Ley 2294 de 2023 fue declarada inexequible por la C-117 de 2024. Tanto la página de costos como el formulario de 2026 dicen que el trámite no tiene costo.
- **Cómo se hace:** en línea, en [registroenlinea.gov.co](https://www.registroenlinea.gov.co/software.aspx), con el formulario «Soporte lógico (software)». Se adjunta el código fuente en ZIP, una descripción breve de las funciones y la declaración del aporte de la IA.
- **Cuánto tarda:** unos 15 días hábiles, según la DNDA.
- **Qué registrar:** la versión de la entrega final como obra «publicada» (el repositorio es público). Las versiones mayores posteriores pueden registrarse como obras derivadas.

## 7. Marca «Karta»

**Trámite ante la SIC** (Decisión 486, arts. 138 a 152):
1. búsqueda de antecedentes;
2. solicitud en línea;
3. publicación en la Gaceta;
4. 30 días para oposiciones;
5. decisión.

La marca dura 10 años y se puede renovar.

**Clases** (Niza, 13.ª edición):
- **9:** aplicaciones descargables; incluye bienes virtuales, como los marcos del avatar.
- **39:** información de tráfico y de rutas y horarios de transporte.
- **42:** software como servicio y mapas en línea.
- **35:** opcional, solo si se venden estadísticas.

**Tasa 2026, en línea:** alrededor de **$1.347.500** por la primera clase y **$673.500** por cada clase adicional (Res. SIC 6167 de 2026; la Res. 77243 de 2025 decía $1.348.500 y $674.000). Las Mipyme acreditadas pagan menos.

**Antecedentes revisados:**
- **Grab** tiene el registro internacional «Karta» (IR 1610396, clases 9, 35, 38, 39, 41, 42 y 45), que **no designa a Colombia**. También opera KartaView, una plataforma de mapas: es un campo cercano y conviene vigilarlo.
- **Pendiente:** no se pudo consultar la base nacional SIPI. Esa búsqueda es gratis y va **antes** de radicar.

**Cuándo radicar:** antes de lanzar la app en las tiendas (fase 4 o después). Hasta entonces el nombre no tiene protección.

## 8. Pendientes y lo que no se pudo verificar

**Acciones:**
1. Registrar el software en la DNDA.
2. Radicar la carta al Comité de Propiedad Intelectual de la UdeC.
3. Que José acepte el acuerdo por sus aportes a los textos del curso.
4. Buscar antecedentes de la marca en SIPI.
5. Publicar la política de tratamiento de datos de Karta (fase 4).

**Sin verificar:**
- el texto completo de la Res. SIC 6167 de 2026;
- la búsqueda en SIPI;
- el Reglamento Estudiantil de la UdeC (Acuerdo 14 de 2009), que está escaneado y no se leyó completo;
- si una persona natural sin matrícula mercantil puede acreditarse como Mipyme ante la SIC;
- la lista de países con nivel adecuado de protección de la SIC (Estados Unidos), confirmada solo por fuentes secundarias.

## Fuentes principales

- Decisión 351 de 1993: https://normograma.mincultura.gov.co/mincultura/compilacion/docs/decision_comisioncandina_dec351.htm
- Ley 23 de 1982: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=3431
- Ley 1955 de 2019, art. 181: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=93970
- Sentencia C-077 de 2023: https://www.corteconstitucional.gov.co/relatoria/2023/C-077-23.htm
- Sentencia C-157 de 2021: https://www.corteconstitucional.gov.co/relatoria/2021/c-157-21.htm
- Sentencia C-117 de 2024: https://www.corteconstitucional.gov.co/Relatoria/2024/C-117-24.htm
- Decreto 1066 de 2015: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=76835
- Circular DNDA 06 de 2002: https://www.derechodeautor.gov.co/sites/default/files/2024-03/Circular%20No.%2006%20del%2015%20de%20abril%20de%202002.pdf
- Circular DNDA 026 de 2023: https://www.derechodeautor.gov.co/sites/default/files/2024-03/Circular%2026%20de%202023.pdf
- Concepto DNDA sobre IA (rad. 1-2024-14722): https://www.derechodeautor.gov.co/sites/default/files/2024-04/Concepto%20Rad.%2014722,%20marzo%202024.pdf
- Formulario de registro de software (agosto de 2026): https://www.derechodeautor.gov.co/sites/default/files/2026-09/6.%20Soporte-Logico-Software_0.pdf
- Ley 527 de 1999: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=4276
- Decreto 1074 de 2015: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=76608
- Ley 1581 de 2012: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=49981
- Estatuto de Propiedad Intelectual de la UdeC (Acuerdo 03 de 2012): https://drive.google.com/file/d/1hz9VTIbq-Q33IT6IqeW-UntVuGcUav_R/view
- Decisión 486 de 2000: https://faolex.fao.org/docs/pdf/anc83522.pdf
- Registro internacional «Karta» de Grab: https://www3.wipo.int/madrid/monitor/en/showData.jsp?ID=ROM.1610396
