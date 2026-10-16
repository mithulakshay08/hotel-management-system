USE hotel_db;
SELECT 'T0 after load (101 Occupied, 201/401 Available since only Booked)' t;
SELECT room_number,status FROM rooms WHERE room_number IN ('101','201','401','103') ORDER BY 1;
-- Gap1: future booking must not occupy
INSERT INTO bookings(guest_id,room_id,check_in_date,check_out_date,number_of_guests,booking_date,booking_status) VALUES (1,5,'2026-12-01','2026-12-03',1,CURDATE(),'Booked');
SELECT 'Gap1 room 202 should be Available' t, status FROM rooms WHERE room_id=5;
SET @b=LAST_INSERT_ID();
UPDATE bookings SET booking_status='Checked-In' WHERE booking_id=@b;
SELECT 'Check-in: 202 Occupied' t, status FROM rooms WHERE room_id=5;
-- Gap3: move booking to another room
UPDATE bookings SET room_id=7 WHERE booking_id=@b;
SELECT 'Gap3 old 202 Available, new 302 Occupied' t,(SELECT status FROM rooms WHERE room_id=5) old_room,(SELECT status FROM rooms WHERE room_id=7) new_room;
-- Gap4: second active booking on same room (non-overlapping) then cancel the checked-in one
INSERT INTO bookings(guest_id,room_id,check_in_date,check_out_date,number_of_guests,booking_date,booking_status) VALUES (2,7,'2027-01-10','2027-01-12',1,CURDATE(),'Booked');
UPDATE bookings SET booking_status='Cancelled' WHERE booking_id=@b;
SELECT 'Gap4 302 Available after cancel (other is only Booked)' t,status FROM rooms WHERE room_id=7;
-- Gap4b: two Checked-In style: check-in second, add a Checked-In on same room, cancel one -> stays Occupied
SET @c=LAST_INSERT_ID();
UPDATE bookings SET booking_status='Checked-In' WHERE booking_id=@c;
UPDATE bookings SET booking_status='Booked' WHERE booking_id=@b;  -- reopen first
UPDATE bookings SET booking_status='Checked-In' WHERE booking_id=@b;
UPDATE bookings SET booking_status='Cancelled' WHERE booking_id=@b;
SELECT 'Gap4b 302 still Occupied (other guest Checked-In)' t,status FROM rooms WHERE room_id=7;
-- Gap2: delete the checked-in booking
DELETE FROM bookings WHERE booking_id=@c;
SELECT 'Gap2 302 Available after delete' t,status FROM rooms WHERE room_id=7;
-- Maintenance never overwritten
INSERT INTO bookings(guest_id,room_id,check_in_date,check_out_date,number_of_guests,booking_date,booking_status) VALUES (3,3,'2027-02-01','2027-02-02',1,CURDATE(),'Checked-In');
UPDATE bookings SET booking_status='Checked-Out' WHERE room_id=3;
SELECT 'Maintenance 103 stays Maintenance' t,status FROM rooms WHERE room_id=3;
-- Guest delete cascade frees room (guest 1 has Checked-In booking on room 1)
SELECT 'before guest delete: 101' t,status FROM rooms WHERE room_id=1;
DELETE FROM guests WHERE guest_id=1;
SELECT 'Guest delete: 101 Available' t,status FROM rooms WHERE room_id=1;
SELECT 'payments left for deleted guest bookings' t, COUNT(*) FROM payments WHERE booking_id=1;
-- Bill procedure still works
CALL sp_generate_bill(2);
