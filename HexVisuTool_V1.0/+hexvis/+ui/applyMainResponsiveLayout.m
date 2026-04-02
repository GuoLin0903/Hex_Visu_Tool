function applyMainResponsiveLayout(fig)
%APPLYMAINRESPONSIVELAYOUT Layout main UI.
% Left side remains responsive. Right preview uses a safer near-fixed grid
% with generous margins to avoid overlap across common DPI settings.

    if ~ishghandle(fig), return; end
    ui = getappdata(fig, 'hexvis_ui_handles');
    if isempty(ui), return; end
    L = hexvis.ui.layoutMainUI();

    fig.Units = 'pixels';
    fp = fig.Position;
    fw = max(fp(3), L.minFigW);
    fh = max(fp(4), L.minFigH);

    m = L.margin;
    g = L.gap;

    leftW = round(min(L.leftMax, max(L.leftMin, fw * L.leftFrac)));
    plotW = fw - 2*m - g - leftW;
    if plotW < 760
        leftW = max(L.leftMin, fw - 2*m - g - 760);
        plotW = fw - 2*m - g - leftW;
    end

    ctrlH = min(L.ctrlPreferredH, max(L.ctrlMinH, round(fh * 0.47)));
    tableH = fh - 2*m - g - ctrlH;
    if tableH < L.eventsMinH
        tableH = L.eventsMinH;
        ctrlH = fh - 2*m - g - tableH;
        ctrlH = max(ctrlH, L.ctrlMinH);
    end

    ctrlPos = [m, fh - m - ctrlH, leftW, ctrlH];
    tablePos = [m, m, leftW, tableH];
    plotPos = [m + leftW + g, m, plotW, fh - 2*m];

    set(ui.panCtrl, 'Units', 'pixels', 'Position', ctrlPos);
    set(ui.panTable, 'Units', 'pixels', 'Position', tablePos);
    set(ui.panPlot, 'Units', 'pixels', 'Position', plotPos);

    localLayoutControls(ui, ctrlPos(3), ctrlPos(4), L);
    localLayoutEvents(ui, tablePos(3), tablePos(4), L);
    localLayoutPreview(ui, plotPos(3), plotPos(4));
end

function localLayoutControls(ui, pw, ph, L)
    m = 10;
    g = L.sectionGap;
    innerW = pw - 2*m;
    minHeights = [L.sectionMin.File, L.sectionMin.Run, L.sectionMin.Vis, L.sectionMin.Status];
    avail = ph - 2*m - 3*g;
    extra = max(0, avail - sum(minHeights));
    hFile = minHeights(1);
    hRun = minHeights(2);
    hVis = minHeights(3) + round(extra * 0.25);
    hStatus = minHeights(4) + extra - round(extra * 0.25);

    yStatus = m;
    yVis = yStatus + hStatus + g;
    yRun = yVis + hVis + g;
    yFile = yRun + hRun + g;

    set(ui.secFile,   'Units', 'pixels', 'Position', [m, yFile,   innerW, hFile]);
    set(ui.secRun,    'Units', 'pixels', 'Position', [m, yRun,    innerW, hRun]);
    set(ui.secVis,    'Units', 'pixels', 'Position', [m, yVis,    innerW, hVis]);
    set(ui.secStatus, 'Units', 'pixels', 'Position', [m, yStatus, innerW, hStatus]);

    localLayoutFile(ui, innerW, hFile);
    localLayoutRun(ui, innerW, hRun);
    localLayoutVis(ui, innerW, hVis);
    set(ui.txtStatus, 'Units', 'pixels', 'Position', [10, 10, innerW - 20, hStatus - 34]);
end

function localLayoutFile(ui, pw, ph)
    left = 10; right = 10; topPad = 28;
    row1H = 26; row2H = 22;
    loadW = 110; gap = 10;
    y1 = ph - topPad - row1H;
    y2 = 12;
    set(ui.btnLoad, 'Units', 'pixels', 'Position', [left, y1, loadW, row1H]);
    set(ui.txtFile, 'Units', 'pixels', 'Position', [left + loadW + gap, y1, pw - right - (left + loadW + gap), row1H]);
    set(ui.txtFileInfo, 'Units', 'pixels', 'Position', [left, y2, pw - left - right, row2H]);
end

function localLayoutRun(ui, pw, ph)
    left = 10; right = 10; topPad = 28; gap = 12;
    btnH = 28; infoH = 18;
    yBtn = ph - topPad - btnH;
    yInfo = 14;
    usableW = pw - left - right - 2*gap;
    w1 = floor(usableW * 0.28);
    w2 = floor(usableW * 0.37);
    w3 = usableW - w1 - w2;
    x1 = left;
    x2 = x1 + w1 + gap;
    x3 = x2 + w2 + gap;
    set(ui.btnAIC, 'Units', 'pixels', 'Position', [x1, yBtn, w1, btnH]);
    set(ui.btnFeat, 'Units', 'pixels', 'Position', [x2, yBtn, w2, btnH]);
    set(ui.btnSettings, 'Units', 'pixels', 'Position', [x3, yBtn, w3, btnH]);
    set(ui.txtChannel, 'Units', 'pixels', 'Position', [left, yInfo, floor((pw-left-right)/2)-6, infoH]);
    set(ui.txtGeom, 'Units', 'pixels', 'Position', [floor(pw/2)+2, yInfo, pw-right-floor(pw/2)-2, infoH]);
end

function localLayoutVis(ui, pw, ph)
    left = 10; right = 10; topPad = 30;
    rowH = 24; ctlH = 24; gapX = 8; rowGap = 12;
    usableW = pw - left - right;
    y1 = ph - topPad - ctlH;
    y2 = y1 - rowGap - ctlH;

    wLbl1 = 56; wPop = 90; wLbl2 = 74; wEdit = 80;
    x = left;
    set(ui.lblTFMode, 'Units', 'pixels', 'Position', [x, y1+2, wLbl1, rowH]);
    x = x + wLbl1 + gapX;
    set(ui.popTF, 'Units', 'pixels', 'Position', [x, y1, wPop, ctlH]);
    x = x + wPop + gapX;
    set(ui.lblFmax, 'Units', 'pixels', 'Position', [x, y1+2, wLbl2, rowH]);
    x = x + wLbl2 + gapX;
    set(ui.edFmax, 'Units', 'pixels', 'Position', [x, y1, wEdit, ctlH]);
    x = x + wEdit + gapX;
    set(ui.chkSharedCB, 'Units', 'pixels', 'Position', [x, y1+1, pw-right-x, ctlH]);

    wLbl3 = 62; wEdit2 = 70; wLbl4 = 72; wEdit3 = 70;
    x = left;
    set(ui.lblStart, 'Units', 'pixels', 'Position', [x, y2+2, wLbl3, rowH]);
    x = x + wLbl3 + gapX;
    set(ui.edStartUs, 'Units', 'pixels', 'Position', [x, y2, wEdit2, ctlH]);
    x = x + wEdit2 + 16;
    set(ui.lblLength, 'Units', 'pixels', 'Position', [x, y2+2, wLbl4, rowH]);
    x = x + wLbl4 + gapX;
    set(ui.edWinUs, 'Units', 'pixels', 'Position', [x, y2, wEdit3, ctlH]);
end

function localLayoutEvents(ui, pw, ph, ~)
    m = 10;
    btnH = 28;
    gap = 8;
    footerH = btnH;
    topInset = 28;
    tableY = m + footerH + gap;
    tableH = ph - topInset - tableY;
    set(ui.tbl, 'Units', 'pixels', 'Position', [m, tableY, pw - 2*m, tableH]);
    set(ui.btnPrev, 'Units', 'pixels', 'Position', [m, m, 56, btnH]);
    set(ui.btnNext, 'Units', 'pixels', 'Position', [m + 64, m, 56, btnH]);
    set(ui.txtSelected, 'Units', 'pixels', 'Position', [pw - 170, m+2, 160, btnH-2]);
end

function localLayoutPreview(ui, pw, ph)
% Fixed, smaller preview layout rolled back toward the stable fix8 style.
% The goal here is not to fill every pixel, but to prevent any overlap.

    x1 = round(0.050 * pw);
    x2 = round(0.535 * pw);
    w  = round(0.415 * pw);

    set(ui.axS1t,  'Units', 'pixels', 'Position', [x1, round(0.745*ph), w, round(0.180*ph)]);
    set(ui.axS2t,  'Units', 'pixels', 'Position', [x2, round(0.745*ph), w, round(0.180*ph)]);

    set(ui.axS1f,  'Units', 'pixels', 'Position', [x1, round(0.490*ph), w, round(0.160*ph)]);
    set(ui.axS2f,  'Units', 'pixels', 'Position', [x2, round(0.490*ph), w, round(0.160*ph)]);

    set(ui.axS1tf, 'Units', 'pixels', 'Position', [x1, round(0.080*ph), w, round(0.355*ph)]);
    set(ui.axS2tf, 'Units', 'pixels', 'Position', [x2, round(0.080*ph), w, round(0.355*ph)]);

    axList = [ui.axS1t ui.axS2t ui.axS1f ui.axS2f ui.axS1tf ui.axS2tf];
    set(axList, 'FontSize', 9);
end
