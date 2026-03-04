#!/usr/bin/env python3
import os
import sys
import random
import shutil
import subprocess
import tkinter as tk
from tkinter import ttk

from pynput.mouse import Controller

# =========================
# Windows DPI awareness (evita mismatch coordinate con scaling 125%/150%)
# =========================
if sys.platform.startswith("win"):
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(2)  # PER_MONITOR_AWARE
    except Exception:
        try:
            import ctypes
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass


# =========================
# Windows WinAPI picker
# =========================
class WinWindowPicker:
    def __init__(self):
        import ctypes
        from ctypes import wintypes

        self.ctypes = ctypes
        self.wintypes = wintypes
        self.user32 = ctypes.windll.user32

        class POINT(ctypes.Structure):
            _fields_ = [("x", wintypes.LONG), ("y", wintypes.LONG)]

        class RECT(ctypes.Structure):
            _fields_ = [("left", wintypes.LONG),
                        ("top", wintypes.LONG),
                        ("right", wintypes.LONG),
                        ("bottom", wintypes.LONG)]

        self.POINT = POINT
        self.RECT = RECT
        self.GA_ROOT = 2  # GetAncestor

    def _get_cursor_pos(self):
        pt = self.POINT()
        if not self.user32.GetCursorPos(self.ctypes.byref(pt)):
            raise OSError("GetCursorPos fallita")
        return pt.x, pt.y

    def _window_from_point(self, x, y):
        pt = self.POINT(x, y)
        return self.user32.WindowFromPoint(pt)

    def _get_root_hwnd(self, hwnd):
        if not hwnd:
            return 0
        root = self.user32.GetAncestor(hwnd, self.GA_ROOT)
        return root if root else hwnd

    def is_valid_target(self, hwnd) -> bool:
        if not hwnd:
            return False
        if not self.user32.IsWindow(hwnd):
            return False
        if not self.user32.IsWindowVisible(hwnd):
            return False
        if self.user32.IsIconic(hwnd):  # minimizzata
            return False
        return True

    def get_window_title(self, hwnd) -> str:
        if not hwnd:
            return ""
        length = self.user32.GetWindowTextLengthW(hwnd)
        buf = self.ctypes.create_unicode_buffer(length + 1)
        self.user32.GetWindowTextW(hwnd, buf, length + 1)
        return buf.value

    def pick_window_under_cursor(self):
        x, y = self._get_cursor_pos()
        hwnd = self._window_from_point(x, y)
        hwnd = self._get_root_hwnd(hwnd)
        if not self.is_valid_target(hwnd):
            return 0, ""
        return hwnd, self.get_window_title(hwnd)

    def get_client_area_screen_rect(self, hwnd):
        """
        (left, top, right, bottom) della *client area* in coordinate schermo.
        """
        if not self.is_valid_target(hwnd):
            raise ValueError("Finestra non valida/visibile")

        rect = self.RECT()
        if not self.user32.GetClientRect(hwnd, self.ctypes.byref(rect)):
            raise OSError("GetClientRect fallita")

        tl = self.POINT(rect.left, rect.top)
        br = self.POINT(rect.right, rect.bottom)

        if not self.user32.ClientToScreen(hwnd, self.ctypes.byref(tl)):
            raise OSError("ClientToScreen(tl) fallita")
        if not self.user32.ClientToScreen(hwnd, self.ctypes.byref(br)):
            raise OSError("ClientToScreen(br) fallita")

        return tl.x, tl.y, br.x, br.y


# =========================
# Linux X11 picker via xdotool (best-effort)
# =========================
class X11WindowPicker:
    def __init__(self):
        if shutil.which("xdotool") is None:
            raise RuntimeError("xdotool non trovato nel PATH")

    def _run(self, *args: str) -> str:
        proc = subprocess.run(
            ["xdotool", *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or f"xdotool errore (rc={proc.returncode})")
        return proc.stdout

    def pick_window_under_cursor(self):
        """
        Usa: xdotool getmouselocation --shell  -> WINDOW=...
        """
        out = self._run("getmouselocation", "--shell")
        data = {}
        for line in out.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                data[k.strip()] = v.strip()

        wid = data.get("WINDOW")
        if not wid:
            return 0, ""

        # Nome finestra (può fallire per certe finestre; gestiamo fallback)
        title = ""
        try:
            title = self._run("getwindowname", wid).strip()
        except Exception:
            title = f"X11_WINDOW={wid}"

        return int(wid), title

    def get_window_rect(self, wid: int):
        """
        Ritorna (left, top, right, bottom) della *window geometry*.
        Nota: su X11 questa geometry è "best-effort" e può includere o meno decorazioni
        a seconda di WM/compositor. È comunque sufficiente per limitare un random-move.
        """
        out = self._run("getwindowgeometry", "--shell", str(wid))
        data = {}
        for line in out.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                data[k.strip()] = v.strip()

        x = int(data["X"])
        y = int(data["Y"])
        w = int(data["WIDTH"])
        h = int(data["HEIGHT"])
        return x, y, x + w, y + h


# =========================
# App
# =========================
class NotAFKAgentGUI:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("NotAFKAgent")
        self.root.resizable(False, False)

        self.mouse = Controller()
        self.enabled = tk.BooleanVar(value=False)
        self.minutes_var = tk.StringVar(value="5")
        self.status_var = tk.StringVar(value="OFF")
        self.window_var = tk.StringVar(value="Nessuna finestra selezionata")

        self.after_id = None
        self.last_pos = None

        self.target_id = 0          # hwnd su Windows, window id su X11
        self.target_title = ""
        self.target_mode = "screen" # "screen" | "window-client" (win) | "window-rect" (x11)

        self.session = os.environ.get("XDG_SESSION_TYPE", "").lower()  # x11/wayland su Linux
        self.is_windows = sys.platform.startswith("win")

        # Selettore finestre: priorità Windows; su Linux solo X11 + xdotool
        self.picker = None
        self.window_feature_available = False
        self.window_feature_reason = ""

        if self.is_windows:
            self.picker = WinWindowPicker()
            self.window_feature_available = True
            self.target_mode = "window-client"
        else:
            if self.session == "x11":
                try:
                    self.picker = X11WindowPicker()
                    self.window_feature_available = True
                    self.target_mode = "window-rect"
                except Exception as e:
                    self.window_feature_reason = str(e)
            else:
                self.window_feature_reason = "Wayland rilevato: selezione finestra non garantibile (fallback a schermo)."

        # UI
        main = ttk.Frame(root, padding=12)
        main.grid(row=0, column=0)

        ttk.Checkbutton(
            main, text="Attivo",
            variable=self.enabled,
            command=self.on_toggle
        ).grid(row=0, column=0, sticky="w")

        ttk.Label(main, text="Minuti:").grid(row=1, column=0, sticky="w", pady=(10, 0))
        vcmd = (root.register(self._validate_digits), "%P")
        ttk.Entry(
            main, textvariable=self.minutes_var,
            width=10, validate="key", validatecommand=vcmd
        ).grid(row=2, column=0, sticky="w")

        self.pick_btn = ttk.Button(main, text="Seleziona finestra", command=self.begin_pick_window)
        self.pick_btn.grid(row=3, column=0, sticky="w", pady=(10, 0))

        ttk.Label(main, textvariable=self.window_var).grid(row=4, column=0, sticky="w", pady=(6, 0))
        ttk.Label(main, textvariable=self.status_var).grid(row=5, column=0, sticky="w", pady=(10, 0))

        if not self.window_feature_available:
            self.pick_btn.state(["disabled"])
            if self.window_feature_reason:
                ttk.Label(main, text=self.window_feature_reason, foreground="orange") \
                    .grid(row=6, column=0, sticky="w", pady=(6, 0))

        for child in main.winfo_children():
            child.grid_configure(padx=2)

    def _validate_digits(self, proposed: str) -> bool:
        return proposed == "" or proposed.isdigit()

    def _get_minutes_or_disable(self):
        raw = self.minutes_var.get().strip()
        if not raw:
            self.status_var.set("OFF — inserisci minuti > 0")
            self.enabled.set(False)
            return None
        minutes = int(raw)
        if minutes <= 0:
            self.status_var.set("OFF — minuti devono essere > 0")
            self.enabled.set(False)
            return None
        return minutes

    # -------------------------
    # Selezione finestra
    # -------------------------
    def begin_pick_window(self):
        if not self.window_feature_available:
            return
        self.status_var.set("Selezione: metti il mouse sopra la finestra target… catturo tra 3 secondi")
        self.root.after(3000, self.finish_pick_window)

    def finish_pick_window(self):
        try:
            wid, title = self.picker.pick_window_under_cursor()
        except Exception as e:
            self.status_var.set(f"Errore selezione finestra: {e}")
            return

        if not wid:
            self.target_id = 0
            self.target_title = ""
            self.window_var.set("Nessuna finestra selezionata")
            self.status_var.set("Selezione fallita: hover su una finestra visibile e riprova")
            return

        self.target_id = wid
        self.target_title = title or f"ID={wid}"
        self.window_var.set(f"Target: {self.target_title}")

        if self.is_windows:
            self.status_var.set("Finestra selezionata (Windows: client area).")
        else:
            self.status_var.set("Finestra selezionata (Linux X11: window geometry).")

    # -------------------------
    # Loop principale
    # -------------------------
    def on_toggle(self):
        if self.enabled.get():
            minutes = self._get_minutes_or_disable()
            if minutes is None:
                return
            self.last_pos = self.mouse.position
            self.status_var.set(f"ON — baseline={self.last_pos} — ogni {minutes} min")
            self._schedule_check(minutes)
        else:
            self._stop()

    def _schedule_check(self, minutes: int):
        if self.after_id is not None:
            self.root.after_cancel(self.after_id)
        self.after_id = self.root.after(minutes * 60 * 1000, self._check_and_act)

    def _random_point_in_target(self):
        margin = 20

        # 1) Se c'è un target finestra, prova a calcolare rect aggiornato
        if self.target_id:
            if self.is_windows:
                l, t, r, b = self.picker.get_client_area_screen_rect(self.target_id)
            else:
                # X11 best-effort rect
                l, t, r, b = self.picker.get_window_rect(self.target_id)

            w = max(0, r - l)
            h = max(0, b - t)
            if w < (margin * 2 + 1) or h < (margin * 2 + 1):
                raise ValueError("Area target troppo piccola per il margin")

            x = random.randint(l + margin, r - margin - 1)
            y = random.randint(t + margin, b - margin - 1)
            return x, y, True

        # 2) Fallback: schermo intero
        w = self.root.winfo_screenwidth()
        h = self.root.winfo_screenheight()
        x = random.randint(margin, max(margin, w - margin - 1))
        y = random.randint(margin, max(margin, h - margin - 1))
        return x, y, False

    def _check_and_act(self):
        if not self.enabled.get():
            return

        minutes = self._get_minutes_or_disable()
        if minutes is None:
            return

        try:
            cur_pos = self.mouse.position
        except Exception as e:
            self.status_var.set(f"Errore lettura mouse: {e}")
            self.enabled.set(False)
            return

        if self.last_pos is not None and cur_pos == self.last_pos:
            try:
                x, y, in_window = self._random_point_in_target()
                self.mouse.position = (x, y)
                new_pos = self.mouse.position
                self.last_pos = new_pos

                scope = "finestra" if in_window else "schermo"
                self.status_var.set(f"ON — fermo: {cur_pos} → {new_pos} (dentro {scope}) — ogni {minutes} min")
            except Exception as e:
                # se il target non è più valido (chiuso, ecc.), reset
                if self.target_id:
                    self.target_id = 0
                    self.target_title = ""
                    self.window_var.set("Nessuna finestra selezionata (target non più valido)")
                self.status_var.set(f"Errore movimento: {e}")
        else:
            self.last_pos = cur_pos
            self.status_var.set(f"ON — mosso: baseline={cur_pos} — ogni {minutes} min")

        self._schedule_check(minutes)

    def _stop(self):
        if self.after_id is not None:
            self.root.after_cancel(self.after_id)
            self.after_id = None
        self.status_var.set("OFF")
        self.last_pos = None


def main():
    root = tk.Tk()
    try:
        ttk.Style().theme_use("clam")
    except Exception:
        pass
    NotAFKAgentGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
