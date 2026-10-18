"""Export maps to T3D and run UnrealEd macros in MobileForcesEd.exe, which has no headless mode.

    python mfed.py export <map>.umf <outdir>
        UCC batchexport of the level to <outdir>/MyLevel.t3d
    python mfed.py run <macro.txt> <map>.umf [files...]
        Copies the macro and files to <game>/MapBuild (the macro refers to them as ..\\MapBuild\\<name>;
        the editor truncates FILE= paths at ~64 characters), starts the editor, types EXEC into its
        command bar and waits until the macro's MAP SAVE has written Maps/<map>.umf.

Standard library only. It drives Windows programs through Win32 calls, so it needs a Windows Python:
native, or one installed under Wine and started with `wine python mfed.py ...` (untested; UCC
batchexport is known to crash under Wine).
"""
import ctypes, os, shutil, subprocess, sys, time
from ctypes import wintypes

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
STAGE = os.path.join(GAME, 'MapBuild')
kernel32 = ctypes.windll.kernel32
user32 = ctypes.windll.user32


def short(path):
    """8.3 path: UCC and the editor split their command lines at the space in 'Mobile Forces'."""
    buf = ctypes.create_unicode_buffer(260)
    kernel32.GetShortPathNameW(path, buf, len(buf))
    return buf.value


def export(map_name, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    system = short(os.path.join(GAME, 'System'))
    subprocess.run([system + r'\UCC.exe', 'batchexport', '..\\Maps\\' + map_name, 'Level', 't3d',
                    short(os.path.abspath(out_dir))], cwd=system, check=True)


def command_bar(pid):
    """The editor's command bar: an Edit (id 1001) inside the combobox with id 19501."""
    found = []
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def child(h, _):
        name = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(h, name, 64)
        if name.value == 'Edit' and user32.GetDlgCtrlID(h) == 1001 and \
                user32.GetDlgCtrlID(user32.GetParent(h)) == 19501:
            found.append(h)
            return False
        return True

    def top(h, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(owner))
        if owner.value == pid:
            user32.EnumChildWindows(h, proc(child), 0)
        return not found

    user32.EnumWindows(proc(top), 0)
    return found[0] if found else None


def run(macro, map_name, files, timeout=900):
    os.makedirs(STAGE, exist_ok=True)
    for f in [macro] + files:
        shutil.copy(f, STAGE)
    out = os.path.join(GAME, 'Maps', map_name)
    started = time.time()
    system = short(os.path.join(GAME, 'System'))
    editor = subprocess.Popen([system + r'\MobileForcesEd.exe'], cwd=system)
    try:
        bar = None
        for _ in range(60):
            time.sleep(1)
            bar = command_bar(editor.pid)
            if bar:
                break
        if not bar:
            sys.exit('Editor command bar not found')
        time.sleep(5)   # let the editor finish loading
        WM_SETTEXT, WM_KEYDOWN, WM_CHAR, WM_KEYUP, VK_RETURN = 0x0C, 0x100, 0x102, 0x101, 0x0D
        user32.SendMessageW(bar, WM_SETTEXT, 0, ctypes.c_wchar_p('EXEC ..\\MapBuild\\' + os.path.basename(macro)))
        user32.PostMessageW(bar, WM_KEYDOWN, VK_RETURN, 0x001C0001)
        user32.PostMessageW(bar, WM_CHAR, VK_RETURN, 0x001C0001)
        user32.PostMessageW(bar, WM_KEYUP, VK_RETURN, 0xC01C0001)
        # MAP SAVE writes Maps/Save.tmp and moves it over the map, so a newer map means it's done
        while not (os.path.exists(out) and os.path.getmtime(out) > started):
            if editor.poll() is not None:
                sys.exit('Editor exited before saving; see System/Editor.log')
            if time.time() - started > timeout:
                sys.exit('No save within %d s; see System/Editor.log' % timeout)
            time.sleep(5)
        print('Saved', out)
    finally:
        if editor.poll() is None:
            editor.kill()
        shutil.rmtree(STAGE)


if __name__ == '__main__':
    if len(sys.argv) >= 4 and sys.argv[1] == 'export':
        export(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 4 and sys.argv[1] == 'run':
        run(sys.argv[2], sys.argv[3], sys.argv[4:])
    else:
        sys.exit(__doc__)
