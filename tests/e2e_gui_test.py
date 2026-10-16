"""End-to-end GUI test: drives the real app.py classes against the live MySQL database.
Run (needs a display; on a headless box use xvfb):
    xvfb-run -a python tests/e2e_gui_test.py
Prerequisite: database/01_schema.sql loaded and src/db_config.py set. Prints PASS/FAIL per check."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "src")
sys.path.insert(0, SRC); os.chdir(SRC)
import tkinter as tk
from tkinter import messagebox
LOG = []
for n in ("showinfo", "showwarning", "showerror"):
    setattr(messagebox, n, (lambda nm: (lambda title, msg, **k: LOG.append((nm, title, msg))))(n))
messagebox.askyesno = lambda *a, **k: True
import app

if True:
    user = {"id": 1, "name": "admin", "role": "Admin"}
    m = app.MainApp(user)
    m.geometry("1180x680+0+0")
    m.update()
    # ---------------- end-to-end CRUD test through the app's own methods
    R = []
    def check(label, cond, detail=""):
        R.append((label, bool(cond), detail)); print(("PASS " if cond else "FAIL ") + label, detail)
    def last(): return LOG[-1] if LOG else None
    g = m.tab_guest
    g.e_fn.insert(0, "Demo"); g.e_ln.insert(0, "Guest"); g.cb_gender.set("Male")
    g.e_phone.insert(0, "9000000001"); g.e_email.insert(0, "demo@example.com")
    g.e_addr.insert(0, "1 Test Street, Coimbatore"); g.cb_idp.set("Aadhaar"); g.e_idn.insert(0, "9999-8888-7777")
    g.add(); check("CREATE guest", last()[0]=="showinfo" and "registered" in last()[2], last()[2])
    g.refresh()
    g.e_fn.delete(0,"end"); g.e_fn.insert(0,"Dup"); g.e_phone.delete(0,"end"); g.e_phone.insert(0,"9000000001")
    g.e_idn.delete(0,"end"); g.e_idn.insert(0,"1111")
    g.cb_gender.set("Male"); g.cb_idp.set("Aadhaar")
    g.add(); check("UNIQUE phone rejected by DB", last()[0]=="showerror", last()[2][:60].replace("\n"," "))
    g.clear()
    g.e_search.insert(0, "Demo"); g.do_search(); check("SEARCH guests", len(g.tree.get_children())==1)
    sel = g.tree.get_children()[0]; g.tree.selection_set(sel); g.update_idletasks(); m.update()
    g.e_email.delete(0,"end"); g.e_email.insert(0,"demo.new@example.com"); g.update(); check("UPDATE guest", last()[0]=="showinfo", last()[2])

    b = m.tab_book; b.refresh()
    b.cb_guest.set([k for k in b.guests if k.startswith("Demo")][0])
    b.e_cin.delete(0,"end"); b.e_cin.insert(0,"2026-11-10"); b.e_cout.delete(0,"end"); b.e_cout.insert(0,"2026-11-13")
    b.find_rooms(); check("Find Available Rooms", last()[1]=="Available Rooms", last()[2])
    room_label = [k for k in b.rooms if k.startswith("202")][0]; b.cb_room.set(room_label); b.e_pax.delete(0,"end"); b.e_pax.insert(0,"2")
    b.add(); check("BOOK room", last()[0]=="showinfo" and "Booking #" in last()[2], last()[2].replace("\n"," | "))
    b.refresh(); b.cb_guest.set([k for k in b.guests if k.startswith("Demo")][0]); b.cb_room.set(room_label)
    b.e_cin.delete(0,"end"); b.e_cin.insert(0,"2026-11-11"); b.e_cout.delete(0,"end"); b.e_cout.insert(0,"2026-11-12"); b.e_pax.delete(0,"end"); b.e_pax.insert(0,"1")
    b.add(); check("Double booking blocked", last()[1]=="Room Not Free", last()[2])
    b.clear(); b.refresh()
    top = b.tree.get_children()[0]; b.tree.selection_set(top); m.update()
    rn = b.tree.item(top)["values"][2]
    import database as db
    def room_status(num): return [r[5] for r in db.get_rooms() if str(r[1])==str(num)][0]
    check("Room Available after future booking", room_status(rn)=="Available", f"room {rn}")
    b.status("Checked-In"); check("Room Occupied after Check-In (trigger)", room_status(rn)=="Occupied", f"room {rn}")
    b.tree.selection_set(b.tree.get_children()[0]); m.update(); b.status("Checked-Out")
    check("Room Available after Check-Out (trigger)", room_status(rn)=="Available", f"room {rn}")

    p = m.tab_pay; p.refresh()
    p.cb_book.set(list(p.bookings.keys())[0]); p.auto_bill(); amt = p.e_amt.get()
    p.cb_method.set("UPI"); p.add(); check("Auto-calc bill + payment", last()[0]=="showinfo" and float(amt)>0, f"Rs {amt}")
    p.refresh()
    pid = p.tree.get_children()[0]; p.tree.selection_set(pid); m.update(); p.delete(); check("DELETE payment", last()[2]=="Deleted")

    rt = m.tab_rt; rt.refresh(); rt.tree.selection_set(rt.tree.get_children()[0]); m.update()
    rt.delete(); check("FK RESTRICT blocks room-type delete", last()[0]=="showerror", "")

    # delete test guest -> bookings removed, rooms freed
    g.clear(); g.e_search.delete(0,"end"); g.e_search.insert(0,"Demo"); g.do_search()
    g.tree.selection_set(g.tree.get_children()[0]); m.update(); g.delete(); check("DELETE guest (cascade)", last()[2]=="Deleted")
    for nm in range(4):
        m.tab_rep.cb.current(nm)
        try:
            m.tab_rep.generate(); check("Report: "+m.tab_rep.cb.get(), True, f"{len(m.tab_rep.tree.get_children())} rows")
        except Exception as e: check("Report "+str(nm), False, str(e))
    with open(os.path.join(HERE,"e2e_results.txt"), "w") as f:
        for l, ok, d in R: f.write(f"{'PASS' if ok else 'FAIL'} | {l} | {d}\n")
    print("TOTAL", sum(1 for r in R if r[1]), "/", len(R))
    m.destroy()
