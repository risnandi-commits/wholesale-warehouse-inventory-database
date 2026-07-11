# Wholesale Warehouse Inventory Database System (MySQL v2)

A robust, relational, and production-ready MySQL database schema designed for wholesale warehouse operations. It comes equipped with automation features like database triggers for stock management and data consistency constraints, making it highly suitable for academic projects, portfolios, or small business inventory backends.

## Database Schema Architecture
The database consists of 5 tightly-coupled relational tables:
- `kategori`: Handles product categorization.
- `supplier`: Manages supplier credentials and contact details.
- `barang`: The master product table tracking current stock levels and pricing (`harga_modal`, `harga_grosir`).
- `transaksi_masuk`: Logs incoming stock from suppliers (recalculates `total_harga` dynamically).
- `transaksi_keluar`: Logs outgoing stock distribution to buyers.

## Advanced Features
- **Automated Stock Tracking:** Built-in `AFTER INSERT` and `BEFORE INSERT` triggers that automatically increment/decrement stock upon transactions.
- **Stock Deficit Prevention:** The outbound trigger throws a custom SQL State error (`45000`) if a transaction attempts to fetch more stock than available.
- **Dynamic Columns:** Utilizes MySQL `GENERATED ALWAYS AS STORED` columns to calculate transaction totals on the fly without manual inputs.
- **Data Integrity:** Strict `FOREIGN KEY` constraints with `ON DELETE RESTRICT` rules to safe-keep historical transaction footprints.

## Getting Started
1. Open your database administration tool (e.g., phpMyAdmin, MySQL Workbench).
2. Create a new database or uncomment the setup headers inside the script:
   ```sql
   CREATE DATABASE db_gudang_grosir;
   USE db_gudang_grosir;

---

## Entity-Relationship Diagram (ERD)

[ERD Warehouse Inventory](ERD-warehouse-inventory.png)

### Database Component Breakdown

| Entity | Primary Key | Foreign Key | Description |
| :--- | :--- | :--- | :--- |
| **Suppliers** | `id_suppliers` | None | Stores supplier contact details. |
| **Categories** | `id_categories` | None | Groups products into specific types. |
| **Product** | `id_product` | `id_categories`, `id_suppliers` | Core inventory details and stock levels. |
| **Incoming_transactions** | `id_incoming` | `id_product` | Tracks incoming restock batches. |
| **Outgoing_transactions** | `id_outgoing` | `id_product` | Tracks sales and outgoing stock. |

### Features Included
* 🔄 **Automated Inventory Tracking** via MySQL Triggers.
* 📈 **Real-time Profit & Stock Alerts** via Database Views.
* ⚡ **Performance Optimization** via Database Indexing.

