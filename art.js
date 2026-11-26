(() => {
  "use strict";

  const { width, height, roster, points } = window.Pei;
  const TAU = Math.PI * 2;
  const palettes = {
    liu: ["#803832", "#bc5541", "#e68359", "#e3be70", "#57352c"],
    fan: ["#563c32", "#8d5b42", "#bc7b4e", "#d7a667", "#392c2b"],
    xiao: ["#305451", "#477d70", "#7fad87", "#d2c283", "#2c3d3b"],
    xiang: ["#433457", "#735473", "#a87996", "#d5aec2", "#312c47"],
    zhou: ["#775236", "#b67d4e", "#d89859", "#dbbe86", "#4e3c35"],
    cao: ["#414c62", "#62758c", "#8d9dad", "#e3ce94", "#343946"],
    qin: ["#3b4947", "#59605b", "#818376", "#b5ae88", "#2d3635"],
    pike: ["#39443d", "#626052", "#8a806a", "#ccaa76", "#343a30"],
    captain: ["#513736", "#80504d", "#a56859", "#d99966", "#3b3032"],
  };
  const ground = {
    defense: ["#41493b", "#353e34", "#4e5440", "#61604a", "#555745", "#857350"],
    assault: ["#454438", "#383d35", "#53503e", "#6a5943", "#5b503f", "#81684b"],
    camp: ["#3f4b3b", "#344337", "#4c5742", "#696145", "#57604a", "#8d7653"],
  };

  function box(ctx, color, x, y, w, h) {
    ctx.fillStyle = color;
    ctx.fillRect(Math.round(x), Math.round(y), w, h);
  }

  function polygon(ctx, color, vertices) {
    ctx.fillStyle = color;
    ctx.beginPath();
    vertices.forEach(([x, y], i) => i ? ctx.lineTo(Math.round(x), Math.round(y)) : ctx.moveTo(Math.round(x), Math.round(y)));
    ctx.closePath();
    ctx.fill();
  }

  function oval(ctx, color, x, y, w, h) {
    polygon(ctx, color, [[x-w+2,y-h],[x+w-2,y-h],[x+w,y-1],[x+w,y+1],[x+w-2,y+h],
      [x-w+2,y+h],[x-w,y+1],[x-w,y-1]]);
  }

  function text(ctx, content, x, y, color, size = 8) {
    ctx.font = "bold " + size + 'px "Apple SD Gothic Neo", "Malgun Gothic", "Noto Sans CJK KR", system-ui, sans-serif';
    ctx.textAlign = "center";
    ctx.lineJoin = "round";
    ctx.lineWidth = 2;
    ctx.strokeStyle = "#20251c";
    ctx.strokeText(content, Math.round(x), Math.round(y));
    ctx.fillStyle = color;
    ctx.fillText(content, Math.round(x), Math.round(y));
  }

  function seeded(seed) {
    return () => {
      seed = (Math.imul(1664525, seed) + 1013904223) >>> 0;
      return seed / 4294967296;
    };
  }

  function tileGround(ctx, zone) {
    const palette = ground[zone];
    const random = seeded(zone === "camp" ? 178 : zone === "assault" ? 323 : 512);
    box(ctx, palette[0], 0, 0, width, height);
    for (let y = 0; y < height; y += 4) {
      for (let x = 0; x < width; x += 4) {
        const lane = Math.abs(x - 240 - 17 * Math.sin(y / 61)) < 41 + random() * 10;
        const trail = zone === "assault" && Math.abs(x - 408) < 20;
        const yard = zone === "camp" && Math.hypot((x - 231) * 0.64, y - 155) < 46 + random() * 8;
        const slope = zone === "defense" ? Math.abs(y - 117) < 13 : Math.abs(y - 125) < 9;
        const edge = Math.min(x, width-x) < 35 + random() * 9;
        const base = lane || trail || yard || slope ? 3 : 0;
        const shade = random() > 0.69 ? (base ? 4 : 2) : edge && !slope ? 1 : base;
        if (shade) box(ctx, palette[shade], x, y, 4, 4);
        if (random() < 0.28) {
          box(ctx, random() > .72 ? palette[5] : palette[shade === 1 ? 0 : 4],
            x + 1, y + Math.floor(random() * 4), random() > .6 ? 3 : 1, 1);
        }
      }
    }
    for (let i = 0; i < 226; i++) {
      const x = 12 + Math.floor(random() * 456);
      const y = 9 + Math.floor(random() * 270);
      if (Math.abs(x - 240) < 49 || (zone === "assault" && Math.abs(x - 408) < 22)) {
        box(ctx, "#53503e", x, y, 2, 1);
        continue;
      }
      box(ctx, "#323d31", x, y, 3, 1);
      box(ctx, random() > 0.76 ? "#8b8060" : "#657057", x + 1, y - 2, 1, 2);
      if (i % 5 === 0) box(ctx, "#747658", x + 3, y - 1, 1, 2);
    }
    for (const [x, y, w] of [[65, 51, 29], [117, 222, 28], [303, 207, 35], [378, 66, 27], [27, 246, 17]]) {
      oval(ctx, palette[1], x, y, w, 10);
      box(ctx, palette[0], x - w + 5, y - 5, w * 2 - 10, 3);
      for (let i = 0; i < 7; i++) box(ctx, palette[i % 3 ? 4 : 5], x - w + 6 + i * (w / 4), y - (i % 3) * 3 + 5, 4, 1);
    }
  }

  function wall(ctx, x, y, w, style) {
    const qin = style === "assault";
    const brick = qin ? ["#786a52", "#645945", "#958268"] : ["#827659", "#6b624b", "#a1926b"];
    box(ctx, "#2f342b", x - 1, y + 9, w + 2, 11);
    box(ctx, "#4c4838", x, y - 9, w, 25);
    for (let row = 0; row < 3; row++) {
      const offset = row % 2 * 6;
      for (let i = -offset; i < w; i += 12) {
        const left = Math.max(0, i);
        const span = Math.min(w, i + 11) - left;
        box(ctx, brick[(row + Math.floor((i+6)/12)) % 2], x + left, y - 5 + row * 6, span, 5);
        if ((i + row) % 3 === 0) box(ctx, brick[2], x + left + 1, y - 5 + row * 6, Math.max(1, span - 2), 1);
      }
    }
    box(ctx, qin ? "#514c40" : "#635644", x - 2, y - 13, w + 4, 8);
    box(ctx, "#ad9469", x - 2, y - 13, w + 4, 2);
    for (let i = 0; i < w; i += 10) {
      box(ctx, "#3e4034", x + i, y - 11, 2, 6);
      box(ctx, "#827357", x + i + 3, y - 10, 6, 1);
    }
    box(ctx, "#302e28", x, y + 13, w, 3);
  }

  function roof(ctx, x, y, w, depth = 15, red = false) {
    const [dark, mid, light, ridge] = red ? ["#3a302a","#65453a","#8b6048","#bd8d61"]
      : ["#253332","#3f524b","#5e6b58","#948a65"];
    polygon(ctx, dark, [[x-5,y+depth],[x+6,y-3],[x+w-6,y-3],[x+w+5,y+depth],[x+w+7,y+depth+4],[x-7,y+depth+4]]);
    polygon(ctx, mid, [[x-2,y+depth-1],[x+6,y],[x+w-6,y],[x+w+2,y+depth-1]]);
    for (let i = 7; i < w - 3; i += 5) {
      const shift = Math.round((i / w - 0.5) * 12);
      polygon(ctx, light, [[x+i,y+1],[x+i+1,y+1],[x+i+shift+1,y+depth],[x+i+shift-1,y+depth]]);
    }
    box(ctx, ridge, x + 4, y - 2, w - 8, 2);
    box(ctx, light, x - 6, y + depth + 1, w + 12, 1);
    box(ctx, ridge, x - 7, y + depth, 4, 2);
    box(ctx, ridge, x + w + 3, y + depth, 4, 2);
  }

  function tower(ctx, x, y, w = 32, red = false) {
    box(ctx, "#30362d", x - 4, y + 12, w + 8, 10);
    box(ctx, "#765841", x + 1, y - 14, w - 2, 30);
    box(ctx, "#a68056", x + 4, y - 12, w - 8, 22);
    for (let i = 5; i < w - 2; i += 8) box(ctx, "#4d3c32", x + i, y - 12, 2, 28);
    box(ctx, "#322d26", x + Math.floor(w/2) - 5, y, 10, 13);
    box(ctx, "#bd9764", x + Math.floor(w/2) - 5, y - 2, 10, 2);
    roof(ctx, x - 2, y - 33, w + 4, 18, red);
    box(ctx, "#ac875f", x, y + 14, w, 2);
  }

  function fence(ctx, x, y, w) {
    box(ctx, "#2b3428", x, y+1, w, 5);
    box(ctx, "#78694b", x, y-6, w, 2);
    box(ctx, "#4b4836", x, y-2, w, 2);
    for (let i = 0; i < w; i += 8) {
      box(ctx, "#564a35", x+i, y-10+(i%3), 3, 13);
      box(ctx, "#a58c58", x+i, y-10+(i%3), 1, 9);
    }
  }

  function crate(ctx, x, y, w = 12) {
    box(ctx, "#303429", x - 1, y + 4, w + 3, 5);
    box(ctx, "#75553b", x, y, w, 7);
    box(ctx, "#b08a57", x, y - 4, w, 4);
    box(ctx, "#d2a66b", x + 1, y - 4, w - 2, 1);
    box(ctx, "#554530", x + 2, y, 1, 7);
    box(ctx, "#ad8752", x + w - 3, y, 1, 6);
    box(ctx, "#503f2e", x, y + 5, w, 2);
  }

  function tree(ctx, x, y, style) {
    const colors = style === "assault" ? ["#2d352c","#394435","#4f5842"] : ["#2b382e","#3a4d3d","#52654b"];
    oval(ctx, "#303a2d", x+4, y+2, 15, 6);
    box(ctx, "#524838", x-2, y-21, 4, 22);
    box(ctx, "#806747", x, y-19, 1, 17);
    polygon(ctx, colors[0], [[x-14,y-9],[x-18,y-16],[x-10,y-23],[x-12,y-28],[x-6,y-36],[x+7,y-35],[x+13,y-26],[x+12,y-23],[x+18,y-16],[x+13,y-10]]);
    polygon(ctx, colors[1], [[x-12,y-17],[x-6,y-24],[x-8,y-28],[x-1,y-34],[x+7,y-31],[x+9,y-26],[x+6,y-23],[x+14,y-18],[x+10,y-15],[x-7,y-14]]);
    box(ctx, colors[2], x-5, y-29, 8, 2);
    box(ctx, colors[2], x-10, y-19, 6, 2);
    box(ctx, colors[2], x+3, y-23, 5, 2);
  }

  function flag(ctx, x, y, t, qin = false, large = false) {
    const h = large ? 34 : 23;
    const w = large ? 24 : 13;
    const flicker = Math.floor(Math.sin(t * 6 + x) * 2);
    const cloth = qin ? ["#27312c","#50584b","#939174"] : ["#71382e","#a8533c","#e0a76c"];
    oval(ctx, "#2c352c", x + 2, y + 1, 5, 2);
    box(ctx, "#362f25", x - 1, y - h, 3, h + 2);
    box(ctx, "#c79b61", x, y - h, 1, h);
    polygon(ctx, cloth[0], [[x+2,y-h+2],[x+w+3,y-h+3+flicker],[x+w,y-h+11+flicker],[x+w+2,y-h+18+flicker],[x+2,y-h+16]]);
    polygon(ctx, cloth[1], [[x+3,y-h+4],[x+w,y-h+5+flicker],[x+w-2,y-h+11],[x+w,y-h+15+flicker],[x+3,y-h+14]]);
    box(ctx, cloth[2], x + 5, y - h + 6, 2, 6);
    if (large) text(ctx, qin ? "秦" : "沛", x+13, y-h+13, "#f0d7a0", 10);
    box(ctx, "#dcb477", x - 1, y - h - 2, 3, 2);
  }

  function tent(ctx, x, y, w, dye) {
    oval(ctx, "#303a2c", x+w/2, y+8, w/2+5, 8);
    box(ctx, "#77583b", x+5, y-15, w-10, 23);
    polygon(ctx, "#9b7950", [[x+7,y-11],[x+w-6,y-11],[x+w-5,y+6],[x+5,y+6]]);
    polygon(ctx, dye, [[x-2,y-9],[x+10,y-26],[x+w-12,y-26],[x+w+2,y-9],[x+w,y-5],[x,y-5]]);
    box(ctx, "#c39861", x+7, y-26, w-13, 2);
    box(ctx, "#d0a16e", x+1, y-10, w-2, 2);
    box(ctx, "#574734", x+w/2-5, y-5, 10, 12);
    box(ctx, "#3e372c", x+w/2-2, y-4, 5, 11);
    box(ctx, "#b58d58", x+2, y-6, 1, 16);
    box(ctx, "#755f42", x+w-3, y-5, 2, 15);
  }

  function fire(ctx, x, y, t, large = false) {
    const flicker = Math.floor(t * 13 + x) % 4;
    const size = large ? 14 : 8;
    const light = ctx.createRadialGradient(x,y-4,1,x,y-4,large ? 42 : 23);
    light.addColorStop(0,"#f9ba633a");
    light.addColorStop(1,"#f9a54a00");
    ctx.fillStyle = light;
    ctx.fillRect(x-44,y-48,88,88);
    if (large) {
      oval(ctx, "#2c3329", x, y, 13, 5);
      box(ctx, "#776746", x-8, y-1, 16, 3);
      box(ctx, "#352d25", x-7, y-2, 14, 2);
    } else {
      box(ctx, "#513c2c", x-1, y-4, 2, 14);
      box(ctx, "#ba8a57", x, y-3, 1, 12);
    }
    polygon(ctx, "#b95838", [[x-size/2,y-2],[x-size/2+1,y-8],[x-2,y-size-1],[x+1,y-size-3-flicker],[x+3,y-8],[x+size/2,y-6],[x+size/2-1,y-2]]);
    box(ctx, "#ef924a", x-3, y-8, 6, 6);
    box(ctx, "#ffdd8b", x-1, y-10+(flicker%3), 3, 6);
    box(ctx, "#f7b96a", x+3-(flicker%3), y-size-6-flicker, 1, 1);
  }

  function makeMap(zone) {
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    tileGround(ctx, zone);
    for (const [x,y] of [[12,28],[57,37],[104,28],[152,45],[321,30],[363,45],[462,32],[17,156],[38,202],[12,259],[77,279],[416,277],[466,250],[463,178]]) tree(ctx,x,y,zone);
    if (zone === "defense") {
      wall(ctx, 13, 79, 194, zone);
      wall(ctx, 273, 79, 194, zone);
      for (const x of [49, 137, 315, 402]) tower(ctx, x, 82, 24, true);
      tower(ctx, 176, 82, 32, true);
      tower(ctx, 273, 82, 32, true);
      for (let x=210;x<271;x+=5) box(ctx, "#9d8258", x, 91, 4, 2);
      box(ctx, "#4d4938", 207, 95, 66, 3);
      for (const [x,y] of [[45,124],[106,204],[394,209],[431,126]]) {
        fence(ctx,x,y,31);
        crate(ctx,x+7,y+5);
        crate(ctx,x+22,y+11,9);
      }
      for (const [x,y] of [[74,245],[361,243],[408,251]]) tent(ctx,x,y,29,"#726448");
      for (const b of Pei.barricades.defense.slice(2)) {
        fence(ctx,b.x,b.y+8,b.w);
        crate(ctx,b.x+2,b.y+6,17);
      }
    } else if (zone === "assault") {
      wall(ctx, 13, 101, 195, zone);
      wall(ctx, 270, 101, 113, zone);
      wall(ctx, 431, 101, 34, zone);
      tower(ctx, 70, 101, 25);
      tower(ctx, 176, 103, 33);
      tower(ctx, 270, 103, 32);
      tower(ctx, 355, 103, 28);
      for (const [x,y] of [[102,58],[146,72],[281,47],[291,53],[339,65],[354,61],[350,211],[53,230]]) crate(ctx,x,y,14);
      tower(ctx, 239, 34, 56, true);
      for (const b of Pei.barricades.assault.slice(3)) {
        crate(ctx,b.x,b.y+6,17);
        fence(ctx,b.x,b.y+8,b.w);
      }
      for (let y = 123; y < 262; y += 3) {
        const bend = Math.round(Math.sin(y / 16) * 5);
        box(ctx,"#3d3e31",386+bend,y,39,3);
        box(ctx,"#64624a",393+bend,y,25,3);
        if (y % 2) box(ctx,"#7b7352",391+bend,y,6,1);
        if (y % 4) box(ctx,"#34382d",419+bend,y,7,1);
      }
    } else {
      fence(ctx,62,92,118);
      fence(ctx,304,92,112);
      tent(ctx,83,141,66,"#745648");
      tent(ctx,327,144,67,"#645d47");
      tent(ctx,119,224,54,"#696748");
      tent(ctx,305,218,59,"#6c5544");
      tower(ctx,217,104,49,true);
      for (const [x,y] of [[155,151],[171,156],[309,152],[295,153],[279,212],[197,208],[174,212]]) crate(ctx,x,y);
      oval(ctx,"#645441",240,157,46,17);
      oval(ctx,"#61573e",240,156,41,14);
      box(ctx,"#9a7b53",209,160,7,2);
      box(ctx,"#94754f",270,156,5,2);
    }
    const vignette = ctx.createRadialGradient(240,150,100,240,150,272);
    vignette.addColorStop(0,"#181d1800");
    vignette.addColorStop(1,"#14181391");
    ctx.fillStyle = vignette;
    ctx.fillRect(0,0,width,height);
    return canvas;
  }

  function sprite(ctx, u, x = u.x, y = u.y, icon = false) {
    const id = u.id;
    const [dark, body, light, trim, boots] = palettes[id];
    const broad = ["fan", "xiang", "captain"].includes(id);
    const tall = ["xiang", "captain", "pike"].includes(id);
    const side = Math.cos(u.face) > .33 ? 1 : Math.cos(u.face) < -.33 ? -1 : 0;
    const back = Math.sin(u.face) < -.58;
    const step = u.moving ? Math.round(Math.sin((u.stride || 0) / 4) * 2) : 0;
    const lift = u.moving && step === 0 ? 1 : 0;
    const head = tall ? -22 : -20;
    const span = broad ? 8 : id === "xiao" ? 5 : 6;
    const cloak = id === "liu" || id === "xiang" || id === "xiao" || id === "captain";
    const outline = "#232923";
    const skin = id === "fan" ? "#cb956c" : "#d8a87d";
    const dx = x + side;
    ctx.save();
    if (!icon && u.hp <= 0) {
      ctx.translate(x, y-4);
      ctx.rotate(-Math.PI/2);
      ctx.translate(-x, -y+4);
      ctx.globalAlpha = .73;
    }
    if (!icon) oval(ctx, "#222b25b8", x, y, span+4, 3);
    if (cloak) {
      polygon(ctx, outline, [[dx-span+1,y-17],[dx+span-1,y-17],[dx+span+2-side*2,y-3],[dx-span-2-side*2,y-2]]);
      polygon(ctx, dark, [[dx-span+1,y-15],[dx+span-1,y-16],[dx+span+1-side*2,y-4],[dx-span-1-side*2,y-3]]);
      box(ctx, light, dx - span - side*2, y-5, 2, 2);
    }
    box(ctx, outline,x-5,y-7+step,5,7);
    box(ctx, outline,x+1,y-7-step,5,7);
    box(ctx, boots,x-4,y-7+step,3,5);
    box(ctx, boots,x+2,y-7-step,3,5);
    box(ctx, "#957957",x-4+side,y-2+step,3,1);
    box(ctx, "#957957",x+2+side,y-2-step,3,1);
    if (id === "fan" || id === "qin" || id === "captain") {
      const shieldX = dx + (side || -1)*6;
      polygon(ctx, outline, [[shieldX-4,y-15],[shieldX+4,y-15],[shieldX+5,y-12],[shieldX+3,y-5],[shieldX,y-3],[shieldX-4,y-6]]);
      polygon(ctx, id === "fan" ? "#916847" : "#6b7770", [[shieldX-3,y-14],[shieldX+3,y-14],[shieldX+4,y-12],[shieldX+2,y-6],[shieldX,y-4],[shieldX-3,y-7]]);
      box(ctx, trim, shieldX-1, y-11, 2, 3);
    }
    polygon(ctx,outline,[[dx-span,y-15-lift],[dx-span+2,y-18-lift],[dx+span-2,y-18-lift],[dx+span,y-15-lift],[dx+span-2,y-6],[dx-span+2,y-6]]);
    polygon(ctx,body,[[dx-span+1,y-15-lift],[dx-span+3,y-17-lift],[dx+span-3,y-17-lift],[dx+span-1,y-15-lift],[dx+span-3,y-7],[dx-span+3,y-7]]);
    box(ctx,light,dx-span+2,y-15-lift,span*2-4,2);
    for (let i=0; i<3; i++) {
      box(ctx,dark,dx-span+3,y-12+i*2,span*2-6,1);
      box(ctx,trim,dx-1+(back ? -side : side),y-12+i*2,1,1);
    }
    box(ctx,boots,dx-span+2,y-8,span*2-4,2);
    box(ctx,trim,dx-1,y-8,2,1);
    const handX = dx + (side || 1)*(span-1);
    box(ctx,skin,handX-1,y-11,3,3);
    if (id === "xiao") {
      box(ctx,"#302c22",handX-2,y-12,6,6);
      box(ctx,"#d4b582",handX-1,y-11,4,4);
      box(ctx,"#986845",handX,y-10,2,1);
    } else if (id === "pike" || id === "xiang") {
      const pole = handX + (side || 1)*3;
      box(ctx,"#9a7650",pole,y-28,1,26);
      box(ctx,"#eee0aa",pole,y-29,1,3);
      box(ctx,"#9caaa1",pole-1,y-31,3,4);
      if (id === "xiang") box(ctx,"#d1989a",pole-3,y-25,4,2);
    } else {
      box(ctx,"#848d7d",handX+2,y-13,2,9);
      box(ctx,"#e0d3ac",handX+2,y-13,1,6);
      box(ctx,trim,handX+1,y-8,3,1);
    }
    const hy = y + head - lift;
    box(ctx,outline,dx-4,hy,8,8);
    box(ctx,back ? boots : skin,dx-3,hy+1,6,6);
    box(ctx,back ? light : "#e9bd93",dx-2,hy+2,4,1);
    if (!back) {
      box(ctx,"#463128",dx+(side || 1),hy+3,1,1);
      if (broad) box(ctx,"#4a342e",dx-2,hy+5,4,2);
    }
    if (id === "liu" || id === "xiao") {
      box(ctx,outline,dx-3,hy-4,6,5);
      box(ctx,id === "xiao" ? "#6d8e70" : trim,dx-1,hy-3,2,3);
      box(ctx,light,dx-4,hy,8,1);
    } else {
      box(ctx,boots,dx-4,hy-2,8,4);
      box(ctx,trim,dx-3,hy-1,6,1);
      if (tall) {
        box(ctx,outline,dx-1,hy-7,3,5);
        box(ctx,light,dx,hy-7,2,4);
      } else if (id === "fan") {
        box(ctx,light,dx-5,hy,10,2);
      }
    }
    if (u.hit > 0.12) {
      box(ctx,"#ffceb2",dx-span+2,y-14,span*2-4,2);
      box(ctx,"#f39b74",dx+span+1,y-17,2,2);
      box(ctx,"#f4ca94",dx-span-2,y-11,2,1);
    }
    ctx.restore();
  }

  function marker(ctx,x,y,label,color,t) {
    oval(ctx,"#242a20",x,y,14,5);
    oval(ctx,color,x,y,12,3);
    oval(ctx,"#414537",x,y,9,2);
    const bob = Math.round(Math.sin(t*4+x)*2);
    polygon(ctx,color,[[x-3,y-17+bob],[x+3,y-17+bob],[x,y-12+bob]]);
    text(ctx,label,x,y-21+bob,color,8);
  }

  function slash(ctx,u,reduced) {
    const radius = u.id === "liu" ? 42 : u.id === "xiang" ? 33 : 22;
    const arc = u.id === "liu" ? 1.05 : 0.83;
    const turn = reduced ? 0 : Math.max(0, (0.25-u.swing)*4);
    const start = u.face - arc + turn*.8;
    const end = Math.min(u.face+arc, start + 1.58);
    const center = { x: u.x, y: u.y - 5 };
    const vertices = [];
    for (let i=0;i<=10;i++) {
      const rot = start+(end-start)*i/10;
      vertices.push([center.x+Math.cos(rot)*radius,center.y+Math.sin(rot)*radius*.81]);
    }
    for (let i=10;i>=0;i--) {
      const rot = start+(end-start)*i/10;
      const span = radius-2-4*Math.sin(Math.PI*i/10);
      vertices.push([center.x+Math.cos(rot)*span,center.y+Math.sin(rot)*span*.81]);
    }
    polygon(ctx,u.id === "liu" ? "#eeb14ccf" : "#d07e45ca",vertices);
  }

  const maps = {};
  function draw(ctx, run, t, pointer, reduced = false) {
    if (reduced) t = 0;
    const zone = run.scene;
    maps[zone] ||= makeMap(zone);
    ctx.drawImage(maps[zone],0,0);
    if (zone === "defense") {
      for (const x of [171,308,86,403]) fire(ctx,x,x===171 || x===308 ? 112 : 122,t);
      flag(ctx,216,121,t,false,true);
      flag(ctx,260,121,t,false,true);
      flag(ctx,108,63,t);
      flag(ctx,372,63,t);
      const gate = points.gate;
      if (run.phase === "defense") {
        box(ctx,"#292e25",gate.x-23,gate.y-7,46,5);
        box(ctx,run.gate < 30 ? "#e07758" : "#dab06f",gate.x-22,gate.y-6,44*run.gate/100,3);
      }
      for (const wound of run.wounds.filter((w)=>w.state==="waiting")) {
        oval(ctx,"#302e25",wound.x,wound.y,10,4);
        box(ctx,"#886b4c",wound.x-9,wound.y-4,17,6);
        box(ctx,"#c2aa7e",wound.x-6,wound.y-3,11,4);
        box(ctx,"#9d594d",wound.x-2,wound.y-2,4,3);
        marker(ctx,wound.x,wound.y+5,wound.name+(wound.stabilized ? " +" : ""),"#c6bd5a",t);
      }
    } else if (zone === "camp") {
      fire(ctx,240,154,t,true);
      fire(ctx,76,146,t);
      fire(ctx,399,146,t);
      flag(ctx,240,112,t,false,true);
      flag(ctx,172,151,t);
      flag(ctx,299,151,t);
    } else {
      if (run.route !== "front") wall(ctx,208,101,62,zone);
      if (run.route !== "side") fence(ctx,383,108,48);
      flag(ctx,221,80,t,true,true);
      flag(ctx,297,80,t,true,true);
      flag(ctx,438,127,t,true);
      for (const x of [113,232,307,402]) fire(ctx,x,x===232 || x===307 ? 50 : 134,t);
      if (!run.route) {
        marker(ctx,points.front.x,points.front.y,"정면 합류","#eeb14c",t);
        marker(ctx,points.side.x,points.side.y,"측문","#b6b65e",t);
      } else if (!run.loading) {
        marker(ctx,points.supply.x,points.supply.y,"군량고","#eeb14c",t);
      } else {
        const { x,y } = points.supply;
        ctx.strokeStyle = "#e3c08280";
        ctx.setLineDash([3,3]);
        ctx.beginPath();
        ctx.arc(x,y,79,0,TAU);
        ctx.stroke();
        ctx.setLineDash([]);
        box(ctx,"#262d24",x-20,y-13,40,4);
        box(ctx,"#dbb575",x-19,y-12,Math.min(38,38*run.loading.progress/105),2);
        text(ctx,"군량 수레",x,y-17,"#eeb14c");
      }
    }
    if (run.rally > 0 && run.party[0]) {
      const player = run.party[0];
      ctx.strokeStyle = "#efc9808c";
      ctx.setLineDash([3,3]);
      ctx.beginPath();
      ctx.ellipse(player.x,player.y,27+Math.sin(t*6)*2,15,0,0,TAU);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    const people = [...run.party,...run.foes.filter(Pei.active)].sort((a,b)=>a.y-b.y);
    for (const u of people) {
      if (u.wind > 0) {
        const reach = roster[u.id].reach+7;
        polygon(ctx,"#da68495e",[[u.x,u.y-4],
          [u.x+Math.cos(u.face-.63)*reach,u.y-4+Math.sin(u.face-.63)*reach],
          [u.x+Math.cos(u.face)*reach,u.y-4+Math.sin(u.face)*reach],
          [u.x+Math.cos(u.face+.63)*reach,u.y-4+Math.sin(u.face+.63)*reach]]);
        text(ctx,"!",u.x,u.y-30,"#f28d58",10);
      }
      if (u.id === "liu" && u.hp > 0) {
        oval(ctx,"#c49a56",u.x,u.y+1,13,4);
        oval(ctx,"#4b4b36",u.x,u.y+1,10,2);
      }
      sprite(ctx,reduced && u.moving ? { ...u, moving: false } : u);
      if (u.swing > 0) slash(ctx,u,reduced);
      if (u.hp > 0 && u.hp < u.max && u.id !== "liu") {
        box(ctx,"#282922",u.x-8,u.y-29,16,3);
        box(ctx,run.party.includes(u) ? "#c6bd5a" : "#f28d58",u.x-7,u.y-28,14*u.hp/u.max,1);
      }
      if (run.party.includes(u)) {
        text(ctx,roster[u.id].name,u.x,u.y+13,roster[u.id].color);
      }
    }
    for (const e of run.effects) text(ctx,e.text,e.x,reduced ? e.y : e.y-(.82-e.life)*14,e.color);
    if (pointer && ["defense","assault"].includes(run.phase)) {
      const { x,y } = pointer;
      for (const [dx,dy,w,h] of [[-6,0,4,1],[3,0,4,1],[0,-6,1,4],[0,3,1,4]]) box(ctx,"#eeb14c",x+dx,y+dy,w,h);
    }
  }

  function die(ctx, face) {
    polygon(ctx,"#2d241c",[[32,2],[51,9],[62,28],[60,44],[47,58],[28,63],[11,54],[2,37],[4,18],[17,6]]);
    polygon(ctx,"#b58750",[[32,4],[50,11],[59,28],[57,44],[46,55],[28,60],[13,52],[5,36],[7,20],[18,8]]);
    polygon(ctx,"#dbb575",[[32,5],[18,9],[8,21],[20,27],[33,17]]);
    polygon(ctx,"#86603d",[[20,27],[6,36],[13,51],[26,46]]);
    polygon(ctx,"#755135",[[43,39],[56,44],[45,54],[28,59],[26,46]]);
    polygon(ctx,"#ead09a",[[20,27],[33,17],[49,24],[43,39],[26,46]]);
    polygon(ctx,"#a57948",[[33,17],[50,11],[58,28],[49,24]]);
    polygon(ctx,"#bd995d",[[49,24],[58,28],[56,44],[43,39]]);
    ctx.fillStyle="#55392b";
    ctx.font="bold 19px Georgia, serif";
    ctx.textAlign="center";
    ctx.fillText(face || "令",34,38);
  }

  window.PeiArt = { draw, sprite, die };
})();
