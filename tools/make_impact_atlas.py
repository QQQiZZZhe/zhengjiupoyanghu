from PIL import Image, ImageDraw
import math
frames, side = 12, 128
atlas = Image.new('RGBA', (frames * side, side))
for frame in range(frames):
    phase = frame / frames
    tile = Image.new('RGBA', (side, side))
    d = ImageDraw.Draw(tile)
    alpha = round((1-phase)**2 * .8 * 255)
    color = (255,255,255,alpha)
    radius = 14 + 38 * (1-(1-phase)**3)
    for i in range(12):
        angle = i * math.tau / 12
        end = angle + math.tau / 20
        a = (round(64+math.cos(angle)*radius), round(64+math.sin(angle)*radius))
        b = (round(64+math.cos(end)*radius), round(64+math.sin(end)*radius))
        d.line((a,b), fill=color, width=2)
    for i in range(8):
        angle = i * math.tau / 8 + .2
        travel = 10 + 48 * phase
        x,y = round(64+math.cos(angle)*travel),round(64+math.sin(angle)*travel)
        s = max(1, round(4*(1-phase)))
        d.rectangle((x,y,x+2*s-1,y+s-1),fill=color)
    atlas.paste(tile,(frame*side,0))
atlas.save('assets/effects/impact-atlas.png')
