"""Paint the original Pei company frames and assemble an editable ASE source.
Use LibreSprite to save the editable source and render the Godot sprite sheet.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = (88, 76)
FOOT = (44, 54)
DIRECTIONS = [(0, 1), (-1, 1), (-1, 0), (-1, -1),
              (0, -1), (1, -1), (1, 0), (1, 1)]
POSES = ("idle", "walk_a", "walk_b", "wind", "brace", "release", "hit", "follow", "recover", "hurt")
COMPANY = ("liu", "fan", "xiao", "xiang", "bow", "qin")
COLORS = {
    "liu": ("301c16", "5b281a", "8e4327", "bf713b", "a27043"),
    "fan": ("2b2115", "594024", "906137", "ba8a48", "b34d2b"),
    "xiao": ("152823", "26463a", "3f6857", "6f8b65", "a36d3c"),
    "xiang": ("161c21", "363e46", "626b71", "929c97", "a7422b"),
    "bow": ("1b2b1c", "3b5029", "63773c", "9b9c53", "aa6d3f"),
    "qin": ("231919", "442929", "6f3930", "925344", "a53227"),
}
INK = "#1a1615"
SKIN = "#b77753"
LIT = "#d09666"
METAL = "#a9a392"
GLINT = "#ded0a8"


def paint(actor, direction, pose):
    image = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(image)
    dx, dy = direction
    fwd = math.hypot(dx, dy)
    dx, dy = dx / fwd, dy / fwd
    side = (dy, -dx)
    back = dy < -0.36
    profile = abs(dx) > 0.85
    dark, low, mid, light, trim = ("#" + tone for tone in COLORS[actor])
    fan, xiao, xiang, liu, bow = (actor == name for name in COMPANY[:5])
    broad = 12 if fan else (10 if xiang else 7)
    tall = 4 if xiang else (2 if xiao else 0)
    lean = {"wind":-3,"brace":-4,"release":1,"hit":6,"follow":5,"recover":2,"hurt":-3}.get(pose,0)
    step = {"walk_a":2,"walk_b":-2,"brace":-2,"release":2,"hit":4,"follow":3,"recover":1}.get(pose,0)
    if pose == "hurt":
        tall -= 2
    cx, cy = FOOT
    cx += round(dx * lean)
    cy += round(dy * lean) - abs(step) // 2

    def poly(points, color, outline=None):
        draw.polygon([(round(cx + x), round(cy + y)) for x, y in points],
                     fill=color, outline=outline)

    def box(x, y, w, h, color):
        if w > 0 and h > 0:
            draw.rectangle((round(cx+x), round(cy+y), round(cx+x+w-1),
                            round(cy+y+h-1)), fill=color)

    def line(points, color, width=1):
        draw.line([(round(cx+x), round(cy+y)) for x, y in points],
                  fill=color, width=width)

    def gear():
        angle = {"wind":-0.80,"brace":-1.18,"release":-0.49,"hit":0.08,"follow":0.74,"recover":0.92}.get(pose,-0.32)
        if bow or xiang:
            angle *= 0.24
        wx = dx * math.cos(angle) - dy * math.sin(angle)
        wy = dx * math.sin(angle) + dy * math.cos(angle)
        shift = {"wind":-2,"brace":-5,"release":2,"hit":6,"follow":3}.get(pose,0)
        ox, oy = side[0]*5 + wx*shift, -13 + side[1]*5 + wy*shift

        def point(length, width=0):
            return ox + wx*length - wy*width, oy + wy*length + wx*width

        if xiao:
            bx, by = point(6)
            poly([(bx-4,by-4),(bx+4,by-4),(bx+5,by+3),(bx+3,by+5),
                  (bx-3,by+5),(bx-5,by+2)], "#9c6837", INK)
            line([(bx-3,by-1),(bx+2,by-1),(bx+3,by+1)], "#db9b57")
            box(bx,by,2,2,"#493320")
        elif bow:
            tips = [point(7,-11),point(11,-7),point(13),point(11,7),point(7,11)]
            line(tips, INK, 4)
            line(tips, "#b88b48", 2)
            middle = point({"wind":-3,"brace":-9,"release":-4,"hit":5}.get(pose,4))
            line([tips[0],middle,tips[-1]], "#c5b38b")
            if pose in ("wind","brace","release","hit"):
                line([middle,point(26 if pose == "hit" else 18)],GLINT)
        elif fan:
            line([point(-5),point(17)],INK,4)
            line([point(-4),point(16)],"#bb8b50",2)
            poly([point(10,-2),point(17,-3),point(20,0),point(19,7),
                  point(14,8),point(11,3)],METAL,INK)
            line([point(19,1),point(18,6),point(14,7)],GLINT)
        elif xiang:
            length = {"brace":21,"release":26,"hit":31,"follow":29}.get(pose,23)
            line([point(-14),point(length)],INK,4)
            line([point(-13),point(length-4)],"#a97948",2)
            poly([point(length-5,-3),point(length+6),point(length-2,2),
                  point(length-6,5),point(length-8,4)],METAL,INK)
            line([point(length-4,-2),point(length+4)],GLINT)
            line([point(length-8,1),point(length-13,4)],"#b04729",2)
        else:
            length = 21 if pose == "hit" else 17
            poly([point(5,-2),point(length-3,-2),point(length+2),
                  point(length-3,2),point(5,2)],METAL,INK)
            line([point(5,-1),point(length-2,-1),point(length+1)],GLINT)
            line([point(4,-4),point(4,4)],INK,3)
            line([point(4,-3),point(4,3)],"#b58345")
            line([point(0),point(3)],"#744526",2)
        if pose in ("wind","brace","release","hit","follow"):
            gx, gy = point(1)
            box(gx-1,gy-1,3,3,LIT)

    if back:
        gear()
    leg_a, leg_b = (-3+round(dx*step), 3-round(dx*step))
    if profile:
        leg_a, leg_b = (-2-step, 3+step)
    for lx, stride in ((leg_a,step),(leg_b,-step)):
        y = round(dy*stride)
        box(lx-2,-8+y,5,8,INK)
        box(lx-1,-7+y,3,5,low)
        box(lx-2+round(dx),-3+y,5,2,"#332722")

    if xiao or liu or xiang:
        hem = 2 if xiao else (-2 if liu else -3)
        poly([(-broad,-17),(broad,-17),(broad+2,hem-4),(4,hem),
              (-1,hem-2),(-6,hem),(-broad-2,hem-2)],low,INK)
        line([(-broad,-11),(-broad-1,hem-3),(-6,hem-1)],mid)
        if not back:
            line([(2,-14),(4,hem-1)],trim if liu else light)

    shoulder = -23 - tall
    width = broad - (3 if profile else 0)
    poly([(-width,shoulder+3),(-width+4,shoulder),(width-4,shoulder),
          (width,shoulder+3),(width+1,-12),(width-3,-9),
          (-width+3,-9),(-width-1,-12)], mid, INK)
    line([(-width+1,shoulder+4),(-width+4,shoulder+1),(width-4,shoulder+1)],light)
    box(-width+3,-12,width*2-6,3,dark)
    box(1 if dx >= 0 else -2,-12,2,2,trim)
    if fan or xiang or actor == "qin":
        for row in range(3):
            y = shoulder + 5 + row*3
            line([(-width+3,y),(width-3,y)],low)
            for x in range(-width+4+row%2,width-2,4):
                box(x,y+1,2,1,light)
    else:
        cross = 2 if dx >= 0 else -2
        line([(-cross,shoulder+2),(cross+1,shoulder+7),(cross+4,-12)],trim,2)
        if xiao:
            line([(-width+2,shoulder+5),(-width+1,-13)],light,2)
    if bow:
        poly([(-8,-18),(-8,-29),(-5,-29),(-4,-16)],"#604126",INK)
        line([(-8,-29),(-11,-32)],"#c4aa69")
        line([(-6,-29),(-7,-34)],"#c4aa69")
    if fan:
        sx = (-2 if pose in ("brace","release") else 0) + round(-side[0]*9) or (-7 if dx > 0 else 7)
        sy = round(-side[1]*3)
        poly([(sx-5,-21+sy),(sx+4,-21+sy),(sx+7,-17+sy),
              (sx+5,-8+sy),(sx,-5+sy),(sx-6,-10+sy),
              (sx-7,-16+sy)],"#593d25",INK)
        poly([(sx-4,-19+sy),(sx+3,-19+sy),(sx+5,-16+sy),
              (sx+3,-9+sy),(sx,-7+sy),(sx-4,-11+sy)],"#9a6b38")
        line([(sx-4,-17+sy),(sx,-19+sy),(sx+4,-17+sy)],"#cc9b51")
        box(sx-1,-16+sy,3,4,"#593c24")
        box(sx,-16+sy,1,2,"#d6a253")

    hx = round(dx*2)
    hy = shoulder-7
    box(hx-5,hy-1,11,10,INK)
    box(hx-4,hy+2,9,6,dark if back else SKIN)
    if not back:
        box(hx-3,hy+2,7,2,LIT)
        if profile:
            point_x = hx+4 if dx > 0 else hx-5
            box(point_x,hy+4,2,2,LIT)
            box(hx+2 if dx > 0 else hx-2,hy+3,1,1,INK)
        else:
            box(hx-2,hy+4,1,1,INK)
            box(hx+2,hy+4,1,1,INK)
        if fan or liu:
            box(hx-2,hy+7,5,2,"#4a2d22")
    if xiang:
        poly([(hx-6,hy+3),(hx-6,hy-1),(hx-3,hy-4),(hx+3,hy-4),
              (hx+6,hy-1),(hx+6,hy+3),(hx+4,hy+5),(hx+3,hy+1),
              (hx-3,hy+1),(hx-4,hy+5)],mid,INK)
        line([(hx-3,hy-3),(hx+1,hy-3),(hx+4,hy-1)],light)
        poly([(hx-2,hy-4),(hx-2,hy-9),(hx+1,hy-10),
              (hx+4,hy-8),(hx+2,hy-7),(hx+1,hy-4)],trim,INK)
    elif xiao:
        poly([(hx-6,hy+2),(hx-5,hy-3),(hx-3,hy-4),(hx+3,hy-4),
              (hx+4,hy-1),(hx+7,hy),(hx+6,hy+2)],dark,INK)
        box(hx-3,hy-3,6,1,mid)
        if back:
            line([(hx-4,hy+2),(hx-5,hy+8)],low,2)
    elif liu:
        box(hx-5,hy,11,3,dark)
        box(hx-3,hy-2,7,3,trim)
        box(hx-4,hy,8,1,light)
        if back:
            box(hx+2,hy+2,2,4,trim)
    elif fan:
        box(hx-5,hy,11,3,dark)
        box(hx-4,hy+1,9,1,trim)
        box(hx-3,hy-2,6,2,INK)
    else:
        poly([(hx-6,hy+2),(hx-4,hy-3),(hx+3,hy-3),
              (hx+5,hy-1),(hx+6,hy+2)],mid,INK)
        box(hx-3,hy-2,5,1,light)
        if actor == "qin":
            box(hx,hy-6,2,4,trim)
    if not back:
        gear()
    if pose == "hurt":
        line([(-width+2,shoulder+5),(-width+5,shoulder+3)], "#e4a369", 2)
        box(width-2,-16,2,2,"#c75433")
    return image


def chunk(kind, data):
    return struct.pack("<IH", len(data)+6, kind)+data


def string(value):
    raw = value.encode()
    return struct.pack("<H",len(raw))+raw


def encode_ase(frames, tags):
    layer = struct.pack("<6HB3x",1,0,0,0,0,0,255)+string("Pei company")
    tag_data = struct.pack("<H8x",len(tags))
    for name, start, end in tags:
        tag_data += struct.pack("<HHB8x3BB",start,end,0,160,110,60,0)+string(name)
    result = []
    for index, image in enumerate(frames):
        cel = struct.pack("<HhhBH7xHH",0,0,0,255,2,*SIZE)+zlib.compress(image.tobytes())
        parts = [chunk(0x2004, layer),chunk(0x2018,tag_data)] if index == 0 else []
        parts.append(chunk(0x2005,cel))
        data = b"".join(parts)
        result.append(struct.pack("<IHHH6x",len(data)+16,0xF1FA,len(parts),95)+data)
    data = b"".join(result)
    header = bytearray(128)
    struct.pack_into("<I5HIH",header,0,128+len(data),0xA5E0,len(frames),*SIZE,32,1,95)
    header[34:36] = bytes((1,1))
    return header+data


if __name__ == "__main__":
    frames = []
    tags = []
    for character in COMPANY:
        begin = len(frames)
        for direction in DIRECTIONS:
            frames.extend(paint(character,direction,pose) for pose in POSES)
        tags.append((character,begin,len(frames)-1))
    Path(sys.argv[1]).write_bytes(encode_ase(frames,tags))
