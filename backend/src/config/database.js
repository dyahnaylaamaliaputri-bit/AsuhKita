// File: backend/src/config/database.js
// Fungsi: Konfigurasi koneksi ke Supabase (PostgreSQL)
// Mode: Otomatis deteksi apakah DATABASE_URL valid atau pakai MOCK (untuk demo tanpa Supabase)

const { Pool } = require('pg');
require('dotenv').config();

// ============================================================
// CEK apakah DATABASE_URL sudah diisi dengan nilai nyata
// ============================================================
const dbUrl = process.env.DATABASE_URL || '';
const isMockMode = !dbUrl || dbUrl.includes('xxxx') || dbUrl.includes('password') || dbUrl === '';

// ============================================================
// DATA IN-MEMORY MOCK — dipakai saat Supabase belum di-setup
// Data ini menggantikan database untuk demo/testing awal
// ============================================================
const mockDb = {
  users: [
    {
      id: 'usr-demo-001',
      name: 'Demo Donatur',
      email: 'demo@asuhkita.com',
      // bcrypt hash dari 'password123' (generate: bcrypt.hash('password123', 12))
      password_hash: '$2b$12$iMUdfP5MB9M6N/AUpe/od.XqpgywkyPpvj1IjmWYRsKSgTeV8uU5u',
      phone: '08123456789',
      role: 'donatur',
      avatar_url: null,
      biometric_enabled: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
    {
      id: 'usr-admin-001',
      name: 'Admin Al-Ikhlas',
      email: 'admin@asuhkita.com',
      // bcrypt hash dari 'admin123!'  (generate: bcrypt.hash('admin123!', 12))
      password_hash: '$2b$12$6hOLUgTUK1cINBxPjnv1s.HyTp9NF8p4kUzTW5.dubktmkFevFEYW',
      phone: '0211111111',
      role: 'admin_panti',
      avatar_url: null,
      biometric_enabled: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
  ],
  sessions: [],
  orphanages: [
    { id: 'orp-001', name: 'Panti Asuhan Al-Ikhlas',    city: 'Jakarta',    address: 'Jl. Damai No. 12', latitude: -6.2607, longitude: 106.8120, phone: '021-111111', description: 'Panti asuhan sejak 1995' },
    { id: 'orp-002', name: 'Panti Asuhan Cahaya Hati',  city: 'Bandung',    address: 'Jl. Merdeka No. 45', latitude: -6.9175, longitude: 107.6191, phone: '022-222222', description: 'Fokus pendidikan' },
    { id: 'orp-003', name: 'Panti Asuhan Bunga Bangsa', city: 'Surabaya',   address: 'Jl. Pahlawan No. 7', latitude: -7.2575, longitude: 112.7521, phone: '031-333333', description: '50 anak binaan' },
    { id: 'orp-004', name: 'Panti Asuhan Tunas Muda',   city: 'Yogyakarta', address: 'Jl. Gejayan No. 22', latitude: -7.7669, longitude: 110.3806, phone: '0274-44444', description: 'Anak usia sekolah' },
    { id: 'orp-005', name: 'Panti Asuhan Harapan Baru', city: 'Semarang',   address: 'Jl. Pemuda No. 88', latitude: -6.9932, longitude: 110.4203, phone: '024-555555', description: 'Aktif sejak 2005' },
  ],
  children: [
    { id: 'ch-001', orphanage_id: 'orp-001', alias: 'Bintang', age: 10, gender: 'L', need_category: 'Pendidikan', story_summary: 'Bintang cita-cita jadi dokter.', avatar: 'avatar_bintang.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Al-Ikhlas', orphanage_city: 'Jakarta' },
    { id: 'ch-002', orphanage_id: 'orp-001', alias: 'Bulan',   age: 8,  gender: 'P', need_category: 'Gizi',       story_summary: 'Bulan senang menggambar.', avatar: 'avatar_bulan.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Al-Ikhlas', orphanage_city: 'Jakarta' },
    { id: 'ch-003', orphanage_id: 'orp-002', alias: 'Awan',    age: 12, gender: 'L', need_category: 'Kesehatan',  story_summary: 'Awan semangat belajar meski sering sakit.', avatar: 'avatar_awan.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Cahaya Hati', orphanage_city: 'Bandung' },
    { id: 'ch-004', orphanage_id: 'orp-002', alias: 'Mentari', age: 9,  gender: 'P', need_category: 'Pendidikan', story_summary: 'Mentari ingin jadi guru.', avatar: 'avatar_mentari.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Cahaya Hati', orphanage_city: 'Bandung' },
    { id: 'ch-005', orphanage_id: 'orp-003', alias: 'Langit',  age: 11, gender: 'L', need_category: 'Umum',       story_summary: 'Langit suka musik.', avatar: 'avatar_langit.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Bunga Bangsa', orphanage_city: 'Surabaya' },
    { id: 'ch-006', orphanage_id: 'orp-003', alias: 'Pelangi', age: 7,  gender: 'P', need_category: 'Gizi',       story_summary: 'Pelangi anak ceria.', avatar: 'avatar_pelangi.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Bunga Bangsa', orphanage_city: 'Surabaya' },
    { id: 'ch-007', orphanage_id: 'orp-004', alias: 'Rizky',   age: 13, gender: 'L', need_category: 'Pendidikan', story_summary: 'Rizky berprestasi di sekolah.', avatar: 'avatar_rizky.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Tunas Muda', orphanage_city: 'Yogyakarta' },
    { id: 'ch-008', orphanage_id: 'orp-005', alias: 'Sari',    age: 10, gender: 'P', need_category: 'Kesehatan',  story_summary: 'Sari butuh biaya kesehatan rutin.', avatar: 'avatar_sari.png', status: 'Tersedia', orphanage_name: 'Panti Asuhan Harapan Baru', orphanage_city: 'Semarang' },
  ],
  sponsorship_packages: [
    { id: 'pkg-001', category: 'Pendidikan', name: 'Paket Buku & Alat Tulis',  amount_idr: 150000, description: 'Buku pelajaran dan perlengkapan sekolah' },
    { id: 'pkg-002', category: 'Pendidikan', name: 'Paket Seragam Sekolah',    amount_idr: 250000, description: 'Seragam lengkap satu tahun' },
    { id: 'pkg-003', category: 'Kesehatan',  name: 'Paket Vitamin Bulanan',    amount_idr: 100000, description: 'Suplemen vitamin' },
    { id: 'pkg-004', category: 'Kesehatan',  name: 'Paket Pemeriksaan Dokter', amount_idr: 300000, description: 'Kunjungan dokter dan obat' },
    { id: 'pkg-005', category: 'Gizi',       name: 'Paket Makanan Bergizi',    amount_idr: 200000, description: 'Gizi sehari-hari satu bulan' },
    { id: 'pkg-006', category: 'Umum',       name: 'Paket Kasih Sayang',       amount_idr: 500000, description: 'Paket lengkap pendidikan, gizi, kesehatan' },
  ],
  sponsorships: [],
  donations: [],
  ledger_blocks: [
    {
      id: 'genesis-block',
      block_index: 0,
      block_type: 'GENESIS',
      ref_id: null,
      payload_hash: '0000000000000000000000000000000000000000000000000000000000000000',
      prev_hash: '0',
      hash: 'GENESIS_ASUHKITA_2026_HASH_CHAIN_INITIALIZED',
      created_at: new Date().toISOString(),
    },
  ],
  feedback: [],
  game_scores: [],
  step_logs: [],
  iot_devices: [
    { id: 'iot-dev-001', orphanage_id: 'orp-001', device_name: 'Kotak Amal Al-Ikhlas #1', device_key: 'demo_device_key_001', is_active: true },
  ],
  iot_events: [],
  call_schedules: [],
  letters: [],
  exchange_rates: [
    { currency: 'USD', rate_to_idr: 16000 },
    { currency: 'SGD', rate_to_idr: 12000 },
    { currency: 'EUR', rate_to_idr: 17000 },
    { currency: 'SAR', rate_to_idr: 4300 },
  ],
};

// ============================================================
// MOCK QUERY ENGINE — Mensimulasikan PostgreSQL query
// Mendukung pola query dasar yang digunakan controllers
// ============================================================
let mockIdCounter = 1000;
const generateMockId = () => `mock-${Date.now()}-${mockIdCounter++}`;

const executeMockQuery = (text, params = []) => {
  const sql = text.trim().toUpperCase();

  // ---- SELECT queries ----

  // SELECT * FROM users WHERE email = $1
  if (sql.includes('FROM USERS') && sql.includes('EMAIL =')) {
    const email = params[0]?.toLowerCase();
    const rows = mockDb.users.filter(u => u.email === email);
    return { rows, rowCount: rows.length };
  }

  // SELECT id FROM users WHERE email = $1 (cek duplikat email)
  if (sql.includes('FROM USERS') && sql.includes('EMAIL =')) {
    const email = params[0]?.toLowerCase();
    const rows = mockDb.users.filter(u => u.email === email).map(u => ({ id: u.id }));
    return { rows, rowCount: rows.length };
  }

  // SELECT * FROM users WHERE id = $1
  if (sql.includes('FROM USERS') && (sql.includes('WHERE ID =') || sql.includes('WHERE U.ID ='))) {
    const id = params[0];
    const rows = mockDb.users.filter(u => u.id === id);
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO users
  if (sql.startsWith('INSERT INTO USERS') || (sql.includes('INSERT INTO') && sql.includes('USERS'))) {
    const [name, email, password_hash, role, phone] = params;
    const newUser = {
      id: generateMockId(),
      name, email: email?.toLowerCase(), password_hash,
      role: role || 'donatur', phone: phone || '',
      avatar_url: null, biometric_enabled: false,
      created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    };
    mockDb.users.push(newUser);
    return { rows: [newUser], rowCount: 1 };
  }

  // UPDATE users SET
  if (sql.includes('UPDATE USERS SET')) {
    const userId = params[params.length - 1];
    const userIdx = mockDb.users.findIndex(u => u.id === userId);
    if (userIdx >= 0) {
      if (sql.includes('NAME =')) mockDb.users[userIdx].name = params[0];
      if (sql.includes('PHONE =')) mockDb.users[userIdx].phone = params[1];
      if (sql.includes('BIOMETRIC_ENABLED')) mockDb.users[userIdx].biometric_enabled = params[0];
      if (sql.includes('AVATAR_URL')) mockDb.users[userIdx].avatar_url = params[0];
      return { rows: [mockDb.users[userIdx]], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  }

  // SELECT FROM sessions
  if (sql.includes('FROM SESSIONS') && sql.includes('REFRESH_HASH =')) {
    const hash = params[0]; const userId = params[1];
    const rows = mockDb.sessions.filter(s => s.refresh_hash === hash && s.user_id === userId);
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO sessions
  if (sql.includes('INSERT INTO SESSIONS')) {
    const [user_id, refresh_hash, device_info, ip_address, expires_at] = params;
    const session = { id: generateMockId(), user_id, refresh_hash, device_info, ip_address, is_revoked: false, expires_at, created_at: new Date().toISOString() };
    mockDb.sessions.push(session);
    return { rows: [session], rowCount: 1 };
  }

  // UPDATE sessions SET is_revoked
  if (sql.includes('UPDATE SESSIONS SET IS_REVOKED')) {
    const hash = params[0];
    mockDb.sessions.forEach(s => { if (s.refresh_hash === hash) s.is_revoked = true; });
    return { rows: [], rowCount: 1 };
  }

  // SELECT FROM orphanages
  if (sql.includes('FROM ORPHANAGES') && !sql.includes('JOIN')) {
    const rows = [...mockDb.orphanages];
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM children (dengan filter sederhana)
  if (sql.includes('FROM CHILDREN') || (sql.includes('FROM CHILDREN C') && sql.includes('JOIN ORPHANAGES'))) {
    let rows = mockDb.children.map(c => ({ ...c }));

    // Filter search alias
    if (params.length > 0) {
      params.forEach(p => {
        if (typeof p === 'string' && p.includes('%')) {
          const searchTerm = p.replace(/%/g, '').toLowerCase();
          if (searchTerm) rows = rows.filter(c => c.alias.toLowerCase().includes(searchTerm));
        }
        if (typeof p === 'string' && ['Tersedia','Disponsori','Nonaktif'].includes(p)) {
          rows = rows.filter(c => c.status === p);
        }
        if (typeof p === 'string' && ['Pendidikan','Kesehatan','Gizi','Umum'].includes(p)) {
          rows = rows.filter(c => c.need_category === p);
        }
      });
    } else {
      rows = rows.filter(c => c.status === 'Tersedia');
    }

    // Limit
    const limitIdx = params.findIndex(p => typeof p === 'number' && p <= 100);
    if (limitIdx >= 0) rows = rows.slice(0, params[limitIdx]);

    return { rows, rowCount: rows.length };
  }

  // INSERT INTO children (admin menambah anak baru)
  if (sql.includes('INSERT INTO CHILDREN') || (sql.includes('INSERT INTO') && sql.includes('CHILDREN'))) {
    const newChild = {
      id: generateMockId(),
      orphanage_id: params[0] || 'orp-001',
      alias: params[1] || 'Anak Baru',
      age: params[2] || 8,
      gender: params[3] || 'L',
      need_category: params[4] || 'Pendidikan',
      story_summary: params[5] || '',
      avatar: params[6] || '',
      status: 'Tersedia',
      orphanage_name: params[7] || 'Peduli Anak Foundation',
      orphanage_city: params[8] || 'Lombok',
      target: params[9] || 500000,
      dream: params[10] || '',
      hobby: params[11] || '',
      created_at: new Date().toISOString(),
    };
    mockDb.children.push(newChild);
    return { rows: [newChild], rowCount: 1 };
  }

  // SELECT COUNT(*) FROM children
  if (sql.includes('SELECT COUNT(*)') && sql.includes('CHILDREN')) {
    return { rows: [{ count: String(mockDb.children.length) }], rowCount: 1 };
  }

  // SELECT FROM sponsorship_packages
  if (sql.includes('FROM SPONSORSHIP_PACKAGES')) {
    let rows = [...mockDb.sponsorship_packages];
    const catParam = params.find(p => ['Pendidikan','Kesehatan','Gizi','Umum'].includes(p));
    if (catParam) rows = rows.filter(p => p.category === catParam || p.category === 'Umum');
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM sponsorships
  if (sql.includes('FROM SPONSORSHIPS') && sql.includes('USER_ID =')) {
    const userId = params[0];
    const rows = mockDb.sponsorships.filter(s => s.user_id === userId);
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO sponsorships
  if (sql.includes('INSERT INTO SPONSORSHIPS')) {
    const [user_id, child_id, package_id, frequency] = params;
    const pkg = mockDb.sponsorship_packages.find(p => p.id === package_id);
    const s = { id: generateMockId(), user_id, child_id, package_id, frequency, status: 'active', started_at: new Date().toISOString(), package_name: pkg?.name, amount_idr: pkg?.amount_idr };
    mockDb.sponsorships.push(s);
    return { rows: [s], rowCount: 1 };
  }

  // SELECT FROM donations
  if (sql.includes('FROM DONATIONS') && (sql.includes('USER_ID =') || sql.includes('D.USER_ID ='))) {
    const userId = params[0];
    const rows = mockDb.donations.filter(d => d.user_id === userId);
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM donations WHERE local_id
  if (sql.includes('FROM DONATIONS') && sql.includes('LOCAL_ID =')) {
    const localId = params[0];
    const rows = mockDb.donations.filter(d => d.local_id === localId);
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO donations
  if (sql.includes('INSERT INTO DONATIONS')) {
    const d = {
      id: generateMockId(),
      sponsorship_id: params[0], user_id: params[1],
      amount_original: params[2], currency: params[3],
      rate_used: params[4], amount_idr: params[5],
      source: params[6] || 'app', local_id: params[7],
      notes: params[8] || '', status: 'completed',
      created_at: new Date().toISOString(),
    };
    mockDb.donations.push(d);
    return { rows: [d], rowCount: 1 };
  }

  // SELECT COUNT(*) FROM donations
  if (sql.includes('SELECT COUNT(*)') && sql.includes('DONATIONS')) {
    const userId = params[0];
    const count = mockDb.donations.filter(d => d.user_id === userId).length;
    return { rows: [{ count: String(count) }], rowCount: 1 };
  }

  // SELECT FROM ledger_blocks ORDER BY block_index DESC LIMIT 1
  if (sql.includes('FROM LEDGER_BLOCKS') && sql.includes('LIMIT 1') && sql.includes('DESC')) {
    const blocks = [...mockDb.ledger_blocks].sort((a, b) => b.block_index - a.block_index);
    return { rows: blocks.slice(0, 1), rowCount: 1 };
  }

  // SELECT * FROM ledger_blocks ORDER BY block_index ASC (verifikasi)
  if (sql.includes('FROM LEDGER_BLOCKS') && sql.includes('ASC')) {
    const rows = [...mockDb.ledger_blocks].sort((a, b) => a.block_index - b.block_index);
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM ledger_blocks (general)
  if (sql.includes('FROM LEDGER_BLOCKS')) {
    const page = params[1] ? parseInt(params[1]) : 0;
    const limit = params[0] ? parseInt(params[0]) : 20;
    const rows = [...mockDb.ledger_blocks].sort((a, b) => b.block_index - a.block_index).slice(page, page + limit);
    return { rows, rowCount: rows.length };
  }

  // SELECT COUNT(*) FROM ledger_blocks
  if (sql.includes('SELECT COUNT(*)') && sql.includes('LEDGER_BLOCKS')) {
    return { rows: [{ count: String(mockDb.ledger_blocks.length) }], rowCount: 1 };
  }

  // INSERT INTO ledger_blocks
  if (sql.includes('INSERT INTO LEDGER_BLOCKS')) {
    const [block_index, block_type, ref_id, payload_hash, prev_hash, hash, created_at] = params;
    const block = { id: generateMockId(), block_index, block_type, ref_id, payload_hash, prev_hash, hash, created_at };
    mockDb.ledger_blocks.push(block);
    return { rows: [block], rowCount: 1 };
  }

  // SELECT FROM feedback
  if (sql.includes('FROM FEEDBACK') && sql.includes('USER_ID =')) {
    const userId = params[0];
    const rows = mockDb.feedback.filter(f => f.user_id === userId).sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO feedback
  if (sql.includes('INSERT INTO FEEDBACK')) {
    const f = { id: generateMockId(), user_id: params[0], suggestion: params[1], impression: params[2], created_at: new Date().toISOString() };
    mockDb.feedback.push(f);
    return { rows: [f], rowCount: 1 };
  }

  // SELECT FROM game_scores
  if (sql.includes('FROM GAME_SCORES') && sql.includes('USER_ID =')) {
    const userId = params[0];
    const rows = mockDb.game_scores.filter(g => g.user_id === userId);
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO game_scores
  if (sql.includes('INSERT INTO GAME_SCORES')) {
    const g = { id: generateMockId(), user_id: params[0], score: params[1], created_at: new Date().toISOString() };
    mockDb.game_scores.push(g);
    return { rows: [g], rowCount: 1 };
  }

  // Leaderboard
  if (sql.includes('FROM GAME_SCORES GS') || (sql.includes('GAME_SCORES') && sql.includes('GROUP BY'))) {
    const grouped = {};
    mockDb.game_scores.forEach(g => {
      if (!grouped[g.user_id]) { grouped[g.user_id] = { best_score: 0, total_score: 0, games_played: 0 }; }
      grouped[g.user_id].best_score = Math.max(grouped[g.user_id].best_score, g.score);
      grouped[g.user_id].total_score += g.score;
      grouped[g.user_id].games_played++;
    });
    const rows = Object.entries(grouped).map(([uid, stats]) => {
      const user = mockDb.users.find(u => u.id === uid);
      return { name: user?.name || 'Unknown', avatar_url: user?.avatar_url, ...stats };
    }).sort((a, b) => b.best_score - a.best_score).slice(0, 10);
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM step_logs
  if (sql.includes('FROM STEP_LOGS') && sql.includes('USER_ID =')) {
    const userId = params[0];
    const rows = mockDb.step_logs.filter(s => s.user_id === userId);
    return { rows, rowCount: rows.length };
  }

  // INSERT/UPSERT INTO step_logs
  if (sql.includes('INTO STEP_LOGS')) {
    const [user_id, log_date, steps, points] = params;
    const idx = mockDb.step_logs.findIndex(s => s.user_id === user_id && s.log_date === log_date);
    if (idx >= 0) {
      mockDb.step_logs[idx] = { ...mockDb.step_logs[idx], steps, points };
      return { rows: [mockDb.step_logs[idx]], rowCount: 1 };
    }
    const s = { id: generateMockId(), user_id, log_date, steps, points, created_at: new Date().toISOString() };
    mockDb.step_logs.push(s);
    return { rows: [s], rowCount: 1 };
  }

  // SELECT FROM iot_devices
  if (sql.includes('FROM IOT_DEVICES') && sql.includes('WHERE ID =')) {
    const id = params[0];
    const rows = mockDb.iot_devices.filter(d => d.id === id);
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM iot_events
  if (sql.includes('FROM IOT_EVENTS')) {
    const limit = params[0] ? parseInt(params[0]) : 20;
    const rows = [...mockDb.iot_events].sort((a,b) => new Date(b.created_at)-new Date(a.created_at)).slice(0, limit);
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO iot_events
  if (sql.includes('INSERT INTO IOT_EVENTS')) {
    const e = { id: generateMockId(), device_id: params[0], amount_sim: params[1], ledger_ref: null, created_at: new Date().toISOString() };
    mockDb.iot_events.push(e);
    return { rows: [e], rowCount: 1 };
  }

  // UPDATE iot_events SET ledger_ref
  if (sql.includes('UPDATE IOT_EVENTS SET LEDGER_REF')) {
    const [ledgerId, eventId] = params;
    const idx = mockDb.iot_events.findIndex(e => e.id === eventId);
    if (idx >= 0) mockDb.iot_events[idx].ledger_ref = ledgerId;
    return { rows: [], rowCount: 1 };
  }

  // SELECT FROM exchange_rates
  if (sql.includes('FROM EXCHANGE_RATES') && sql.includes('CURRENCY =')) {
    const currency = params[0];
    const rows = mockDb.exchange_rates.filter(r => r.currency === currency).map(r => ({ rate_to_idr: r.rate_to_idr, fetched_at: new Date().toISOString() }));
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM call_schedules
  if (sql.includes('FROM CALL_SCHEDULES') || sql.includes('CALL_SCHEDULES CS')) {
    const rows = mockDb.call_schedules;
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO call_schedules
  if (sql.includes('INSERT INTO CALL_SCHEDULES')) {
    const [sponsorship_id, scheduled_at_utc, donor_timezone, notes] = params;
    const s = { id: generateMockId(), sponsorship_id, scheduled_at_utc, donor_timezone, notes, status: 'scheduled', created_at: new Date().toISOString() };
    mockDb.call_schedules.push(s);
    return { rows: [s], rowCount: 1 };
  }

  // SELECT FROM letters WHERE user_id (with optional child_id filter)
  if (sql.includes('FROM LETTERS') && sql.includes('USER_ID =') && !sql.includes('INSERT') && !sql.includes('DELETE')) {
    const userId = params[0];
    let rows = mockDb.letters.filter(l => l.user_id === userId);
    // Filter by child_id jika ada
    if (params[1]) {
      rows = rows.filter(l => l.child_id === params[1]);
    }
    // Join dengan children untuk alias
    rows = rows.map(l => {
      const child = mockDb.children.find(c => c.id === l.child_id);
      return { ...l, child_alias: child?.alias || 'Unknown' };
    });
    rows.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return { rows, rowCount: rows.length };
  }

  // SELECT FROM letters WHERE id AND user_id (get by ID)
  if (sql.includes('FROM LETTERS') && sql.includes('WHERE L.ID =')) {
    const letterId = params[0]; const userId = params[1];
    let rows = mockDb.letters.filter(l => l.id === letterId && l.user_id === userId);
    rows = rows.map(l => {
      const child = mockDb.children.find(c => c.id === l.child_id);
      return { ...l, child_alias: child?.alias || 'Unknown' };
    });
    return { rows, rowCount: rows.length };
  }

  // INSERT INTO letters
  if (sql.includes('INSERT INTO LETTERS')) {
    const [user_id, child_id, content, ai_generated] = params;
    const l = { id: generateMockId(), user_id, child_id, content, ai_generated: ai_generated === true, created_at: new Date().toISOString() };
    mockDb.letters.push(l);
    return { rows: [l], rowCount: 1 };
  }

  // DELETE FROM letters WHERE id AND user_id
  if (sql.includes('DELETE FROM LETTERS')) {
    const letterId = params[0]; const userId = params[1];
    const idx = mockDb.letters.findIndex(l => l.id === letterId && l.user_id === userId);
    if (idx >= 0) {
      const deleted = mockDb.letters.splice(idx, 1);
      return { rows: [{ id: deleted[0].id }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  }

  // SELECT FROM children WHERE id (untuk validasi di letters controller)
  if (sql.includes('FROM CHILDREN') && sql.includes('WHERE ID =')) {
    const childId = params[0];
    const rows = mockDb.children.filter(c => c.id === childId);
    return { rows, rowCount: rows.length };
  }

  // SELECT NOW() — health check database
  if (sql.includes('SELECT NOW()')) {
    return { rows: [{ now: new Date().toISOString() }], rowCount: 1 };
  }

  // INSERT INTO progress_reports
  if (sql.includes('INSERT INTO PROGRESS_REPORTS')) {
    const r = { id: generateMockId(), child_id: params[0], period: params[1], summary: params[2], evidence_url: params[3], ledger_ref: null, created_at: new Date().toISOString() };
    return { rows: [r], rowCount: 1 };
  }

  // Default: kembalikan rows kosong
  console.log('[MOCK DB] Query tidak dikenali:', text.substring(0, 80));
  return { rows: [], rowCount: 0 };
};

// ============================================================
// EXPORT: Pool atau Mock tergantung kondisi
// ============================================================
let pool;
let query;

if (isMockMode) {
  // Mode MOCK: pakai in-memory data
  console.log('⚠️  [MOCK MODE] DATABASE_URL belum dikonfigurasi.');
  console.log('⚠️  Server berjalan dengan data IN-MEMORY (untuk demo/testing).');
  console.log('⚠️  Untuk koneksi nyata, isi DATABASE_URL di file .env dengan URL Supabase kamu.');
  console.log('');

  // Buat mock pool agar tidak error
  pool = {
    query: (text, params) => Promise.resolve(executeMockQuery(text, params)),
    on: () => {},
  };
  query = (text, params) => Promise.resolve(executeMockQuery(text, params));
} else {
  // Mode REAL: koneksi ke Supabase PostgreSQL
  pool = new Pool({
    connectionString: dbUrl,
    ssl: process.env.NODE_ENV === 'production'
      ? { rejectUnauthorized: true }
      : { rejectUnauthorized: false },
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
  });

  pool.on('connect', () => console.log('✅ Terhubung ke Supabase (PostgreSQL)'));
  pool.on('error', (err) => console.error('❌ Koneksi database error:', err.message));

  query = (text, params) => pool.query(text, params);
}

module.exports = { pool, query, isMockMode, mockDb };
