package controlador;

import java.awt.Desktop;
import java.io.File;
import javax.swing.JFileChooser;
import javax.swing.JOptionPane;
import javax.swing.filechooser.FileNameExtensionFilter;
import net.sf.jasperreports.engine.JasperPrint;
import servicio.InformeService;
import vista.InformesJFrame;

public class InformesController {

    private final InformesJFrame vista;
    private final InformeService servicio;

    public InformesController(InformesJFrame vista, InformeService servicio) {
        this.vista = vista;
        this.servicio = servicio;
        this.vista.addGenerarListener(e -> onGenerar());
    }

    private void onGenerar() {
        try {
            JasperPrint print = servicio.generarVentasPorCategoria();
            File destino = pedirDestino();
            if (destino == null) return;

            servicio.exportarPdf(print, destino.getAbsolutePath());
            abrir(destino);
        } catch (Exception ex) {
            ex.printStackTrace();
            JOptionPane.showMessageDialog(vista, "Error: " + ex.getMessage());
        }
    }

    private File pedirDestino() {
        JFileChooser jfc = new JFileChooser();
        jfc.setDialogTitle("Guardar informe como...");
        jfc.setSelectedFile(new File(System.getProperty("user.home") + "/VentasPorCategoria.pdf"));
        jfc.setFileFilter(new FileNameExtensionFilter("Archivos PDF", "pdf"));

        if (jfc.showSaveDialog(vista) != JFileChooser.APPROVE_OPTION) return null;

        File f = jfc.getSelectedFile();
        if (!f.getName().toLowerCase().endsWith(".pdf")) {
            f = new File(f.getAbsolutePath() + ".pdf");
        }
        return f;
    }

    private void abrir(File f) throws Exception {
        if (Desktop.isDesktopSupported() && f.exists()) {
            Desktop.getDesktop().open(f);
        }
    }
}