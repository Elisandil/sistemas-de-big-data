import controlador.InformesController;
import repositorio.VentasRepository;
import servicio.InformeService;
import vista.InformesJFrame;
import net.sf.jasperreports.engine.JasperPrint;

public class App {
    public static void main(String[] args) {
        VentasRepository repo = new VentasRepository();
        InformeService servicio = new InformeService(repo);

        if (args.length > 0 && "--headless".equals(args[0])) {
            // Modo headless: genera PDF directamente sin GUI
            String rutaPdf = args.length > 1 ? args[1] : "VentasPorCategoria.pdf";
            System.out.println("Modo headless: generando informe en " + rutaPdf);
            try {
                JasperPrint print = servicio.generarVentasPorCategoria();
                servicio.exportarPdf(print, rutaPdf);
                System.out.println("Informe generado correctamente: " + rutaPdf);
            } catch (Exception e) {
                System.err.println("Error generando informe: " + e.getMessage());
                e.printStackTrace();
                System.exit(1);
            }
        } else {
            // Modo GUI: ventana Swing
            InformesJFrame vista = new InformesJFrame();
            new InformesController(vista, servicio);
            vista.setVisible(true);
        }
    }
}