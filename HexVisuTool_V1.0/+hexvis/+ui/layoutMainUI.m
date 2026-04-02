function L = layoutMainUI()
%LAYOUTMAINUI Default size and responsive layout constants.

    L.fig = [20 20 1680 940];

    L.minFigW = 1280;
    L.minFigH = 760;

    L.margin = 8;
    L.gap = 10;
    L.leftFrac = 0.28;
    L.leftMin = 420;
    L.leftMax = 500;

    L.ctrlPreferredH = 430;
    L.ctrlMinH = 405;
    L.eventsMinH = 210;

    L.sectionGap = 8;
    L.sectionMin.File = 90;
    L.sectionMin.Run = 88;
    L.sectionMin.Vis = 100;
    L.sectionMin.Status = 80;

end
