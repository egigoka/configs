function tileWindow(side) {
    const win = workspace.activeWindow;
    if (!win || !win.moveable || !win.resizeable) return;

    win.tile = null;
    if (win.maximizable) {
        win.setMaximize(false, false);
    }

    // full screen for split calculations, work area for panel clamping
    var full = win.output.geometry;
    var work = workspace.clientArea(workspace.MaximizeArea, win.output, workspace.currentDesktop);
    print("[tilehalves] full: " + full.x + "," + full.y + " " + full.width + "x" + full.height);
    print("[tilehalves] work: " + work.x + "," + work.y + " " + work.width + "x" + work.height);

    var splitX = full.x + Math.round(full.width / 2);
    var splitY = full.y + Math.round(full.height / 2);
    var workRight = work.x + work.width;
    var workBottom = work.y + work.height;

    var geo;
    if (side === "right") {
        geo = { x: splitX, y: work.y, width: workRight - splitX, height: work.height };
    } else if (side === "left") {
        geo = { x: work.x, y: work.y, width: splitX - work.x, height: work.height };
    } else if (side === "top") {
        geo = { x: work.x, y: work.y, width: work.width, height: splitY - work.y };
    } else if (side === "bottom") {
        geo = { x: work.x, y: splitY, width: work.width, height: workBottom - splitY };
    }

    print("[tilehalves] tile " + side + ": top-left=(" + geo.x + "," + geo.y + ") bottom-right=(" + (geo.x + geo.width) + "," + (geo.y + geo.height) + ")");

    win.frameGeometry = geo;
}

function maximizeWindow() {
    const win = workspace.activeWindow;
    if (!win || !win.maximizable) return;

    win.tile = null;
    win.setMaximize(true, true);
}

registerShortcut("TileWindowRightHalf", "Tile Window to Right Half", "Meta+D", function() { tileWindow("right"); });
registerShortcut("TileWindowLeftHalf", "Tile Window to Left Half", "Meta+A", function() { tileWindow("left"); });
registerShortcut("TileWindowTopHalf", "Tile Window to Top Half", "Meta+W", function() { tileWindow("top"); });
registerShortcut("TileWindowBottomHalf", "Tile Window to Bottom Half", "Meta+X", function() { tileWindow("bottom"); });
registerShortcut("TileWindowMaximize", "Maximize Window Without Toggling", "Meta+S", function() { maximizeWindow(); });
