# lechuzing

Este repositorio tiene los archivos finales obtenidos durante la realización de mi trabajo final de carrera.

El repositorio tiene cinco carpetas:
* __docs__: Se encuentran los documentos generados para la presentación formal de este trabajo
* __FX2 Board__: Contiene el código fuente necesario para la configuración de la interfaz USB.
* __hardware__: Contiene archivos del diseño del circuito de interconexión. Se abren con Altium Designer.
* __PC__: Se encuentra el programa de pc desarrollado para la prueba del sistema.
* **Spartan6**: Contiene los archivos necesarios para la programación del FPGA.

## Información adicional

### docs

Esta carpeta posee en su interior dos carpeta adicionales, a saber, informe y presentacion. Ambas contienen archivos *.tex* que se compilan con PdfLatex

### PC

En su interior se encuentran un tres archivos denominados tfUSBCheck:
* tfUSBCheck.h: Es un archivo de cabecera para C++ que contiene las declaraciones de las funciones y clases utilizadas
* tfUSBCheck.cpp: Contiene el código fuente que implementa las funciones declaradas en el archivo de cabecera homonimo.
* tfUSBCheck: Es el ejecutable compilado con gcc. Fue compilado para Ubuntu 16.04. Si se desea otra versión, requiere compilación de los códigos y la configuración adecuada.

El programa de PC utiliza el puerto USB para envar y recibir en forma ininterrumpida paquetes aleatorios hacia el sistema realizado en este trabajo.

Además, existe un archivo nombrado como resultados. Este archivo es de texto plano y contiene la sintesis de los resultados obtenidos luego de ejecutar tfUSBCheck durante 24 horas.
