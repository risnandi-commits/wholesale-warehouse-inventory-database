-- =====================================================================
-- TEMPLATE DATABASE: GUDANG BARANG GROSIR (v2 - lengkap)
-- Untuk kebutuhan template project (siap pakai & bisa dimodifikasi)
-- Compatible: MySQL 5.7+ / 8.0+
-- =====================================================================

-- Uncomment 2 baris di bawah kalau mau langsung buat database baru
-- CREATE DATABASE IF NOT EXISTS db_gudang_grosir CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE db_gudang_grosir;

SET FOREIGN_KEY_CHECKS = 0;

-- Urutan DROP: tabel anak (yang punya FK) dihapus dulu sebelum tabel induk
DROP TABLE IF EXISTS transaksi_keluar;
DROP TABLE IF EXISTS transaksi_masuk;
DROP TABLE IF EXISTS barang;
DROP TABLE IF EXISTS kategori;
DROP TABLE IF EXISTS supplier;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- TABEL: kategori (BARU)
-- Dipisah dari kolom teks bebas biar konsisten & gampang di-filter
-- =====================================================================
CREATE TABLE kategori (
    id_kategori     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama_kategori   VARCHAR(100) NOT NULL,
    keterangan      VARCHAR(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- TABEL: supplier
-- =====================================================================
CREATE TABLE supplier (
    id_supplier     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama_supplier   VARCHAR(150) NOT NULL,
    kontak          VARCHAR(50)  DEFAULT NULL,   -- no. HP / telepon supplier
    alamat          TEXT         DEFAULT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

    -- Tambahan opsional: email VARCHAR(100), npwp VARCHAR(30),
    -- status ENUM('aktif','nonaktif') DEFAULT 'aktif'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- TABEL: barang (master produk)
-- =====================================================================
CREATE TABLE barang (
    id_barang       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama_barang     VARCHAR(150)    NOT NULL,
    id_kategori     INT UNSIGNED    DEFAULT NULL,
    -- Sekarang pakai FK ke tabel kategori, bukan teks bebas lagi.
    -- Kalau mau balik simpel (tanpa tabel kategori), tinggal ganti jadi
    -- kategori VARCHAR(100) dan hapus FK-nya di bagian bawah.

    satuan          VARCHAR(20)     DEFAULT 'pcs',
    -- Contoh: pcs, dus, karton, kg, dll — silakan sesuaikan/hapus

    stok            INT UNSIGNED    NOT NULL DEFAULT 0,
    -- Stok otomatis nambah/berkurang lewat TRIGGER (lihat bagian bawah)

    harga_modal     DECIMAL(15,2)   UNSIGNED NOT NULL DEFAULT 0,
    harga_grosir    DECIMAL(15,2)   UNSIGNED NOT NULL DEFAULT 0,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_barang_kategori
        FOREIGN KEY (id_kategori) REFERENCES kategori(id_kategori)
        ON UPDATE CASCADE ON DELETE SET NULL

    -- Tambahan opsional: harga_eceran DECIMAL(15,2), foto_barang VARCHAR(255),
    -- min_stok INT (buat fitur notifikasi stok menipis)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_barang_nama ON barang(nama_barang);


-- =====================================================================
-- TABEL: transaksi_masuk
-- Mencatat pasokan barang dari supplier yang masuk ke gudang
-- =====================================================================
CREATE TABLE transaksi_masuk (
    id_transaksi        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_barang           INT UNSIGNED NOT NULL,
    id_supplier         INT UNSIGNED NOT NULL,
    jumlah_masuk        INT UNSIGNED NOT NULL,
    harga_beli_satuan   DECIMAL(15,2) UNSIGNED NOT NULL,
    -- Harga beli disimpan per transaksi (historis), karena harga_modal di
    -- tabel barang bisa berubah sewaktu-waktu dan gak boleh menimpa histori lama

    total_harga         DECIMAL(15,2) GENERATED ALWAYS AS (jumlah_masuk * harga_beli_satuan) STORED,
    -- Kolom generated, otomatis dihitung MySQL, gak perlu diisi manual saat INSERT

    tanggal_masuk       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    keterangan          VARCHAR(255) DEFAULT NULL,  -- contoh: no. nota/faktur dari supplier
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_masuk_barang
        FOREIGN KEY (id_barang) REFERENCES barang(id_barang)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_masuk_supplier
        FOREIGN KEY (id_supplier) REFERENCES supplier(id_supplier)
        ON UPDATE CASCADE ON DELETE RESTRICT

    -- ON DELETE RESTRICT supaya data barang/supplier gak bisa terhapus
    -- kalau masih ada histori transaksinya. Ganti ke CASCADE/SET NULL
    -- kalau alur bisnis project-mu butuh perilaku beda.
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_masuk_tanggal ON transaksi_masuk(tanggal_masuk);


-- =====================================================================
-- TABEL: transaksi_keluar (BARU)
-- Mencatat barang yang keluar dari gudang (dijual/didistribusikan)
-- =====================================================================
CREATE TABLE transaksi_keluar (
    id_transaksi_keluar INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_barang           INT UNSIGNED NOT NULL,
    jumlah_keluar        INT UNSIGNED NOT NULL,
    harga_jual_satuan    DECIMAL(15,2) UNSIGNED NOT NULL,
    total_harga          DECIMAL(15,2) GENERATED ALWAYS AS (jumlah_keluar * harga_jual_satuan) STORED,

    nama_pembeli         VARCHAR(150) DEFAULT NULL,
    -- Simpel pakai teks dulu. Kalau nanti butuh data pelanggan lebih detail
    -- (riwayat pembelian, kontak, dll), bikin tabel "pelanggan" sendiri
    -- lalu ganti kolom ini jadi id_pelanggan (FK), sama seperti pola supplier.

    tanggal_keluar       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    keterangan           VARCHAR(255) DEFAULT NULL,
    created_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_keluar_barang
        FOREIGN KEY (id_barang) REFERENCES barang(id_barang)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_keluar_tanggal ON transaksi_keluar(tanggal_keluar);


-- =====================================================================
-- TRIGGER: stok bertambah otomatis saat transaksi masuk
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_stok_bertambah
AFTER INSERT ON transaksi_masuk
FOR EACH ROW
BEGIN
    UPDATE barang
    SET stok = stok + NEW.jumlah_masuk
    WHERE id_barang = NEW.id_barang;
END$$

DELIMITER ;


-- =====================================================================
-- TRIGGER: stok berkurang otomatis saat transaksi keluar (BARU)
-- Sekalian validasi biar stok gak bisa minus
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_stok_berkurang
BEFORE INSERT ON transaksi_keluar
FOR EACH ROW
BEGIN
    DECLARE stok_sekarang INT UNSIGNED;

    SELECT stok INTO stok_sekarang FROM barang WHERE id_barang = NEW.id_barang;

    IF stok_sekarang IS NULL OR stok_sekarang < NEW.jumlah_keluar THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stok tidak mencukupi untuk transaksi keluar ini';
    END IF;

    UPDATE barang
    SET stok = stok - NEW.jumlah_keluar
    WHERE id_barang = NEW.id_barang;
END$$

DELIMITER ;


-- =====================================================================
-- DATA CONTOH (OPSIONAL) — buat testing awal
-- Hapus bagian ini sebelum template diserahkan ke pembeli final
-- =====================================================================
INSERT INTO kategori (nama_kategori) VALUES
('Sembako'), ('Makanan Instan'), ('Minuman');

INSERT INTO supplier (nama_supplier, kontak, alamat) VALUES
('CV Sumber Makmur', '081234567890', 'Jl. Industri No. 10, Semarang'),
('PT Anugerah Distribusi', '081298765432', 'Jl. Raya Grosir No. 5, Surabaya');

INSERT INTO barang (nama_barang, id_kategori, satuan, stok, harga_modal, harga_grosir) VALUES
('Minyak Goreng 1L', 1, 'dus', 0, 180000, 195000),
('Gula Pasir 1Kg', 1, 'karung', 0, 130000, 142000),
('Mie Instan Goreng', 2, 'dus', 0, 95000, 105000);

-- Trigger otomatis nambah stok
INSERT INTO transaksi_masuk (id_barang, id_supplier, jumlah_masuk, harga_beli_satuan, keterangan) VALUES
(1, 1, 50, 178000, 'Nota #INV-0001'),
(2, 2, 30, 128000, 'Nota #INV-0002'),
(3, 1, 100, 93000, 'Nota #INV-0003');

-- Trigger otomatis kurangin stok (dicek dulu cukup/gaknya)
INSERT INTO transaksi_keluar (id_barang, jumlah_keluar, harga_jual_satuan, nama_pembeli, keterangan) VALUES
(1, 10, 195000, 'Toko Barokah', 'Ambil di gudang'),
(3, 25, 105000, 'Toko Sejahtera', NULL);
