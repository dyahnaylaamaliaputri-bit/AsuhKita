# AsuhKita Backend — Dokumentasi API Auth

## Base URL (Development)
```
http://localhost:3000/api
```

## Format Respons Standar

**Sukses:**
```json
{
  "success": true,
  "message": "Pesan sukses",
  "data": { ... }
}
```

**Gagal:**
```json
{
  "success": false,
  "message": "Pesan error yang ramah",
  "error": "KODE_ERROR"
}
```

---

## 1. Health Check
**GET** `/health`

Cek apakah server berjalan.

**Response:**
```json
{
  "success": true,
  "message": "AsuhKita Backend berjalan dengan baik! 🎉",
  "timestamp": "2026-10-20T10:00:00.000Z",
  "version": "1.0.0"
}
```

---

## 2. Registrasi
**POST** `/api/auth/register`

### Request Body
```json
{
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "password": "password123",
  "role": "donatur",
  "phone": "08123456789"
}
```

| Field    | Tipe   | Wajib | Keterangan                          |
|----------|--------|-------|-------------------------------------|
| name     | string | ✅    | Nama lengkap                        |
| email    | string | ✅    | Format email valid                  |
| password | string | ✅    | Minimal 8 karakter                  |
| role     | string | ❌    | `donatur` (default) atau `admin_panti` |
| phone    | string | ❌    | Nomor HP                            |

### Response Sukses (201)
```json
{
  "success": true,
  "message": "Registrasi berhasil! Silakan login.",
  "data": {
    "id": "uuid-user",
    "name": "Budi Santoso",
    "email": "budi@example.com",
    "role": "donatur"
  }
}
```

### Response Error
| Kode | Error                  | Keterangan                    |
|------|------------------------|-------------------------------|
| 400  | MISSING_FIELDS         | Nama/email/password kosong    |
| 400  | WEAK_PASSWORD          | Password kurang dari 8 karakter |
| 400  | INVALID_EMAIL          | Format email tidak valid      |
| 409  | EMAIL_ALREADY_EXISTS   | Email sudah terdaftar         |

---

## 3. Login
**POST** `/api/auth/login`

### Request Body
```json
{
  "email": "budi@example.com",
  "password": "password123"
}
```

### Response Sukses (200)
```json
{
  "success": true,
  "message": "Login berhasil.",
  "data": {
    "access": "eyJhbGci....",
    "refresh": "eyJhbGci....",
    "user": {
      "id": "uuid-user",
      "name": "Budi Santoso",
      "email": "budi@example.com",
      "role": "donatur",
      "avatar_url": null
    }
  }
}
```

> **Flutter:** Simpan `access` dan `refresh` di `flutter_secure_storage`

### Response Error
| Kode | Error               | Keterangan                              |
|------|---------------------|-----------------------------------------|
| 400  | MISSING_FIELDS      | Email/password kosong                   |
| 401  | INVALID_CREDENTIALS | Email atau password salah (pesan generik) |

---

## 4. Refresh Token
**POST** `/api/auth/refresh`

Digunakan Flutter secara otomatis saat access token kedaluwarsa (401).

### Request Body
```json
{
  "refreshToken": "eyJhbGci...."
}
```

### Response Sukses (200)
```json
{
  "success": true,
  "message": "Token berhasil diperbarui.",
  "data": {
    "access": "eyJhbGci....",
    "userId": "uuid-user"
  }
}
```

### Response Error
| Kode | Error                | Keterangan                              |
|------|----------------------|-----------------------------------------|
| 400  | MISSING_REFRESH_TOKEN| Body kosong                             |
| 401  | INVALID_REFRESH_TOKEN| Token tidak valid atau kedaluwarsa      |
| 401  | SESSION_NOT_FOUND    | Token tidak ada di database             |
| 401  | SESSION_REVOKED      | Token sudah dicabut (sudah logout)      |
| 401  | SESSION_EXPIRED      | Sesi sudah melewati masa berlaku        |

---

## 5. Logout
**POST** `/api/auth/logout`

🔒 **Memerlukan:** `Authorization: Bearer <access_token>`

### Request Body
```json
{
  "refreshToken": "eyJhbGci...."
}
```

### Response Sukses (200)
```json
{
  "success": true,
  "message": "Logout berhasil. Sesi telah dicabut."
}
```

> **Flutter:** Setelah logout, hapus access token dan refresh token dari `flutter_secure_storage`

---

## 6. Get Profile (Cek Sesi)
**GET** `/api/auth/me`

🔒 **Memerlukan:** `Authorization: Bearer <access_token>`

### Response Sukses (200)
```json
{
  "success": true,
  "data": {
    "id": "uuid-user",
    "name": "Budi Santoso",
    "email": "budi@example.com",
    "role": "donatur",
    "phone": "08123456789",
    "avatar_url": null,
    "biometric_enabled": false,
    "created_at": "2026-10-20T10:00:00.000Z"
  }
}
```

### Response Error
| Kode | Error           | Keterangan             |
|------|-----------------|------------------------|
| 401  | MISSING_TOKEN   | Header Authorization kosong |
| 401  | TOKEN_EXPIRED   | Access token kedaluwarsa |
| 401  | INVALID_TOKEN   | Token tidak valid      |
| 404  | USER_NOT_FOUND  | Akun tidak ditemukan   |

---

## Cara Test dengan Postman

### Langkah:
1. **Register** → `POST /api/auth/register`
2. **Login** → `POST /api/auth/login` → copy `access` token
3. **Buka tab GET /api/auth/me** → di Authorization pilih **Bearer Token** → paste token
4. **Logout** → `POST /api/auth/logout` dengan body `refreshToken`
5. **Coba GET /api/auth/me lagi** → harus dapat 401 (token sudah tidak bisa pakai)

### Environment Variable Postman (disarankan):
| Variable       | Value                        |
|----------------|------------------------------|
| base_url       | http://localhost:3000/api    |
| access_token   | (isi setelah login)          |
| refresh_token  | (isi setelah login)          |
