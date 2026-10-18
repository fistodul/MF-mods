"""Read Mobile Forces (UE1) package tables: .u, .umf, .utx, .uax, .umx.

Usage, from the game root:
  python .agents/tools/upkg.py info <file>              header, exports by class, imported packages
  python .agents/tools/upkg.py exports <file> [Class]   exported objects, optionally of one class
  python .agents/tools/upkg.py classes <Package>...     classes in System/<Package>.u vs <Package>/Classes/*.uc
  python .agents/tools/upkg.py refs <Package>           files that import objects from <Package>

Only the name, export and import tables are parsed; object data is not.
"""
import glob, os, struct, sys
from collections import Counter

SCAN = ('System/*.u', 'Maps/*.umf', 'Textures/*.utx', 'Sounds/*.uax', 'Music/*.umx')


def compact(b, p):
    x = b[p]; p += 1
    neg = x & 0x80; v = x & 0x3F
    if x & 0x40:
        sh = 6
        while True:
            x = b[p]; p += 1
            v |= (x & 0x7F) << sh; sh += 7
            if not x & 0x80:
                break
    return (-v if neg else v), p


class Package:
    def __init__(self, path):
        b = open(path, 'rb').read()
        tag, self.version, _, self.flags, nc, no, ec, eo, ic, io = struct.unpack_from('<IHHIIIIIII', b, 0)
        if tag != 0x9E2A83C1:
            raise ValueError(f'{path}: not an Unreal package')
        self.names, p = [], no
        for _ in range(nc):
            if self.version >= 64:
                n, p = compact(b, p); s = b[p:p + n - 1].decode('latin-1'); p += n
            else:
                e = b.index(b'\0', p); s = b[p:e].decode('latin-1'); p = e + 1
            self.names.append(s); p += 4
        self.imports, p = [], io
        for _ in range(ic):
            cpkg, p = compact(b, p); cname, p = compact(b, p)
            outer, = struct.unpack_from('<i', b, p); p += 4
            name, p = compact(b, p)
            self.imports.append((self.names[cname], outer, self.names[name]))
        self.exports, p = [], eo
        for _ in range(ec):
            cls, p = compact(b, p); _, p = compact(b, p)
            outer, = struct.unpack_from('<i', b, p); p += 4
            name, p = compact(b, p); p += 4
            size, p = compact(b, p)
            if size > 0:
                _, p = compact(b, p)
            self.exports.append((cls, outer, self.names[name], size))

    def class_name(self, ref):
        if ref == 0:
            return 'Class'
        if ref < 0:
            return self.imports[-ref - 1][2]
        return self.exports[ref - 1][2]

    def path(self, ref):
        """Dotted name of an object reference (negative = import, positive = export)."""
        parts = []
        while ref:
            if ref < 0:
                _, ref, name = self.imports[-ref - 1]
            else:
                _, ref, name, _ = self.exports[ref - 1]
            parts.append(name)
        return '.'.join(reversed(parts))

    def imported_packages(self):
        return sorted({name for cls, outer, name in self.imports if outer == 0 and cls == 'Package'})


def cmd_info(path):
    pkg = Package(path)
    print(f'{path}: version {pkg.version}, {len(pkg.names)} names, {len(pkg.exports)} exports, {len(pkg.imports)} imports')
    for cls, n in Counter(pkg.class_name(e[0]) for e in pkg.exports).most_common():
        print(f'  {n:5}  {cls}')
    print('imports from:', ', '.join(pkg.imported_packages()))


def cmd_exports(path, only=None):
    pkg = Package(path)
    for i, (cls, outer, name, size) in enumerate(pkg.exports):
        cname = pkg.class_name(cls)
        if only is None or cname.lower() == only.lower():
            print(f'{cname:16} {pkg.path(i + 1):60} {size}')


def cmd_classes(*packages):
    for name in packages:
        pkg = Package(f'System/{name}.u')
        have = {f[:-3].lower() for f in os.listdir(f'{name}/Classes') if f.lower().endswith('.uc')} \
            if os.path.isdir(f'{name}/Classes') else set()
        classes = [e[2] for e in pkg.exports if e[0] == 0]
        missing = [c for c in classes if c.lower() not in have]
        extra = sorted(have - {c.lower() for c in classes})
        print(f'{name}: {len(classes)} classes, {len(have)} .uc; missing: {missing or "-"}; extra: {extra or "-"}')


def cmd_refs(target):
    target = target.lower()
    for pattern in SCAN:
        for path in sorted(glob.glob(pattern)):
            try:
                pkg = Package(path)
            except (ValueError, struct.error, IndexError) as e:
                print(f'skipped {path}: {e}', file=sys.stderr)
                continue
            used = sorted({pkg.path(-i - 1) for i, (cls, outer, name) in enumerate(pkg.imports)
                           if cls != 'Package' and pkg.path(-i - 1).lower().startswith(target + '.')})
            if used:
                print(f'{path}: ' + ', '.join(used[:8]) + (f' (+{len(used) - 8} more)' if len(used) > 8 else ''))


if __name__ == '__main__':
    cmds = {'info': cmd_info, 'exports': cmd_exports, 'classes': cmd_classes, 'refs': cmd_refs}
    if len(sys.argv) < 3 or sys.argv[1] not in cmds:
        sys.exit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
