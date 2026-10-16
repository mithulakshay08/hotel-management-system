# Hotel Management System — Setup & Review Guide

**22AIE303 DBMS | First Project Review**
Python (Tkinter) front end → `mysql-connector` → MySQL 8.0 back end

---

## 1. Setup (about 15 minutes)

### Step 1 — Install what you need

You need MySQL Server and Python 3. If MySQL isn't installed, get **MySQL Community Server + MySQL Workbench** from dev.mysql.com. During install, set a root password and **write it down**.

Then, in a terminal:

```bash
pip install mysql-connector-python
```

Tkinter ships with Python on Windows and macOS. On Ubuntu/Debian:

```bash
sudo apt install python3-tk
```

### Step 2 — Create the database

Put all the project files in one folder. From that folder:

```bash
mysql -u root -p < 01_schema.sql
```

Enter your root password when prompted. You should see `Database created successfully`, then `total_rooms = 10` and `total_bookings = 5`.

If `mysql` isn't a recognised command, open MySQL Workbench instead, click the SQL editor, open `01_schema.sql`, and press the lightning-bolt icon to run it.

### Step 3 — Point the app at your database

Open `db_config.py` and change one line:

```python
"password": "root",      # <-- put YOUR MySQL password here
```

### Step 4 — Run it

```bash
python app.py
```

Login with **admin / admin123**. (There's a second account, `reception / admin123`, for showing the Receptionist role.)

### If it doesn't connect

| Error | Fix |
|---|---|
| `Access denied for user 'root'` | Wrong password in `db_config.py` |
| `Unknown database 'hotel_db'` | Step 2 didn't run — re-run `01_schema.sql` |
| `Can't connect to MySQL server` | MySQL service isn't running. Windows: Services → MySQL80 → Start. Mac: `brew services start mysql`. Linux: `sudo systemctl start mysql` |
| `No module named 'mysql'` | Run `pip install mysql-connector-python` |
| `No module named 'tkinter'` | Linux only — `sudo apt install python3-tk` |

---

## 2. Files

| File | What it is |
|---|---|
| `01_schema.sql` | Full MySQL schema — 6 tables, constraints, 3 views, 4 triggers, 2 stored procedures, 4 indexes, sample data |
| `db_config.py` | Your MySQL credentials (the only file you edit) |
| `database.py` | Back end — every SQL statement in the project lives here |
| `app.py` | Front end — Tkinter GUI, login + 7 tabs |
| `ER_Diagram.pdf` | **Print this** — the required hard copy |
| `Use_Case_Diagram.pdf` | UML use case diagram |
| `Review1_Hotel_Management_System.pptx` | The review deck (speaker notes included) |
| `er_diagram.py`, `use_case.py` | Scripts that regenerate the two diagrams, if you need to edit them |

---

## 3. Before you leave for the review

- [ ] `ER_Diagram.pdf` printed (A4, colour if possible)
- [ ] Team number, names and roll numbers filled into **slide 1** of the deck
- [ ] App runs on **the laptop you're carrying** — test it there, not just on one machine
- [ ] MySQL service set to start automatically, or you know how to start it
- [ ] Deck exported to PDF as a backup in case PowerPoint misbehaves

---

## 4. Demo script (5 minutes, in this order)

The instructions say CRUD must be shown working in the application, not as screenshots. Run it in this sequence — each step sets up the next.

**1. Login** — type a wrong password first. It's rejected. Then log in properly.
> *"Passwords are stored as SHA-256 hashes, so the users table never holds plain text."*

**2. Dashboard** — point at the six cards.
> *"Each of these is a separate aggregate query — COUNT and SUM — running against the live database."*

**3. CREATE** — Guests tab → fill the form → Add. The new row appears in the table.
> Then try adding the **same phone number again**. It's rejected.
> *"That's the UNIQUE constraint on the phone column. The database refuses it, not the application."*

**4. READ + search** — type a few letters in the Guests search box. Rows filter live.
> *"That's a SELECT with a LIKE across five columns."*

**5. UPDATE** — click a guest row, change the email, click Update.

**6. The booking logic** — Bookings tab → pick your new guest → enter dates → **Find Available Rooms**.
> *"This runs a subquery that excludes any room with an overlapping booking, and any room under maintenance."*
> Book it. A message shows the total: nights × price per night.
> Now try to book **the same room for overlapping dates**. It's blocked.
> *"That's the date-overlap check — this is what prevents double booking."*

**7. Check-in / Check-out** — first look at the Rooms tab: the room you just booked is still **Available** (a future reservation doesn't occupy it). Select the booking → Check-In → Rooms tab shows **Occupied**. Then Check-Out → back to **Available**.
> *"The room status changes automatically — that's a trigger on the bookings table calling a stored procedure, not application code. It recomputes the status from the bookings, so it stays correct on cancel, delete, or moving a booking to another room. Rooms under Maintenance are never overwritten."*

**8. Payments** — select the booking → **Auto-Calculate Bill** → the amount fills in from a JOIN → Add.

**9. DELETE** — delete the payment. Then try to delete a **room type** that has rooms.
> *"Blocked by ON DELETE RESTRICT — referential integrity."*

**10. Reports** — run all four. Point out that these use GROUP BY, HAVING and aggregate functions.

**11. Code walkthrough** — open `database.py`.
> *"The GUI contains no SQL at all. Every query lives in this one file, and all of them are parameterised with placeholders, so the application isn't vulnerable to SQL injection."*

---

## 5. Likely viva questions

**Why is this in 3NF?**
Every non-key attribute depends on the whole primary key and nothing else. The room tariff is the clearest case — it lives in `ROOM_TYPES`, not on every room. If it were on `ROOMS`, changing the Deluxe rate would mean updating every Deluxe room, and they could drift out of sync. That's the transitive dependency 3NF removes.

**Why are there no many-to-many relationships?**
All four are 1:N, so the foreign key goes on the "many" side and no junction table is needed. If we later let one booking cover several rooms, that becomes M:N and would need a `BOOKING_ROOMS` junction table.

**Why a surrogate key instead of a natural key?**
Phone numbers and ID numbers change, and they're wide to index. An INT `AUTO_INCREMENT` key is stable, compact, and fast to join on. We still enforce the natural keys with UNIQUE constraints — `phone`, and the composite `(id_proof, id_number)`.

**How do you stop double booking?**
Two bookings overlap when `existing.check_in < new.check_out AND existing.check_out > new.check_in`. That test is a subquery run before every insert. Note that this is currently enforced in the application layer — moving it into a database trigger is on our Review 2 list.

**Difference between the trigger and the application logic?**
The trigger fires inside the database, so it holds even if someone inserts a row from the MySQL command line. Application checks only hold if the insert comes through our app. Database-level enforcement is stronger, which is why constraints do the heavy lifting here.

**How does the room-status trigger work?**
Three triggers on `bookings` (after insert, update, delete) call one stored procedure, `sp_refresh_room_status`. Instead of flipping the status by guesswork, the procedure recomputes it: a room is Occupied only if it has a Checked-In booking, otherwise Available, and Maintenance is never touched. That is why cancelling one booking can't wrongly free a room that another guest is staying in, and why moving a booking to a different room fixes both rooms.

**Why a trigger on `guests` as well?**
MySQL does not fire triggers for rows removed by `ON DELETE CASCADE`. So deleting a guest would silently delete their bookings and leave the room stuck Occupied. A BEFORE DELETE trigger on `guests` deletes their bookings explicitly first, which fires the booking-delete trigger.

**Why ENUM instead of a lookup table?**
The status values are fixed and few. If they needed to change without altering the schema, a lookup table with a foreign key would be the better choice — that's the trade-off.

**Why store the amount in PAYMENTS if it can be computed?**
Deliberate, controlled redundancy. The computed value uses today's tariff; the stored value records what the guest actually paid. If the rate changes later, historical bills stay correct.

**Where's the transaction control?**
Each operation commits atomically right now. Wrapping booking + payment in a single transaction with COMMIT/ROLLBACK is our Review 2 work.

---

## 6. If something breaks mid-demo

- **App freezes** — close it and rerun `python app.py`. Your data is in MySQL, not the app; nothing is lost.
- **A table looks stale** — hit Refresh, or switch tabs and back.
- **Database got messy while practising** — re-run `01_schema.sql`. It drops and recreates everything with fresh sample data. Do a practice run the night before, then reset.
