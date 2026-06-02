package servicio;

import java.awt.Color;
import java.sql.Connection;
import java.util.HashMap;
import net.sf.jasperreports.charts.design.JRDesignPieDataset;
import net.sf.jasperreports.charts.design.JRDesignPiePlot;
import net.sf.jasperreports.engine.JasperCompileManager;
import net.sf.jasperreports.engine.JasperExportManager;
import net.sf.jasperreports.engine.JasperFillManager;
import net.sf.jasperreports.engine.JasperPrint;
import net.sf.jasperreports.engine.JasperReport;
import net.sf.jasperreports.engine.design.JRDesignBand;
import net.sf.jasperreports.engine.design.JRDesignChart;
import net.sf.jasperreports.engine.design.JRDesignExpression;
import net.sf.jasperreports.engine.design.JRDesignField;
import net.sf.jasperreports.engine.design.JRDesignQuery;
import net.sf.jasperreports.engine.design.JRDesignSection;
import net.sf.jasperreports.engine.design.JRDesignStaticText;
import net.sf.jasperreports.engine.design.JRDesignTextField;
import net.sf.jasperreports.engine.design.JasperDesign;
import net.sf.jasperreports.engine.type.ModeEnum;
import net.sf.jasperreports.engine.type.OrientationEnum;
import repositorio.VentasRepository;

public class InformeService {

    private static final Color AZUL_CABECERA = new Color(40, 40, 120);
    private final VentasRepository repo;

    public InformeService(VentasRepository repo) {
        this.repo = repo;
    }

    public JasperPrint generarVentasPorCategoria() throws Exception {
        JasperDesign disenio = construirDisenio();
        JasperReport informe = JasperCompileManager.compileReport(disenio);
        try (Connection conn = repo.abrirConexion()) {
            return JasperFillManager.fillReport(informe, new HashMap<>(), conn);
        }
    }

    public void exportarPdf(JasperPrint print, String rutaDestino) throws Exception {
        JasperExportManager.exportReportToPdfFile(print, rutaDestino);
    }

    // ---------- construcción del diseño ----------

    private JasperDesign construirDisenio() throws Exception {
        JasperDesign jd = new JasperDesign();
        jd.setName("VentasPorCategoria");
        jd.setPageWidth(595);
        jd.setPageHeight(842);
        jd.setColumnWidth(555);
        jd.setLeftMargin(20);
        jd.setRightMargin(20);
        jd.setTopMargin(20);
        jd.setBottomMargin(20);
        jd.setOrientation(OrientationEnum.PORTRAIT);

        configurarQueryYCampos(jd);
        jd.setTitle(construirTitulo());
        jd.setColumnHeader(construirCabecera());
        ((JRDesignSection) jd.getDetailSection()).addBand(construirDetalle());
        jd.setSummary(construirResumenConGrafico(jd));

        return jd;
    }

    private void configurarQueryYCampos(JasperDesign jd) throws Exception {
        JRDesignQuery q = new JRDesignQuery();
        q.setText(VentasRepository.SQL_VENTAS_POR_CATEGORIA);
        jd.setQuery(q);

        jd.addField(campo("categoria", String.class));
        jd.addField(campo("unidades",  Long.class));
        jd.addField(campo("ingresos",  Double.class));
    }

    private JRDesignBand construirTitulo() {
        JRDesignBand band = new JRDesignBand();
        band.setHeight(40);

        JRDesignStaticText t = new JRDesignStaticText();
        t.setText("Ventas por categoría");
        t.setX(0); t.setY(0); t.setWidth(555); t.setHeight(30);
        t.setBold(true);
        t.setFontSize(18f);
        t.setForecolor(AZUL_CABECERA);
        band.addElement(t);
        return band;
    }

    private JRDesignBand construirCabecera() {
        JRDesignBand band = new JRDesignBand();
        band.setHeight(25);
        band.addElement(cabeceraColumna("Categoría",  0,   250));
        band.addElement(cabeceraColumna("Unidades",   260, 130));
        band.addElement(cabeceraColumna("Ingresos €", 400, 155));
        return band;
    }

    private JRDesignBand construirDetalle() {
        JRDesignBand band = new JRDesignBand();
        band.setHeight(20);
        band.addElement(textField("$F{categoria}", String.class, 0,   250));
        band.addElement(textField("$F{unidades}",  Long.class,   260, 130));
        band.addElement(textField("$F{ingresos}",  Double.class, 400, 155));
        return band;
    }

    private JRDesignBand construirResumenConGrafico(JasperDesign jd) {
        JRDesignBand band = new JRDesignBand();
        band.setHeight(320);

        JRDesignStaticText subt = new JRDesignStaticText();
        subt.setText("Distribución de ingresos por categoría");
        subt.setX(0); subt.setY(0); subt.setWidth(555); subt.setHeight(20);
        subt.setBold(true);
        band.addElement(subt);

        JRDesignChart pie = new JRDesignChart(jd, JRDesignChart.CHART_TYPE_PIE);
        pie.setX(0); pie.setY(25); pie.setWidth(555); pie.setHeight(290);
        pie.setShowLegend(true);

        JRDesignPieDataset ds = (JRDesignPieDataset) pie.getDataset();
        ds.setKeyExpression(expresion("$F{categoria}", String.class));
        ds.setValueExpression(expresion("$F{ingresos}", Double.class));
        ds.setLabelExpression(expresion(
            "$F{categoria} + \" - \" + new java.text.DecimalFormat(\"#,##0.00\").format($F{ingresos}) + \" €\"",
            String.class));

        JRDesignPiePlot plot = (JRDesignPiePlot) pie.getPlot();
        plot.setCircular(Boolean.TRUE);
        plot.setShowLabels(Boolean.TRUE);

        band.addElement(pie);
        return band;
    }

    // ---------- helpers ----------

    private JRDesignField campo(String nombre, Class<?> tipo) {
        JRDesignField f = new JRDesignField();
        f.setName(nombre);
        f.setValueClass(tipo);
        return f;
    }

    private JRDesignStaticText cabeceraColumna(String texto, int x, int w) {
        JRDesignStaticText st = new JRDesignStaticText();
        st.setText(texto);
        st.setX(x); st.setY(0); st.setWidth(w); st.setHeight(25);
        st.setBold(true);
        st.setForecolor(Color.WHITE);
        st.setBackcolor(AZUL_CABECERA);
        st.setMode(ModeEnum.OPAQUE);
        return st;
    }

    private JRDesignTextField textField(String expr, Class<?> tipo, int x, int w) {
        JRDesignTextField tf = new JRDesignTextField();
        tf.setBlankWhenNull(true);
        tf.setX(x); tf.setY(0); tf.setWidth(w); tf.setHeight(20);
        tf.setExpression(expresion(expr, tipo));
        return tf;
    }

    private JRDesignExpression expresion(String text, Class<?> tipo) {
        JRDesignExpression e = new JRDesignExpression();
        e.setText(text);
        e.setValueClass(tipo);
        return e;
    }
}