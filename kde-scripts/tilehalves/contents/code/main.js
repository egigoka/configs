function tileWindow(side) {
    const win = workspace.activeWindow;
    if (!win || !win.moveable || !win.resizeable) return;

    win.tile = null;

    const output = win.output;
    const s = { x: output.geometry.x, y: output.geometry.y, width: output.geometry.width, height: output.geometry.height };
    print("[tilehalves] output geometry: " + s.x + "," + s.y + " " + s.width + "x" + s.height);
    const geo = { x: s.x, y: s.y, width: s.width, height: s.height };

    if (side === "right") {
        geo.x = s.x + Math.round(s.width / 2);
        geo.width = Math.round(s.width / 2);
    } else if (side === "left") {
        geo.width = Math.round(s.width / 2);
    } else if (side === "top") {
        geo.height = Math.round(s.height / 2);
    } else if (side === "bottom") {
        geo.y = s.y + Math.round(s.height / 2);
        geo.height = Math.round(s.height / 2);
    }

    print("[tilehalves] screen: " + s.width + "x" + s.height);
    print("[tilehalves] tile " + side + ": top-left=(" + geo.x + "," + geo.y + ") bottom-right=(" + (geo.x + geo.width) + "," + (geo.y + geo.height) + ")");

    win.frameGeometry = geo;
}

registerShortcut("TileWindowRightHalf", "Tile Window to Right Half", "Meta+D", function() { tileWindow("right"); });
registerShortcut("TileWindowLeftHalf", "Tile Window to Left Half", "Meta+A", function() { tileWindow("left"); });
registerShortcut("TileWindowTopHalf", "Tile Window to Top Half", "Meta+W", function() { tileWindow("top"); });
registerShortcut("TileWindowBottomHalf", "Tile Window to Bottom Half", "Meta+X", function() { tileWindow("bottom"); });
