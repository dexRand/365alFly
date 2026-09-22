import glob
import sys
import xml.etree.ElementTree as ET
import zipfile

fails = 0
for p in sorted(glob.glob(sys.argv[1] + "/*.pptx")):
    z = zipfile.ZipFile(p)
    if z.testzip():
        print(p, "BAD ZIP")
        fails += 1
        continue
    for n in z.namelist():
        if n.endswith((".xml", ".rels")):
            try:
                ET.fromstring(z.read(n))
            except Exception as e:
                print(p, n, "XMLERR", e)
                fails += 1
    print(p, "ok", len(z.namelist()), "parts")

print("FAILS:", fails)
sys.exit(1 if fails else 0)