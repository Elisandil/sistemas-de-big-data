package modelo;

public class VentaCategoria {
    private final String categoria;
    private final long unidades;
    private final double ingresos;

    public VentaCategoria(String categoria, long unidades, double ingresos) {
        this.categoria = categoria;
        this.unidades = unidades;
        this.ingresos = ingresos;
    }

    public String getCategoria() { return categoria; }
    public long getUnidades()    { return unidades; }
    public double getIngresos()  { return ingresos; }
}