import sys

path = r'C:\Users\mixao\myproject\game\project.godot'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove from [layer_names] to end
idx = content.find('[layer_names]')
if idx != -1:
    content = content[:idx].rstrip()

content += '\n\n[layer_names]\n\n'
content += '3d_physics/layer_1="world_static"\n'
content += '3d_physics/layer_2="player"\n'
content += '3d_physics/layer_3="npc"\n'
content += '3d_physics/layer_4="props_dynamic"\n'
content += '3d_physics/layer_5="triggers"\n'

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('done')
