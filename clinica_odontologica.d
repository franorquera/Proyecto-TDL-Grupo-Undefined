module clinica_odontologica_final;

import std.stdio;
import std.algorithm;
import std.conv:to;
import core.stdc.stdlib;
import core.exception;
import std.conv;
import std.format;
import std.array : array;
import std.string;
import std.typecons : Yes;
import std.range; 
import std.parallelism;
import std.exception;
import std.traits;
import std.ascii : isAlpha;
import std.file;
import std.concurrency;
import core.thread;


/***********************************************/
/**           INTERFACING C                   **/
/***********************************************/
extern (C) int strcmp(const char* string1, const char* string2);

bool buscar_paciente(string[][int] pacientes, string pacienteAtendido){
    auto valor_pacientes = pacientes.values.reverse();

    for(int i =0; i<=(valor_pacientes.length)-1;i++){
        if (strcmp(std.string.toStringz(valor_pacientes[i][0]), std.string.toStringz(pacienteAtendido)) == 0){
            return true;
        }
    }
    return false;
}

/***********************************************/
/**           CLÍNICA ODONTOLOGICA            **/
/***********************************************/

enum string URGENTE = "URGENTE";
enum string REGULAR = "REGULAR";
enum string ATENDER_SIGUIETE = "ATENDER_SIGUIETE";
enum string PEDIR_TURNO = "PEDIR_TURNO";
enum string INFORME = "INFORME";

string escribir_resumen(string[][int] pacientes, int desde, ulong hasta) {
    auto dni_pacientes = pacientes.keys.reverse()[desde - 1 .. hasta];
    auto lista_pacientes = pacientes.values.reverse()[desde - 1 .. hasta];
    File archivo = File("resumen_clinica.txt", "a");
    for (int i = 0; i <= dni_pacientes.length - 1; i ++) {
        archivo.writeln(format("dni %d, nombre %s, cantidad de veces atendido %s", dni_pacientes[i], lista_pacientes[i][0], lista_pacientes[i][1]));
    }
    archivo.close();
    return "Resumen escrito correctamente";
}

void escribir_reporte(string mensaje) {
    File archivo = File("reporte_clinica.txt", "a");
    archivo.writeln(mensaje);
    archivo.close();
    writeln(mensaje);
}

string pedir_turno(Multicola multicola, Paciente!int paciente) {
    paciente.prioridad == URGENTE ? multicola.multicola_encolar_prioritario(paciente) : multicola.multicola_encolar_regular(paciente);
    string mensaje = format("Se le asigno un turno con prioridad %s a %s", paciente.prioridad, paciente.nombre);
    return mensaje;
}

string[][int] incrementar_atendido(string[][int] pacientes, Paciente!int pacienteAtendido) {
    if (0 in pacientes) {pacientes.remove(0);}

    pacientes[pacienteAtendido.extra] = pacientes.get(pacienteAtendido.extra, [pacienteAtendido.nombre, "0"]);
    auto lista = pacientes[pacienteAtendido.extra];
    string snum = lista[1];
    int num = to!int(snum);
    num ++;
    string snum2 = to!string(num);
    lista[1] = snum2;
    return pacientes;
}

string atender_paciente(Multicola multicola, string[][int] pacientes) {
    Paciente!int pacienteAtendido;
    string mensaje;
    try{
        pacienteAtendido = multicola.multicola_desencolar();
        mensaje = format("Se atendio al paciente %s", pacienteAtendido.nombre);
        pacientes = incrementar_atendido(pacientes, pacienteAtendido);
    }catch(Error error){
        mensaje = to!string(error.message);
    }
    return mensaje;
}

void procesar_entrada(Multicola multicola) {
    string[] linea;
    string[] turno;
    string comando;
    string[][int] pacientes;
    pacientes[0] = ["nombre", "cantidad_veces_atendido"];

    string[] lista = stdin.byLineCopy(Yes.keepTerminator).array();

    for (int i = 0; i < lista.length; i++) {
        string mensaje;
        linea = split(strip(lista[i]), ":");
        comando = linea[0];

        if (comando == ATENDER_SIGUIETE) {
            mensaje = atender_paciente(multicola, pacientes);
        }
        else if (comando == PEDIR_TURNO) {
            turno = split(linea[1], ",");
            try{
                Paciente!int primero = Paciente!int(turno[0],turno[1],to!int(turno[2]));
                mensaje = pedir_turno(multicola, primero);
            }catch(RangeError error){
                mensaje = "Faltan parametros";
            }catch(Error error){
                mensaje = "Algo salio mal";
            }
        }
        else if (comando == INFORME) {
            string[] limites = split(linea[1], ",");

            ulong hasta = to!ulong(limites[1]);
            int desde = to!int(limites[0]);

            hasta > pacientes.length ? hasta = pacientes.length : true;
            desde < 1 ? desde = 1 : true;

            mensaje = escribir_resumen(pacientes, desde, hasta);
        }
        else {
            mensaje = "El comando ingresado es invalido";
        }

        new Thread({
            escribir_reporte(mensaje);
        }).start().join();
    }
}

struct Paciente(T){
    string nombre;
    string prioridad;
    T extra;
}

class Files_txt {
    string route;
    int n;
    this(string route, int n) {
        this.route = route;
        this.n = n;
    }
    void read_file() {
        writeln("reading ", route, " in ", thisTid);
        writeln("Thread ", n, " starts ");
        read(route);
        writeln("Thread ", n, " stops ");
    }
}

void parallelism() {
    auto files_txt = [new Files_txt("reporte_clinica.txt", 1), new Files_txt("resumen_clinica.txt", 2)];
    foreach(f; parallel(files_txt)) {
        f.read_file();
    }
}

int main () {
    Multicola multicola = new Multicola;
    procesar_entrada(multicola);

    pragma(msg, "compilando ...");

    Thread.sleep(1.seconds);
    writeln("\n");

   parallelism();

    return 0;   
}

/***********************************************/
/**                   COLA                    **/
/***********************************************/

struct cola {
    Paciente!int[] lista_cola;
}
alias cola cola_t;

cola_t *cola_crear() {
    cola_t *cola = cast(cola_t*) malloc((cola_t).sizeof); 
    if (cola == null) {
        return null;
    }
    Paciente!int[] lista;
    cola.lista_cola = lista;
    return cola;
}
void cola_destruir(cola_t *cola){
    free(cola);
}
bool cola_esta_vacia(const cola_t *cola) {
    return cola.lista_cola.length == 0;
}
void cola_encolar(cola_t *cola, Paciente!int valor) {
    cola.lista_cola ~= valor; 
}
Paciente!int cola_ver_primero(const cola_t *cola) {
    return cola.lista_cola[0];
}
Paciente!int cola_desencolar(cola_t *cola) {
    if (cola_esta_vacia(cola)){
        throw new Error("La cola esta vacia");
    }
    Paciente!int dato = cola.lista_cola[0];
    cola.lista_cola = cola.lista_cola.remove(0);
    return dato;
}
int cola_cantidad(cola_t *cola) {
    return cast(int) cola.lista_cola.length;
}

/***********************************************/
/**               MULTICOLA                   **/
/***********************************************/

class Multicola {
    cola_t* cola_prioritaria;
    cola_t* cola_regular;

    this() {
        this.cola_prioritaria = cola_crear();
        this.cola_regular = cola_crear();
    }

    void multicola_encolar_prioritario(Paciente!int paciente) 
    in {
        assert(!__traits(isAbstractClass, paciente));
        assert(__traits(isPOD, typeof(paciente)));
        assert(__traits(hasMember, paciente, "nombre"));
        assert(__traits(hasMember, paciente, "prioridad"));
        assert(__traits(hasMember, paciente, "extra"));
        assert(__traits(isArithmetic, paciente.extra));
        // std.traits
        assert(isSomeString!(typeof(paciente.nombre)));
        assert(all!isAlpha(paciente.prioridad));
    }
    body {
        cola_encolar(this.cola_prioritaria, paciente);    
    }

    void multicola_encolar_regular(Paciente!int paciente) {
        cola_encolar(this.cola_regular, paciente);
    }

    Paciente!int multicola_desencolar() 
    out (paciente) {
        assert(!__traits(isAbstractClass, paciente));
        assert(__traits(isPOD, typeof(paciente)));
        assert(__traits(hasMember, paciente, "nombre"));
        assert(__traits(hasMember, paciente, "prioridad"));
        assert(__traits(hasMember, paciente, "extra"));
        assert(__traits(isArithmetic, paciente.extra));
        // std.traits
        assert(isSomeString!(typeof(paciente.nombre)));
        assert(all!isAlpha(paciente.prioridad));
    }
    body {
        if (!cola_esta_vacia(this.cola_prioritaria)) {
            return cola_desencolar(this.cola_prioritaria);
        }
        return cola_desencolar(this.cola_regular);
    }

    int multicola_cantidad() {
        return (cola_cantidad(this.cola_prioritaria) + cola_cantidad(this.cola_regular));
    }

    bool multicola_esta_vacia() {
        return !multicola_cantidad();
    }

    Paciente!int multicola_ver_primero() {
        if (cola_esta_vacia(this.cola_prioritaria) == false) {
            return cola_ver_primero(this.cola_prioritaria);
        }
        return cola_ver_primero(this.cola_regular);
    }

    unittest
    {
        Multicola multicola = new Multicola;
        Paciente!int f = Paciente!int("fede", "REGULAR");
        Paciente!int g = Paciente!int("fede", "URGENTE");
        multicola.multicola_encolar_prioritario(g);
        multicola.multicola_encolar_regular(f);
        assert(multicola.multicola_desencolar()==g);
        assert(multicola.multicola_desencolar()==f);
    }
}