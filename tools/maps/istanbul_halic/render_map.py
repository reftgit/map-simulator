"""Optional Blender 4.5 render/source-file builder. Run with Blender's Python or bpy.
The previews use the exact exported GLB geometry, with studio lighting.
"""
from pathlib import Path
import bpy, math, os
from mathutils import Vector
ROOT=Path(__file__).resolve().parent.parent
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'Godot/assets/istanbul_halic.glb'))
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED';scene.render.threads=12
scene.render.image_settings.file_format='PNG'
scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.77,.85,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
sun_data=bpy.data.lights.new('Afternoon Sun','SUN');sun=bpy.data.objects.new('Afternoon Sun',sun_data);scene.collection.objects.link(sun)
sun.rotation_euler=(math.radians(27),math.radians(-24),math.radians(-32));sun_data.energy=3;sun_data.angle=math.radians(12);sun_data.color=(1,.88,.70)
cam_data=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cam_data);scene.collection.objects.link(cam);scene.camera=cam
cam_data.clip_end=10000
def camera(pos,target,lens=45,ortho=None):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
 cam_data.type='ORTHO' if ortho else 'PERSP';cam_data.lens=lens
 if ortho:cam_data.ortho_scale=ortho
def render(name,width=1800,height=1300):
 if os.environ.get("RENDER_ONLY") and name not in os.environ["RENDER_ONLY"].split(","):return
 scene.render.resolution_x=width;scene.render.resolution_y=height
 scene.render.filepath=str(ROOT/'previews'/name);bpy.ops.render.render(write_still=True)
# A studio floor below the map makes the finite gameplay slice readable.
bpy.ops.mesh.primitive_plane_add(size=20000,location=(0,0,-16))
floor=bpy.context.object;floor.name='Preview_Backdrop-noimp'
mat=bpy.data.materials.new('Preview_Backdrop');mat.diffuse_color=(.052,.083,.09,1);mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.052,.083,.09,1);floor.data.materials.append(mat)
camera((-410,-350,165),(-690,0,35),lens=36)
render('06_halic_metro_koprusu.png',1800,1150)
camera((35,-165,70),(-20,-50,7),lens=42)
render('07_sokak_detaylari.png',1800,1150)
camera((2000,-2900,2400),(-585,220,0),ortho=3950)
render('01_istanbul_overview.png',1800,1550)
camera((140,740,380),(-160,-160,0),lens=34)
render('02_galata_halic.png',1800,1150)
camera((135,-175,145),(-270,-565,25),lens=36)
render('03_bridge_eminonu.png',1800,1100)
camera((-660,-550,230),(-929,-780,89),lens=45)
render('04_suleymaniye.png',1800,1200)
camera((2000,-2900,2400),(-585,220,0),ortho=3950)
# Terrain-only inspection view uses the unexaggerated game mesh.
hidden=[]
for obj in scene.objects:
 if obj.type=='MESH' and not any(obj.name.startswith(prefix) for prefix in ['Ground','Water','Gardens','Quays','Preview_']):
    hidden.append(obj);obj.hide_render=True
render('05_arazi.png',1600,1350)
for obj in hidden:obj.hide_render=False
camera((-280,700,340),(-1080,850,15),lens=40)
render('08_kasimpasa.png',1800,1150)
camera((-410,-350,165),(-690,0,35),lens=36)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Istanbul_Halic.blend'),compress=True)
print('PREVIEWS_AND_BLEND_SAVED',flush=True)
