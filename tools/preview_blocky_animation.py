from PIL import Image, ImageDraw
from pathlib import Path
assets=Path('assets/models')
frames=[]
for clip in ('Idle','Walk','Attack','Death'):
    paths=sorted((assets/'animation_preview').glob(clip+'_*.png'))
    for path in paths:
        im=Image.open(path).convert('RGB')
        draw=ImageDraw.Draw(im)
        draw.rounded_rectangle((12,12,145,42),radius=5,fill=(18,25,24))
        draw.text((24,21),{'Idle':'REPOSO','Walk':'CAMINAR','Attack':'ATAQUE','Death':'MUERTE'}[clip],fill=(235,235,211))
        frames.append(im)
    if clip in ('Attack','Death'):
        frames.extend([frames[-1].copy() for _ in range(5)])
frames[0].save(assets/'zombie_blocky_animation.gif',save_all=True,append_images=frames[1:],duration=125,loop=0,optimize=False)
sheet=Image.new('RGB',(448*4,448))
for index,(clip,frame) in enumerate((('Idle',13),('Walk',67),('Attack',136),('Death',202))):
    sheet.paste(Image.open(assets/'animation_preview'/f'{clip}_{frame:03d}.png'),(index*448,0))
sheet.save(assets/'zombie_blocky_animation_poses.png')
