"""Author the separated ink-and-wash figures and height plate as editable SVG."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
STYLE = {
    "liu": ("#873e26", "#bc7549", "#cda769", "crown", "robe"),
    "fan": ("#635039", "#a68856", "#d5ad62", "warcap", "armor"),
    "xiao": ("#345a54", "#699282", "#ba9b62", "scholar", "robe"),
    "han": ("#3e575d", "#658389", "#caba79", "hood", "robe"),
    "cao": ("#746446", "#a39261", "#d1af72", "warcap", "armor"),
    "xiang": ("#3e4c51", "#7f9290", "#cfb479", "horns", "armor"),
    "guard": ("#75352c", "#9e5747", "#c6a26a", "helmet", "armor"),
    "pursuer": ("#8d5535", "#b47752", "#c6a26a", "headband", "robe"),
    "archer": ("#6a4139", "#a26856", "#bc9a70", "hood", "robe"),
    "fiction": ("#66545e", "#9a7a84", "#c5ac87", "horns", "armor"),
}
PARTS = ["torso_front", "torso_side", "torso_back", "head_front", "head_side", "head_back",
         "sleeve", "forearm", "thigh", "boot", "cape"]
EQUIPMENT = ["sword", "axe", "shield", "bow", "bow_drawn", "spear", "aid", "quiver", "arrow"]
INK = "#252020"
WIDTH, HEIGHT, CELL = 12 * 192, 10 * 192, 192
RAMP = {"cloth": (136,162,146), "leather": (145,183,158), "iron": (156,221,175), "lacquer": (156,197,169), "skin": (143,184,152)}
PLATE = {"cloth": "#939393", "fold": "#aaaaaa", "leather": "#a7a7a7",
         "iron": "#c8c8c8", "lacquer": "#b8b8b8", "skin": "#adadad", "line": "#7c7c7c",
         "ridge": "#dddddd", "edge": "#909090"}

def shape(d, color, material="cloth", width=0.8):
    height = f"url(#height-{material})" if material in RAMP else PLATE[material]
    return f'<path d="{d}" fill="{color}" stroke="{INK}" stroke-width="{width}" stroke-linejoin="round"/>', \
           f'<path d="{d}" fill="{height}" stroke="{PLATE["edge"]}" stroke-width="{width}"/>'


def line(d, color, width=0.65, material="line"):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>', \
           f'<path d="{d}" fill="none" stroke="{PLATE[material]}" stroke-width="{width}" stroke-linecap="round"/>'


def circle(cx, cy, r, color, material="lacquer"):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"/>',
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{PLATE[material]}"/>')


def figure(name, part):
    dark, high, trim, cap, coat = STYLE[name]
    armor = coat == "armor"
    if part.startswith("torso"):
        side, back = part.endswith("side"), part.endswith("back")
        w = 9.4 if name in {"fan", "xiang"} else 7.5
        mark = [shape(f"M{-w} 1 Q-5 -2 0 -2 Q5 -2 {w} 1 L{w-2} 11 L{w-1} 20 Q3 22 0 19 Q-3 22 {-w+1} 20 L{-w+2} 11Z", "url(#body)", "lacquer" if armor else "cloth"),
                shape("M-7 12 Q1 13 7 11 L7.5 14 Q0 16 -7.5 14Z", "#493528", "leather"),
                shape("M-1.3 12.8h2.6v2h-2.6Z", trim, "iron", 0.4)]
        if armor:
            for row in range(3):
                y = 3.4+row*2.45
                mark.append(line(f"M-6.4 {y} Q0 {y+1} 6.4 {y-.45}", "#362c28", .66))
                for x in [-5.0,-2.2,.6,3.4,5.4]:
                    mark.append(circle(x, y+.85, .37, trim, "ridge"))
        elif not back:
            origin = 4.0 if side else 0.0
            mark += [shape(f"M-5 -.2 {origin} 5.2 5 0 3 -.8 {origin} 2.7 -3 -.9Z", trim, "fold", .35),
                     line(f"M{origin} 5 Q3 8 5 11 M-4 16 Q-3 17 -4 19 M3 16L4 19", high, .7, "fold")]
        else:
            mark += [line("M0 1L0 12 M-5 3Q-4 8 -5 10 M5 3Q4 8 5 10", high, .7, "fold")]
        mark += [line("M-7 19Q-4 20 -1 18 M2 19Q4 20 7 19", trim, .55, "fold")]
        return mark
    if part.startswith("head"):
        side, back = part.endswith("side"), part.endswith("back")
        skin = "#d39d72" if name!="fan" else "#b77e58"
        lid = "M-5.3 -1 Q-4 -7 1 -7 Q6 -7 6 0 L3 2 -4 1Z"
        if cap=="horns": lid="M-6 0 L-8 -6 -4 -4 0 -10 4 -4 8 -6 6 0Z"
        if cap=="warcap": lid="M-6 -1 Q-5 -7 0 -7 Q5 -7 6 -1 L2 1 -4 1Z"
        if cap=="crown": lid="M-5 -.5 -5 -5 -1 -5 -1 -9 2 -9 2 -5 5 -5 5 0Z"
        if cap=="scholar": lid="M-6 -1 -4 -7 -2 -9 2 -9 5 -6 6 0Z"
        if cap=="hood": lid="M-6 2 Q-6 -8 0 -8 Q6 -8 6 2 L4 4 3 -2 -3 -2 -4 4Z"
        if cap=="headband": lid="M-6 -2 -5 -5 Q-1 -8 4 -5 L6 -2 8 -3 7 1 5 0 -5 0Z"
        face = "M-4 -2 Q0 -4 4 -3 L5 -1 6 1 4 2 3.5 4 0 5 -3 4 -4 1Z" if side else "M-4.5 -2 Q0 -4.7 4.5 -2 L4.2 1.5 2.5 4.8 0 5.5 -2.5 4.8 -4.2 1.5Z"
        mark = [shape(face, "#46302a" if back else skin, "skin"), shape(lid,"url(#body)","lacquer")]
        mark += [line("M-4 -1Q0 0 4 -1",trim,.65,"ridge")]
        if not back:
            mark += [line("M1.1 .05L3.2 .1 M2.5 2.4L4 2.5" if side else "M-2.9 .2l1.75 -.1 M1.15 .1l1.75 .1 M-1 3h2",INK,.48)]
            if name in {"liu","fan","xiang","guard"}:
                mark += [shape("M-2.7 2.7Q0 3.5 3.6 2.6 L2.1 5.5 0 6.1 -2 4.8Z","#50332a","leather",.4)]
        else:
            mark += [line("M-2 4L-2 1 M2 4V1",high,.55,"fold")]
        return mark
    if part=="sleeve":
        return [shape("M-3 -1 Q-3 -3 0 -3 Q3 -3 3 0 L2.6 6 Q0 8 -2.6 6Z","url(#body)", "lacquer" if armor else "cloth"),
                line("M-2.2 4Q0 5.3 2.2 4",trim,.7,"ridge")]
    if part=="forearm":
        return [shape("M-2 -1 Q0 -2 2 -1 L2 6 Q1.8 9 0 9 Q-2 9 -2.3 6 Z","#654936","leather"),
                shape("M-2.17 6 Q0 5 2 5.8 L2 7.7 Q0 9 -1.7 8.1Z","#ca9670","skin",.5),
                line("M-1.8 1.2L1.8 .4 M-1.7 2.7L1.8 2",trim,.42,"ridge")]
    if part=="thigh":
        return [shape("M-3.1 -1 Q0 -2 3 -1 L2.2 5.5 -.1 7 -2.6 5Z","url(#body)","cloth"),
                line("M-1.65 1Q-1.8 3 0 4", high, .6,"fold")]
    if part=="boot":
        return [shape("M-2.25 -1 2.25 -1 2.1 5 3.1 7 Q3.5 9 1.5 9 L-2.7 8.4 -2.4 5Z","#44352c","leather"),
                line("M-2 1L2 1 M-1.7 3L1.7 2.5","#9f805e",.57,"ridge")]
    return [shape("M-6 0 Q0 -2 6 1 L7 18 4 22 -1 18 -5 21 -8 17Z","url(#body)","cloth"),
            line("M-4 2 Q-5 9 -5 18 M-1 3 Q-1 10 0 17 M4 3 5 19",high,.65,"fold")]


def item(part):
    wood, iron, gold = "#734d33", "#aeb3aa", "#cba265"
    if part in {"sword","spear"}:
        long = part=="spear"
        tip = 22 if long else 20
        return [shape(f"M{-17 if long else -5} -1.15 H{16 if long else 4} V1.15 H{-17 if long else -5}Z",wood,"leather",.6),
                shape(f"M{14 if long else 3} -2.2 L{tip-4} -1.9 {tip} 0 {tip-4} 1.9 {14 if long else 3} 2.2Z",iron,"iron",.65),
                line(f"M{15 if long else 4} .15L{tip-1} 0","#e1dbbf",.52,"ridge"),
                shape("M1 -3 3 -3 3 3 1 3Z",gold,"iron",.47)]
    if part=="axe":
        return [shape("M-7 -1 14 -1 14 1.2 -7 1.2Z",wood,"leather",.72),
                shape("M9 -1 Q11 -4 10 -6 Q15 -9 19 -5 Q22 -1 19 4 L14 5 12 1Z","#9faaa3","iron",.75),
                line("M12 -5.8 Q17 -7.6 19 -3 M18 2.7L14 3.8","#e0d1aa",.62,"ridge")]
    if part=="shield":
        return [shape("M-6 -7 Q0 -9 6 -7 L8 -3 7 4 0 9 -7 4 -8 -3 Z",gold,"iron"),
                shape("M-4.9 -5.8 Q0 -7.4 4.9 -5.8 L6 -3 5.4 3 0 7 -5.4 3 -6 -3 Z","#70382b","lacquer",.56),
                circle(0,0,2.32,"#bb9360","iron"), circle(-.6,-.6,.7,"#d9b47b","ridge"),
                line("M-5 -4Q0 -6 5 -4 M0 4v1","#bd8757",.42,"ridge")]
    if part in {"bow","bow_drawn"}:
        draw = -14 if part=="bow_drawn" else -4.5
        return [line("M-2 -13 Q15 -10 9 -3 Q6 0 9 3 Q15 10 -2 13",INK,2.8,"edge"),
                line("M-2 -13 Q15 -10 9 -3 Q6 0 9 3 Q15 10 -2 13",gold,1.5,"leather"),
                line(f"M-2 -13 {draw} 0 -2 13","#dfd4ba",.57,"ridge"),
                line("M7 -1v2",wood,1.5,"leather")]
    if part=="arrow":
        return [line("M-6 0H14","#ccb28a",.7,"leather"),shape("M14 -1.1 17 0 14 1.1Z",iron,"iron",.36)]
    if part=="quiver":
        return [shape("M-3 -9 3 -9 3 11 -2 11Z",wood,"leather"),
                line("M-2 -9 -3 -15 M0 -9L0 -17 M2 -9 3 -15",gold,.77,"ridge"),
                line("M-2 2L2 1",gold,.64,"ridge")]
    return [shape("M-3 -5 3 -5 4 3 2 5 -3 4 -4 0Z", "#866139","leather"),
            line("M-3 -2Q0 1 3 -2"," #cf9d56".strip(),.76,"ridge"),
            line("M-1 2h2 M0 1v2","#d6b68a",.62,"ridge")]


def main():
    cells = [(name,part) for name in STYLE for part in PARTS] + [("gear",part) for part in EQUIPMENT]
    for plate in (0,1):
        result = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">']
        if plate:
            for material, values in RAMP.items():
                peak = "40%" if material=="iron" else "53%"
                result.append(f'<defs><linearGradient id="height-{material}" x1="0" y1="0" x2="1" y2="{".7" if material=="cloth" else ".26"}"><stop stop-color="#{values[0]:02x}{values[0]:02x}{values[0]:02x}"/><stop offset="{peak}" stop-color="#{values[1]:02x}{values[1]:02x}{values[1]:02x}"/><stop offset="1" stop-color="#{values[2]:02x}{values[2]:02x}{values[2]:02x}"/></linearGradient></defs>')
        for i,(name,part) in enumerate(cells):
            x,y = 192*(i%12)+96, 192*(i//12)+96
            values = STYLE.get(name)
            art = figure(name,part) if values else item(part)
            parts = [pair[plate] for pair in art]
            if values:
                dark, high = values[:2]
                key = f"coat{i}"
                result.append(f'<defs><linearGradient id="{key}" x1="0%" y1="0%" x2="84%" y2="100%"><stop stop-color="{high}"/><stop offset="1" stop-color="{dark}"/></linearGradient></defs>')
                parts = [x.replace("url(#body)",f"url(#{key})") for x in parts]
            result.append(f'<g id="{name}-{part}" transform="translate({x} {y}) scale(4)">'+ "".join(parts)+'</g>')
        result.append("</svg>")
        (HERE/("relief.svg" if plate else "pigments.svg")).write_text("\n".join(result)+"\n")

if __name__ == "__main__":
    main()
