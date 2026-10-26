



const { query } = require('../config/database');











const getNearbyOrphanages = async (req, res, next) => {
  try {
    const { lat, lng, radius = 50 } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({
        success: false,
        message: 'Parameter lat (latitude) dan lng (longitude) wajib diisi.',
        error: 'MISSING_COORDINATES',
      });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const radiusKm = parseFloat(radius);

    if (isNaN(latitude) || isNaN(longitude)) {
      return res.status(400).json({
        success: false,
        message: 'Koordinat tidak valid.',
        error: 'INVALID_COORDINATES',
      });
    }



    const result = await query(
      `SELECT id, name, city, address, latitude, longitude, phone, description,
              ROUND(
                (6371 * acos(
                  LEAST(1.0, cos(radians($1)) * cos(radians(latitude))
                  * cos(radians(longitude) - radians($2))
                  + sin(radians($1)) * sin(radians(latitude)))
                ))::numeric, 2
              ) AS distance_km
       FROM orphanages
       WHERE latitude IS NOT NULL AND longitude IS NOT NULL
       HAVING ROUND((6371 * acos(
                  LEAST(1.0, cos(radians($1)) * cos(radians(latitude))
                  * cos(radians(longitude) - radians($2))
                  + sin(radians($1)) * sin(radians(latitude)))
                ))::numeric, 2) <= $3
       ORDER BY distance_km ASC`,
      [latitude, longitude, radiusKm]
    ).catch(async () => {

      return await query(
        `SELECT * FROM (
           SELECT id, name, city, address, latitude, longitude, phone, description,
                  ROUND(
                    (6371 * acos(
                      LEAST(1.0, cos(radians($1)) * cos(radians(latitude))
                      * cos(radians(longitude) - radians($2))
                      + sin(radians($1)) * sin(radians(latitude)))
                    ))::numeric, 2
                  ) AS distance_km
           FROM orphanages
           WHERE latitude IS NOT NULL AND longitude IS NOT NULL
         ) AS sub
         WHERE distance_km <= $3
         ORDER BY distance_km ASC`,
        [latitude, longitude, radiusKm]
      );
    });

    return res.status(200).json({
      success: true,
      data: result.rows,
      meta: {
        user_location: { latitude, longitude },
        radius_km: radiusKm,
        total_found: result.rows.length,
      },
    });
  } catch (err) {
    next(err);
  }
};





const getAllOrphanages = async (req, res, next) => {
  try {
    const result = await query(
      'SELECT id, name, city, address, latitude, longitude, phone, description FROM orphanages ORDER BY name ASC'
    );

    return res.status(200).json({ success: true, data: result.rows });
  } catch (err) {
    next(err);
  }
};






const checkIn = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { lat, lng } = req.body;

    if (!lat || !lng) {
      return res.status(400).json({
        success: false,
        message: 'Koordinat lokasi saat ini wajib disertakan.',
        error: 'MISSING_COORDINATES',
      });
    }

    const orphanageResult = await query(
      'SELECT id, name, latitude, longitude FROM orphanages WHERE id = $1',
      [id]
    );

    if (orphanageResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Panti tidak ditemukan.', error: 'NOT_FOUND' });
    }

    const orphanage = orphanageResult.rows[0];

    if (!orphanage.latitude || !orphanage.longitude) {
      return res.status(400).json({
        success: false,
        message: 'Koordinat panti ini belum tersedia.',
        error: 'ORPHANAGE_NO_COORDINATES',
      });
    }


    const R = 6371000;
    const dLat = (orphanage.latitude - parseFloat(lat)) * Math.PI / 180;
    const dLng = (orphanage.longitude - parseFloat(lng)) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 +
              Math.cos(parseFloat(lat) * Math.PI / 180) *
              Math.cos(orphanage.latitude * Math.PI / 180) *
              Math.sin(dLng / 2) ** 2;
    const distanceMeters = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    const isWithinRadius = distanceMeters <= 100;

    return res.status(200).json({
      success: true,
      data: {
        orphanage_name: orphanage.name,
        distance_meters: Math.round(distanceMeters),
        is_within_100m: isWithinRadius,
        check_in_valid: isWithinRadius,
        message: isWithinRadius
          ? `Check-in berhasil! Kamu berada ${Math.round(distanceMeters)} meter dari ${orphanage.name}.`
          : `Check-in gagal. Kamu berada ${Math.round(distanceMeters)} meter dari panti. Harus dalam 100 meter.`,
      },
    });
  } catch (err) {
    next(err);
  }
};








const createSchedule = async (req, res, next) => {
  try {
    const { sponsorship_id, scheduled_at_utc, donor_timezone, notes } = req.body;

    if (!sponsorship_id || !scheduled_at_utc) {
      return res.status(400).json({
        success: false,
        message: 'sponsorship_id dan scheduled_at_utc wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }


    const scheduledDate = new Date(scheduled_at_utc);
    if (isNaN(scheduledDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'Format tanggal tidak valid. Gunakan format ISO 8601 (contoh: 2026-10-25T10:00:00Z)',
        error: 'INVALID_DATE',
      });
    }

    if (scheduledDate < new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Jadwal tidak boleh di masa lalu.',
        error: 'DATE_IN_PAST',
      });
    }

    const result = await query(
      `INSERT INTO call_schedules (sponsorship_id, scheduled_at_utc, donor_timezone, notes)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [sponsorship_id, scheduledDate.toISOString(), donor_timezone || 'Asia/Jakarta', notes || '']
    );

    const schedule = result.rows[0];




    const utcTime = new Date(schedule.scheduled_at_utc);
    const timezones = convertToFourTimezones(utcTime);

    return res.status(201).json({
      success: true,
      message: 'Jadwal video call berhasil dibuat.',
      data: {
        schedule,
        display_times: timezones,
      },
    });
  } catch (err) {
    next(err);
  }
};






const getSchedules = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT cs.*, c.alias AS child_alias, o.name AS orphanage_name
       FROM call_schedules cs
       JOIN sponsorships s ON cs.sponsorship_id = s.id
       JOIN children c ON s.child_id = c.id
       JOIN orphanages o ON c.orphanage_id = o.id
       WHERE s.user_id = $1
       ORDER BY cs.scheduled_at_utc ASC`,
      [req.user.id]
    );


    const schedulesWithTimezones = result.rows.map(s => ({
      ...s,
      display_times: convertToFourTimezones(new Date(s.scheduled_at_utc)),
    }));

    return res.status(200).json({
      success: true,
      data: schedulesWithTimezones,
    });
  } catch (err) {
    next(err);
  }
};






const convertToFourTimezones = (utcDate) => {
  const format = (d) => d.toISOString().replace('T', ' ').substring(0, 16) + ' ';



  const month = utcDate.getUTCMonth();
  const londonOffset = (month >= 2 && month <= 9) ? 60 : 0;

  const addMinutes = (date, minutes) => new Date(date.getTime() + minutes * 60000);

  return {
    WIB: {
      label: 'WIB (Asia/Jakarta)',
      offset: '+07:00',
      time: format(addMinutes(utcDate, 420)),
    },
    WITA: {
      label: 'WITA (Asia/Makassar)',
      offset: '+08:00',
      time: format(addMinutes(utcDate, 480)),
    },
    WIT: {
      label: 'WIT (Asia/Jayapura)',
      offset: '+09:00',
      time: format(addMinutes(utcDate, 540)),
    },
    London: {
      label: londonOffset > 0 ? 'London (BST/UTC+1)' : 'London (GMT/UTC+0)',
      offset: londonOffset > 0 ? '+01:00' : '+00:00',
      time: format(addMinutes(utcDate, londonOffset)),
      is_dst: londonOffset > 0,
    },
  };
};

module.exports = { getNearbyOrphanages, getAllOrphanages, checkIn, createSchedule, getSchedules };
