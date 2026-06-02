package vista;

import java.awt.GridLayout;
import java.awt.event.ActionListener;
import javax.swing.JButton;
import javax.swing.JFrame;

public class InformesJFrame extends JFrame {

    private final JButton btnGenerar = new JButton("Generar informe (PDF)");

    public InformesJFrame() {
        setTitle("Informes BI - Ventas");
        setDefaultCloseOperation(EXIT_ON_CLOSE);
        setSize(360, 120);
        setLocationByPlatform(true);
        setLayout(new GridLayout(1, 1, 8, 8));
        add(btnGenerar);
    }

    public void addGenerarListener(ActionListener l) {
        btnGenerar.addActionListener(l);
    }
}