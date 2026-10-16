-- ============================================================
--  HOTEL MANAGEMENT SYSTEM  |  22AIE303 DBMS
--  ADVANCED SQL QUERIES  (documented, each with its purpose)
--  Run AFTER 01_schema.sql :   mysql -u root -p hotel_db < advanced_queries.sql
--  Every query below was executed against the sample data.
-- ============================================================
USE hotel_db;

-- ------------------------------------------------------------
-- Q1. MULTI-TABLE JOIN (4 tables)
-- Purpose: full booking register - guest, room, type, computed nights & bill.
-- (The same query powers the Bookings tab and the bill calculation.)
-- ------------------------------------------------------------
SELECT b.booking_id,
       CONCAT(g.first_name,' ',IFNULL(g.last_name,'')) AS guest,
       r.room_number, rt.room_type_name,
       b.check_in_date, b.check_out_date,
       DATEDIFF(b.check_out_date, b.check_in_date)                         AS nights,
       DATEDIFF(b.check_out_date, b.check_in_date) * rt.price_per_night    AS bill_amount,
       b.booking_status
FROM bookings b
JOIN guests     g  ON b.guest_id     = g.guest_id
JOIN rooms      r  ON b.room_id      = r.room_id
JOIN room_types rt ON r.room_type_id = rt.room_type_id
ORDER BY b.booking_id;

-- ------------------------------------------------------------
-- Q2. SUBQUERY (NOT IN) + date-overlap test
-- Purpose: rooms free for 2026-08-14 .. 2026-08-17 - not under maintenance
-- and with no active booking that overlaps the requested dates.
-- Overlap rule: existing.check_in < new.check_out AND existing.check_out > new.check_in
-- ------------------------------------------------------------
SELECT r.room_number, rt.room_type_name, rt.price_per_night
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
WHERE r.status <> 'Maintenance'
  AND r.room_id NOT IN (
        SELECT b.room_id FROM bookings b
        WHERE b.booking_status IN ('Booked','Checked-In')
          AND b.check_in_date  < '2026-08-17'
          AND b.check_out_date > '2026-08-14')
ORDER BY r.room_number;

-- ------------------------------------------------------------
-- Q3. CORRELATED SUBQUERY with EXISTS
-- Purpose: guests who still owe money (have at least one Pending payment).
-- ------------------------------------------------------------
SELECT g.guest_id, CONCAT(g.first_name,' ',IFNULL(g.last_name,'')) AS guest, g.phone
FROM guests g
WHERE EXISTS (SELECT 1
              FROM bookings b
              JOIN payments p ON p.booking_id = b.booking_id
              WHERE b.guest_id = g.guest_id
                AND p.payment_status = 'Pending');

-- ------------------------------------------------------------
-- Q4. GROUP BY + HAVING + aggregate functions
-- Purpose: revenue actually collected per room type, keeping only the
-- room types that earned more than Rs 5,000.
-- ------------------------------------------------------------
SELECT rt.room_type_name,
       COUNT(p.payment_id)  AS paid_transactions,
       SUM(p.amount)        AS revenue,
       ROUND(AVG(p.amount),2) AS avg_payment
FROM payments p
JOIN bookings   b  ON p.booking_id   = b.booking_id
JOIN rooms      r  ON b.room_id      = r.room_id
JOIN room_types rt ON r.room_type_id = rt.room_type_id
WHERE p.payment_status = 'Paid'
GROUP BY rt.room_type_name
HAVING SUM(p.amount) > 5000
ORDER BY revenue DESC;

-- ------------------------------------------------------------
-- Q5. CONDITIONAL AGGREGATION
-- Purpose: occupancy summary per room type with occupancy percentage.
-- ------------------------------------------------------------
SELECT rt.room_type_name,
       COUNT(*)                                          AS total_rooms,
       SUM(r.status = 'Occupied')                        AS occupied,
       SUM(r.status = 'Available')                       AS available,
       SUM(r.status = 'Maintenance')                     AS maintenance,
       ROUND(100 * SUM(r.status = 'Occupied') / COUNT(*), 1) AS occupancy_pct
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
GROUP BY rt.room_type_name
ORDER BY rt.room_type_name;

-- ------------------------------------------------------------
-- Q6. SCALAR SUBQUERY in HAVING-style filter
-- Purpose: bookings whose bill is above the average booking bill.
-- ------------------------------------------------------------
SELECT booking_id, guest_name, room_number, total_amount
FROM vw_booking_details
WHERE total_amount > (SELECT AVG(total_amount) FROM vw_booking_details)
ORDER BY total_amount DESC;

-- ------------------------------------------------------------
-- Q7. LEFT JOIN + IS NULL (anti-join)
-- Purpose: rooms that have never been booked.
-- ------------------------------------------------------------
SELECT r.room_number, rt.room_type_name, r.status
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
LEFT JOIN bookings b ON b.room_id = r.room_id
WHERE b.booking_id IS NULL
ORDER BY r.room_number;

-- ------------------------------------------------------------
-- Q8. WINDOW FUNCTION (RANK)  - requires MySQL 8.0+
-- Purpose: rank guests by the total they have paid.
-- ------------------------------------------------------------
SELECT CONCAT(g.first_name,' ',IFNULL(g.last_name,'')) AS guest,
       SUM(p.amount)                                   AS total_paid,
       RANK() OVER (ORDER BY SUM(p.amount) DESC)       AS paid_rank
FROM guests g
JOIN bookings b ON b.guest_id   = g.guest_id
JOIN payments p ON p.booking_id = b.booking_id
WHERE p.payment_status = 'Paid'
GROUP BY g.guest_id, guest
ORDER BY paid_rank;

-- ------------------------------------------------------------
-- Q9. VIEW usage
-- Purpose: live (non-closed) bookings through the pre-joined view.
-- ------------------------------------------------------------
SELECT booking_id, guest_name, room_number, nights, total_amount, booking_status
FROM vw_booking_details
WHERE booking_status IN ('Booked','Checked-In');

-- ------------------------------------------------------------
-- Q10. STORED PROCEDURE
-- Purpose: itemised bill for booking #4.
-- ------------------------------------------------------------
CALL sp_generate_bill(4);

-- ------------------------------------------------------------
-- Q11. TRANSACTION with ROLLBACK
-- Purpose: show atomicity - the insert is undone, row counts are unchanged.
-- ------------------------------------------------------------
SELECT COUNT(*) AS bookings_before FROM bookings;
START TRANSACTION;
  INSERT INTO bookings (guest_id, room_id, check_in_date, check_out_date,
                        number_of_guests, booking_date, booking_status)
  VALUES (1, 5, '2026-12-20', '2026-12-22', 2, CURDATE(), 'Booked');
  SELECT COUNT(*) AS bookings_inside_transaction FROM bookings;
ROLLBACK;
SELECT COUNT(*) AS bookings_after_rollback FROM bookings;
