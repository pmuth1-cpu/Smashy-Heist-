MENU_PATH = r"D:\My project\smashy heist\scripts\ui\brawl_main_menu.gd"

with open(MENU_PATH, "r", encoding="utf-8") as f:
    text = f.read()

s = text.find("var hangar_group := Node3D.new()")
e = text.find("_pedestal_pivot = Node3D.new()")
assert s != -1 and e != -1

replacement = """var hangar_group := Node3D.new()
\thangar_group.name = "NeonGarageHangar"
\tworld.add_child(hangar_group)
\t
\t"""

text = text[:s] + replacement + text[e:]

with open(MENU_PATH, "w", encoding="utf-8") as f:
    f.write(text)

print("Simplified hangar group successfully!")
