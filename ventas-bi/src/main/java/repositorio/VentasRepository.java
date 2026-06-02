package repositorio;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class VentasRepository {

    private static final String JDBC_URL  = System.getenv("HIVE_JDBC_URL") != null
            ? System.getenv("HIVE_JDBC_URL")
            : "jdbc:hive2://localhost:10001/default";
    private static final String JDBC_USER = "hive";
    private static final String JDBC_PASS = "";
    private static final String DRIVER    = "org.apache.hive.jdbc.HiveDriver";

    public static final String SQL_VENTAS_POR_CATEGORIA =
        "SELECT categoria, " +
        "       SUM(cantidad) AS unidades, " +
        "       SUM(cantidad * precio_unitario) AS ingresos " +
        "FROM ventas_reporte " +
        "GROUP BY categoria";

    public VentasRepository() {
        try {
            Class.forName(DRIVER);
        } catch (ClassNotFoundException e) {
            throw new IllegalStateException("Driver Hive no encontrado", e);
        }
    }

    public Connection abrirConexion() throws SQLException {
        return DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASS);
    }
}