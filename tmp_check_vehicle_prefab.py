from pathlib import Path
p=Path('C:/Projects/reading-racer/Assets/SimpleCars/Prefabs/PosZFacing/sedan_seperate_PosZ.prefab.scn')
b=p.read_bytes()
print('len', len(b))
print('first80', b[:80])
print('has MeshInstance3D', b.find(b'MeshInstance3D'))
print('has material_overlay', b.find(b'material_overlay'))
